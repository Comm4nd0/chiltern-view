"""Read-time, weather-aware deferral of crop watering reminders.

No scheduler and no data mutation: when enough rain has fallen in the last two
days (or is confidently forecast for today), the auto "Water X" tasks are
flagged and ranked below genuinely due work for this request only.
``last_completed`` is never touched, so the rule reverses itself as soon as
the forecast dries out.
"""
import re

from django.conf import settings

from .models import Crop

WATER_KEY = re.compile(r"^crop:(\d+):water$")


def apply_rain_deferral(tasks, weather):
    """Flag watering tasks for crops still in the ground when rain covers them.

    Sets request-scoped ``task.rain_deferred`` / ``task.weather_note``
    attributes (surfaced by the serializer). Returns the deferred task ids.
    """
    if not weather:
        return set()
    threshold = settings.WATERING_RAIN_THRESHOLD_MM
    recent = weather.get("recent_rain_mm") or 0
    today = weather.get("today") or {}
    rained = recent >= threshold
    rain_due = (today.get("precip_mm") or 0) >= threshold and (today.get("precip_prob") or 0) >= 60
    if not (rained or rain_due):
        return set()
    note = "rained recently — deferred" if rained else "rain due — deferred"

    watering = {}
    for task in tasks:
        match = WATER_KEY.match(task.auto_key or "")
        if match and task.active:
            watering[task] = int(match.group(1))
    if not watering:
        return set()
    growing = set(
        Crop.objects.filter(
            pk__in=watering.values(), harvested_on__isnull=True
        ).values_list("pk", flat=True)
    )
    deferred = set()
    for task, crop_pk in watering.items():
        if crop_pk in growing:
            task.rain_deferred = True
            task.weather_note = note
            deferred.add(task.id)
    return deferred


def effective_days_overdue(task):
    """Ranking key: a rain-deferred watering job drops below genuinely due work."""
    if getattr(task, "rain_deferred", False) and task.days_overdue >= 0:
        return -1
    return task.days_overdue


def effective_status(task):
    """Bucketing key for counts: a deferred watering job counts as upcoming."""
    if getattr(task, "rain_deferred", False) and task.days_overdue >= 0:
        return "upcoming"
    return task.status
