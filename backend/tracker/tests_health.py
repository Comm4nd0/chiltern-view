"""Tests for animal weight tracking and medication withdrawal periods."""
from datetime import timedelta

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Animal, LogEntry, WeightRecord


class WeightTrackingTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="marco", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.animal = Animal.objects.create(name="Gertie", species="goat")

    def test_log_and_list_weights_oldest_first(self):
        today = timezone.localdate()
        res = self.client.post(
            "/api/weight-records/",
            {"animal": self.animal.id, "date": str(today), "weight_kg": "42.5"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        WeightRecord.objects.create(
            animal=self.animal, date=today - timedelta(days=10), weight_kg="40.0"
        )
        res = self.client.get("/api/weight-records/", {"animal": self.animal.id})
        weights = res.data["results"] if isinstance(res.data, dict) else res.data
        # Oldest-first, so a client can plot the growth trend directly.
        self.assertEqual([w["weight_kg"] for w in weights], ["40.00", "42.50"])

    def test_weight_filtered_by_animal(self):
        other = Animal.objects.create(name="Billy", species="goat")
        WeightRecord.objects.create(animal=self.animal, weight_kg="42.5")
        WeightRecord.objects.create(animal=other, weight_kg="50.0")
        res = self.client.get("/api/weight-records/", {"animal": other.id})
        weights = res.data["results"] if isinstance(res.data, dict) else res.data
        self.assertEqual(len(weights), 1)
        self.assertEqual(weights[0]["weight_kg"], "50.00")


class MedicationWithdrawalTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="claire", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.hen = Animal.objects.create(name="Henrietta", species="chicken")

    def test_health_entry_computes_withdrawal_until(self):
        today = timezone.localdate()
        res = self.client.post(
            "/api/log-entries/",
            {
                "entry_type": "health",
                "note": "Flubenvet wormer",
                "animal": self.hen.id,
                "medicine": "Flubenvet",
                "withdrawal_days": 7,
                "occurred_on": str(today),
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["withdrawal_until"], str(today + timedelta(days=7)))
        self.assertTrue(res.data["withdrawal_active"])

    def test_overview_surfaces_active_withdrawal(self):
        today = timezone.localdate()
        LogEntry.objects.create(
            entry_type=LogEntry.EntryType.HEALTH,
            note="Wormer",
            animal=self.hen,
            medicine="Flubenvet",
            withdrawal_days=7,
            occurred_on=today - timedelta(days=2),
        )
        # An expired one must not show.
        LogEntry.objects.create(
            entry_type=LogEntry.EntryType.HEALTH,
            note="Old treatment",
            animal=self.hen,
            medicine="Old",
            withdrawal_days=3,
            occurred_on=today - timedelta(days=30),
        )
        res = self.client.get("/api/overview/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data["withdrawals"]), 1)
        self.assertEqual(res.data["withdrawals"][0]["medicine"], "Flubenvet")
        self.assertEqual(res.data["withdrawals"][0]["until"], today + timedelta(days=5))

    def test_plain_note_has_no_withdrawal(self):
        res = self.client.post(
            "/api/log-entries/",
            {"entry_type": "general", "note": "Looking healthy", "animal": self.hen.id},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIsNone(res.data["withdrawal_until"])
        self.assertFalse(res.data["withdrawal_active"])
