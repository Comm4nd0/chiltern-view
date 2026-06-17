"""Tests for the read-only analytics & knowledge endpoints: egg laying trend,
harvest history/yields, and per-bed crop-rotation history."""
from datetime import date, timedelta

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Crop, EggRecord


class EggTrendTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="marco", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_trend_zero_fills_and_aggregates(self):
        today = timezone.localdate()
        EggRecord.objects.create(date=today, count=6)
        EggRecord.objects.create(date=today - timedelta(days=2), count=4)
        res = self.client.get("/api/egg-records/trend/", {"days": 7})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data["days"]), 7)
        # Last point is today; gaps are zero-filled, not missing.
        self.assertEqual(res.data["days"][-1]["count"], 6)
        self.assertEqual(res.data["days"][-3]["count"], 4)
        self.assertEqual(res.data["days"][-2]["count"], 0)
        self.assertEqual(res.data["total"], 10)
        self.assertEqual(res.data["best_day"]["count"], 6)

    def test_trend_clamps_days(self):
        res = self.client.get("/api/egg-records/trend/", {"days": "99999"})
        self.assertEqual(len(res.data["days"]), 365)

    def test_trend_handles_bad_days_param(self):
        res = self.client.get("/api/egg-records/trend/", {"days": "lots"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data["days"]), 30)
        self.assertIsNone(res.data["best_day"])


class HarvestHistoryTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="claire", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_harvests_group_by_crop_and_total(self):
        Crop.objects.create(
            crop="carrots", planted_on=date(2026, 4, 1),
            harvested_on=date(2026, 6, 1), yield_kg="3.50",
        )
        Crop.objects.create(
            crop="carrots", planted_on=date(2026, 4, 10),
            harvested_on=date(2026, 6, 10), yield_kg="1.50",
        )
        Crop.objects.create(
            crop="potatoes_maincrop", planted_on=date(2026, 3, 1),
            harvested_on=date(2026, 7, 1), yield_kg="10.00",
        )
        # Still growing — must not appear.
        Crop.objects.create(crop="onions", planted_on=date(2026, 4, 1))
        res = self.client.get("/api/crops/harvests/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data["harvests"]), 3)
        self.assertEqual(res.data["total_kg"], 15.0)
        # Best-yielding crop first.
        self.assertEqual(res.data["by_crop"][0]["crop"], "potatoes_maincrop")
        carrots = next(c for c in res.data["by_crop"] if c["crop"] == "carrots")
        self.assertEqual(carrots["count"], 2)
        self.assertEqual(carrots["total_kg"], 5.0)


class BedRotationTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="marco", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_beds_report_recent_families(self):
        today = timezone.localdate()
        # Potatoes (solanaceae) grown in Bed 1 this year.
        Crop.objects.create(crop="potatoes_maincrop", bed="Bed 1", planted_on=today - timedelta(days=30))
        # An old onion crop in Bed 1, beyond the rotation window — excluded.
        Crop.objects.create(crop="onions", bed="Bed 1", planted_on=today - timedelta(days=900))
        # A crop with no bed must not create a phantom bed.
        Crop.objects.create(crop="carrots", planted_on=today)
        res = self.client.get("/api/crops/beds/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        beds = {b["bed"]: b for b in res.data["beds"]}
        self.assertEqual(list(beds), ["Bed 1"])
        self.assertEqual(beds["Bed 1"]["last_family"], "solanaceae")
        self.assertIn("solanaceae", beds["Bed 1"]["recent_families"])
        # The 900-day-old onion is outside the ~14-month window.
        self.assertNotIn("allium", beds["Bed 1"]["recent_families"])

    def test_catalog_exposes_family(self):
        res = self.client.get("/api/crops/catalog/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        potato = next(c for c in res.data if c["key"] == "potatoes_maincrop")
        self.assertEqual(potato["family"], "solanaceae")
        self.assertEqual(potato["family_label"], "Potato & tomato family")
