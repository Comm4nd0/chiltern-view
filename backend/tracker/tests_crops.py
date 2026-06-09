"""Tests for the crop lifecycle: auto reminders must follow harvest/edit/delete."""
from datetime import date
from decimal import Decimal

from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import CareTask, Crop, LogEntry


class CropLifecycleTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="marco", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def make_crop(self, **overrides):
        payload = {"crop": "carrots", "planted_on": "2026-04-01", **overrides}
        res = self.client.post("/api/crops/", payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        return Crop.objects.get(pk=res.data["id"])

    def auto_tasks(self, crop):
        return CareTask.objects.filter(auto_key__startswith=f"crop:{crop.pk}:")

    def test_create_makes_water_and_harvest_reminders(self):
        crop = self.make_crop()
        keys = set(self.auto_tasks(crop).values_list("auto_key", flat=True))
        self.assertEqual(keys, {f"crop:{crop.pk}:water", f"crop:{crop.pk}:harvest"})

    def test_harvest_action_records_yield_and_retires_reminders(self):
        crop = self.make_crop()
        res = self.client.post(
            f"/api/crops/{crop.pk}/harvest/",
            {"date": "2026-07-15", "yield_kg": "12.5", "note": "Good year"},
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        crop.refresh_from_db()
        self.assertEqual(crop.harvested_on, date(2026, 7, 15))
        self.assertEqual(crop.yield_kg, Decimal("12.5"))
        self.assertIn("Good year", crop.notes)
        # Both auto reminders are closed, not deleted.
        self.assertEqual(self.auto_tasks(crop).count(), 2)
        self.assertFalse(self.auto_tasks(crop).filter(active=True).exists())
        # And the harvest landed in the log.
        log = LogEntry.objects.filter(note__startswith="Harvested").get()
        self.assertEqual(log.occurred_on, date(2026, 7, 15))
        self.assertIn("12.5 kg", log.note)

    def test_harvest_rejects_bad_yield(self):
        crop = self.make_crop()
        res = self.client.post(f"/api/crops/{crop.pk}/harvest/", {"yield_kg": "a lot"})
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        crop.refresh_from_db()
        self.assertIsNone(crop.harvested_on)

    def test_patch_harvested_on_also_retires_reminders(self):
        crop = self.make_crop()
        res = self.client.patch(
            f"/api/crops/{crop.pk}/", {"harvested_on": "2026-07-01"}, format="json"
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(self.auto_tasks(crop).filter(active=True).exists())

    def test_unharvest_reactivates_reminders(self):
        crop = self.make_crop()
        self.client.post(f"/api/crops/{crop.pk}/harvest/")
        res = self.client.patch(
            f"/api/crops/{crop.pk}/", {"harvested_on": None}, format="json"
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        water = CareTask.objects.get(auto_key=f"crop:{crop.pk}:water")
        harvest = CareTask.objects.get(auto_key=f"crop:{crop.pk}:harvest")
        self.assertTrue(water.active)
        self.assertTrue(harvest.active)

    def test_moving_dates_repoints_harvest_reminder(self):
        crop = self.make_crop()
        res = self.client.patch(
            f"/api/crops/{crop.pk}/", {"expected_harvest": "2026-09-30"}, format="json"
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        harvest = CareTask.objects.get(auto_key=f"crop:{crop.pk}:harvest")
        self.assertEqual(harvest.due_date, date(2026, 9, 30))

    def test_delete_removes_auto_reminders(self):
        crop = self.make_crop()
        prefix = f"crop:{crop.pk}:"
        res = self.client.delete(f"/api/crops/{crop.pk}/")
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(CareTask.objects.filter(auto_key__startswith=prefix).exists())
