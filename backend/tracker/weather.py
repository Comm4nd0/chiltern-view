"""Local weather for the holding (Open-Meteo) and frost warnings.

The forecast is cached in the single-row ``WeatherSnapshot`` table so all
workers share one copy; it refreshes on demand when older than
``WEATHER_CACHE_MINUTES``. When Open-Meteo is unreachable the stale snapshot is
served (flagged ``"stale": true``) so the dashboard degrades gracefully, and
failures are not retried for a few minutes to keep requests fast.
"""
import logging
from datetime import datetime, timedelta

import requests
from django.conf import settings
from django.utils import timezone

from .models import Crop, WeatherSnapshot

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
FAILURE_BACKOFF = timedelta(minutes=5)

# Crops a late frost can kill — drives the Apr–Jun frost warning.
TENDER_CROPS = {
    "courgettes", "cucumbers", "pumpkins", "tomatoes",
    "runner_beans", "french_beans", "sweetcorn",
}

_last_failure = None  # per-worker backoff after a failed fetch


def fetch_open_meteo():
    """One GET to Open-Meteo: the last 2 days plus today + 3 days ahead."""
    res = requests.get(
        OPEN_METEO_URL,
        params={
            "latitude": settings.WEATHER_LATITUDE,
            "longitude": settings.WEATHER_LONGITUDE,
            "daily": "temperature_2m_min,temperature_2m_max,"
                     "precipitation_sum,precipitation_probability_max",
            "past_days": 2,
            "forecast_days": 4,
            "timezone": "Europe/London",
        },
        timeout=5,
    )
    res.raise_for_status()
    return _normalise(res.json())


def _normalise(raw):
    """Open-Meteo's parallel-array payload as one compact dict per day."""
    daily = raw.get("daily") or {}
    dates = daily.get("time") or []
    tmins = daily.get("temperature_2m_min") or []
    tmaxs = daily.get("temperature_2m_max") or []
    rains = daily.get("precipitation_sum") or []
    probs = daily.get("precipitation_probability_max") or []

    def value(series, i):
        return series[i] if i < len(series) else None

    days = []
    for i, date in enumerate(dates):
        tmin = value(tmins, i)
        days.append({
            "date": date,
            "tmin": tmin,
            "tmax": value(tmaxs, i),
            "precip_mm": value(rains, i) or 0,
            "precip_prob": value(probs, i),
            "frost": tmin is not None and tmin < settings.FROST_TEMP_C,
        })

    today_str = str(timezone.localdate())
    today_index = next((i for i, d in enumerate(days) if d["date"] == today_str), 0)
    recent_rain = sum(d["precip_mm"] for d in days[:today_index])

    return {
        "location": settings.WEATHER_LOCATION_NAME,
        "fetched_at": timezone.now().isoformat(),
        "recent_rain_mm": round(recent_rain, 1),
        "today": days[today_index] if days else None,
        "days": days[today_index + 1:today_index + 4],
        "stale": False,
    }


def get_weather(max_age_minutes=None):
    """The cached weather payload, refreshed when stale.

    Returns None only when nothing has ever been fetched and Open-Meteo is
    unreachable — callers fail open (no deferral, no weather card).
    """
    global _last_failure
    max_age = settings.WEATHER_CACHE_MINUTES if max_age_minutes is None else max_age_minutes
    now = timezone.now()
    snapshot = WeatherSnapshot.objects.order_by("-fetched_at").first()
    if snapshot and snapshot.fetched_at > now - timedelta(minutes=max_age):
        return snapshot.payload
    if _last_failure and now - _last_failure < FAILURE_BACKOFF:
        return {**snapshot.payload, "stale": True} if snapshot else None
    try:
        payload = fetch_open_meteo()
    except Exception:
        logger.warning("Weather fetch failed; serving stale snapshot if any", exc_info=True)
        _last_failure = now
        return {**snapshot.payload, "stale": True} if snapshot else None
    _last_failure = None
    if snapshot:
        snapshot.payload = payload
        snapshot.fetched_at = now
        snapshot.save(update_fields=["payload", "fetched_at"])
    else:
        WeatherSnapshot.objects.create(payload=payload, fetched_at=now)
    return payload


def frost_warning(weather, today=None):
    """A heads-up when a tender crop is in the ground and frost is forecast.

    Only fires April–June: late frosts after planting-out are the danger on
    this holding; winter frost on brassicas/leeks is normal and not warned.
    """
    if not weather:
        return None
    today = today or timezone.localdate()
    if not 4 <= today.month <= 6:
        return None
    candidates = [weather.get("today"), *(weather.get("days") or [])]
    frost_days = [d for d in candidates if d and d.get("frost")]
    if not frost_days:
        return None
    growing = Crop.objects.filter(harvested_on__isnull=True, crop__in=TENDER_CROPS)
    labels = sorted({crop.crop_label for crop in growing})
    if not labels:
        return None
    nights = [d["date"] for d in frost_days]
    night_names = " & ".join(
        datetime.strptime(n, "%Y-%m-%d").strftime("%a") for n in nights[:2]
    )
    return {
        "nights": nights,
        "crops": labels,
        "message": f"Frost risk {night_names} night — cover the {', '.join(labels)}",
    }
