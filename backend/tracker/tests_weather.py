"""Tests for the weather snapshot cache, rain-deferred watering, and frost warnings."""
from datetime import date, timedelta
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from . import weather as weather_mod
from .models import CareTask, Crop, WeatherSnapshot
from .watering import apply_rain_deferral, effective_days_overdue
from .weather import frost_warning, get_weather


def fake_open_meteo(rain_past=0.0, rain_today=0.0, prob_today=0, tmin=8.0):
    """A raw Open-Meteo payload: 2 past days + today + 3 ahead."""
    today = timezone.localdate()
    dates = [str(today + timedelta(days=offset)) for offset in range(-2, 4)]
    return {
        "daily": {
            "time": dates,
            "temperature_2m_min": [tmin] * 6,
            "temperature_2m_max": [tmin + 8] * 6,
            "precipitation_sum": [rain_past, rain_past, rain_today, 0, 0, 0],
            "precipitation_probability_max": [80, 80, prob_today, 10, 10, 10],
        }
    }


def weather_payload(recent_rain=0.0, today_rain=0.0, today_prob=0, frost_days=0):
    """A normalised payload, as get_weather() would return it."""
    today = timezone.localdate()
    days = []
    for offset in range(1, 4):
        days.append({
            "date": str(today + timedelta(days=offset)),
            "tmin": -1.0 if offset <= frost_days else 8.0,
            "tmax": 14.0,
            "precip_mm": 0,
            "precip_prob": 10,
            "frost": offset <= frost_days,
        })
    return {
        "location": "Test",
        "fetched_at": timezone.now().isoformat(),
        "recent_rain_mm": recent_rain,
        "today": {
            "date": str(today),
            "tmin": 8.0,
            "tmax": 16.0,
            "precip_mm": today_rain,
            "precip_prob": today_prob,
            "frost": False,
        },
        "days": days,
        "stale": False,
    }


class WeatherCacheTests(TestCase):
    def setUp(self):
        weather_mod._last_failure = None

    @patch("tracker.weather.requests.get")
    def test_fetch_normalises_and_caches(self, mock_get):
        mock_get.return_value.json.return_value = fake_open_meteo(rain_past=3.0, rain_today=1.0)
        mock_get.return_value.raise_for_status.return_value = None
        payload = get_weather()
        self.assertEqual(payload["recent_rain_mm"], 6.0)  # two past days at 3mm
        self.assertEqual(len(payload["days"]), 3)
        self.assertEqual(WeatherSnapshot.objects.count(), 1)
        # A second call inside the TTL serves the snapshot without re-fetching.
        get_weather()
        self.assertEqual(mock_get.call_count, 1)

    @patch("tracker.weather.requests.get")
    def test_failure_serves_stale_snapshot(self, mock_get):
        WeatherSnapshot.objects.create(
            payload=weather_payload(recent_rain=2.0),
            fetched_at=timezone.now() - timedelta(hours=3),
        )
        mock_get.side_effect = OSError("offline")
        payload = get_weather()
        self.assertTrue(payload["stale"])
        self.assertEqual(payload["recent_rain_mm"], 2.0)

    @patch("tracker.weather.requests.get")
    def test_failure_with_no_snapshot_returns_none(self, mock_get):
        mock_get.side_effect = OSError("offline")
        self.assertIsNone(get_weather())


class RainDeferralTests(TestCase):
    def setUp(self):
        self.crop = Crop.objects.create(crop="lettuce", planted_on=timezone.localdate())
        self.water = CareTask.objects.get(auto_key=f"crop:{self.crop.pk}:water")

    def test_recent_rain_defers_watering(self):
        deferred = apply_rain_deferral([self.water], weather_payload(recent_rain=6.0))
        self.assertEqual(deferred, {self.water.id})
        self.assertTrue(self.water.rain_deferred)
        self.assertEqual(self.water.weather_note, "rained recently — deferred")
        self.assertEqual(effective_days_overdue(self.water), min(-1, self.water.days_overdue))

    def test_confident_forecast_defers_watering(self):
        deferred = apply_rain_deferral(
            [self.water], weather_payload(today_rain=8.0, today_prob=90)
        )
        self.assertEqual(deferred, {self.water.id})
        self.assertEqual(self.water.weather_note, "rain due — deferred")

    def test_dry_spell_defers_nothing(self):
        deferred = apply_rain_deferral(
            [self.water], weather_payload(recent_rain=1.0, today_rain=2.0, today_prob=40)
        )
        self.assertEqual(deferred, set())
        self.assertFalse(getattr(self.water, "rain_deferred", False))

    def test_harvested_crop_not_deferred(self):
        self.crop.harvested_on = timezone.localdate()
        self.crop.save()
        # The watering task may still be active mid-request; deferral must
        # ignore crops out of the ground regardless.
        deferred = apply_rain_deferral([self.water], weather_payload(recent_rain=10.0))
        self.assertEqual(deferred, set())

    def test_non_watering_tasks_untouched(self):
        chores = CareTask.objects.create(name="Sweep the yard")
        deferred = apply_rain_deferral([chores], weather_payload(recent_rain=10.0))
        self.assertEqual(deferred, set())
        self.assertFalse(getattr(chores, "rain_deferred", False))

    def test_no_weather_fails_open(self):
        self.assertEqual(apply_rain_deferral([self.water], None), set())


class FrostWarningTests(TestCase):
    def test_warns_for_tender_crop_in_spring(self):
        Crop.objects.create(crop="courgettes", planted_on=timezone.localdate())
        warning = frost_warning(weather_payload(frost_days=2), today=date(2026, 5, 10))
        self.assertIsNotNone(warning)
        self.assertIn("Courgettes", warning["crops"])
        self.assertEqual(len(warning["nights"]), 2)
        self.assertIn("cover the Courgettes", warning["message"])

    def test_silent_outside_april_to_june(self):
        Crop.objects.create(crop="courgettes", planted_on=timezone.localdate())
        warning = frost_warning(weather_payload(frost_days=2), today=date(2026, 11, 10))
        self.assertIsNone(warning)

    def test_silent_without_tender_crops(self):
        Crop.objects.create(crop="carrots", planted_on=timezone.localdate())
        warning = frost_warning(weather_payload(frost_days=2), today=date(2026, 5, 10))
        self.assertIsNone(warning)

    def test_silent_without_frost(self):
        Crop.objects.create(crop="courgettes", planted_on=timezone.localdate())
        warning = frost_warning(weather_payload(frost_days=0), today=date(2026, 5, 10))
        self.assertIsNone(warning)


class WeatherApiTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="marco", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    @patch("tracker.views.get_weather")
    def test_overview_carries_weather_and_defers_counts(self, mock_weather):
        mock_weather.return_value = weather_payload(recent_rain=8.0)
        crop = Crop.objects.create(
            crop="lettuce", planted_on=timezone.localdate() - timedelta(days=10)
        )
        water = CareTask.objects.get(auto_key=f"crop:{crop.pk}:water")
        # Make the watering task due today.
        water.last_completed = timezone.localdate() - timedelta(days=water.recurrence_interval_days)
        water.save()
        res = self.client.get("/api/overview/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["weather"]["recent_rain_mm"], 8.0)
        self.assertIn("frost_warning", res.data["weather"])
        # The due watering job is deferred, so nothing counts as due today.
        self.assertEqual(res.data["tasks"]["due_today"], 0)
        deferred_top = [t for t in res.data["tasks"]["top"] if t["rain_deferred"]]
        self.assertEqual(len(deferred_top), 1)

    @patch("tracker.views.get_weather")
    def test_dashboard_flags_deferred_watering(self, mock_weather):
        mock_weather.return_value = weather_payload(recent_rain=8.0)
        crop = Crop.objects.create(crop="lettuce", planted_on=timezone.localdate())
        res = self.client.get("/api/care-tasks/dashboard/")
        self.assertEqual(res.status_code, 200)
        by_key = {t["auto_key"]: t for t in res.data}
        water = by_key[f"crop:{crop.pk}:water"]
        self.assertTrue(water["rain_deferred"])
        self.assertEqual(water["weather_note"], "rained recently — deferred")
