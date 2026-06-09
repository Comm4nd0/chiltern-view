"""Tests for the holding journal: log entry authorship, type filtering, and the
recent-activity feed on the overview."""
from unittest.mock import patch

from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Animal, CareTask, LogEntry, Person


class JournalTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        self.person = Person.objects.create(name="Marco", user=self.user)
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.animal = Animal.objects.create(name="Clover", species="goat")
        # Keep the overview's weather lookup off the network.
        patcher = patch("tracker.views.get_weather", return_value=None)
        self.addCleanup(patcher.stop)
        patcher.start()

    def test_create_stamps_author_from_login(self):
        res = self.client.post(
            "/api/log-entries/",
            {"entry_type": "health", "note": "Limping on left rear", "animal": self.animal.id},
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["created_by"], self.person.id)
        self.assertEqual(res.data["created_by_name"], "Marco")

    def test_client_cannot_spoof_author(self):
        other = Person.objects.create(name="Claire")
        res = self.client.post(
            "/api/log-entries/",
            {"entry_type": "general", "note": "Fox about", "created_by": other.id},
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["created_by"], self.person.id)

    def test_types_csv_filter(self):
        LogEntry.objects.create(entry_type="health", note="Wormed", animal=self.animal)
        LogEntry.objects.create(entry_type="feeding", note="Extra hay", animal=self.animal)
        task = CareTask.objects.create(name="Check the goats")
        task.mark_done()  # creates a task_completed entry
        res = self.client.get("/api/log-entries/", {"types": "health,feeding"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        notes = [e["note"] for e in res.data["results"]]
        self.assertIn("Wormed", notes)
        self.assertIn("Extra hay", notes)
        self.assertEqual(len(notes), 2)

    def test_overview_activity_excludes_completions(self):
        LogEntry.objects.create(entry_type="health", note="Hoof trim", animal=self.animal)
        task = CareTask.objects.create(name="Check the goats")
        task.mark_done()
        res = self.client.get("/api/overview/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        notes = [e["note"] for e in res.data["activity"]]
        self.assertIn("Hoof trim", notes)
        self.assertFalse(any("Completed" in n for n in notes))

    def test_overview_activity_caps_at_five(self):
        for i in range(7):
            LogEntry.objects.create(entry_type="general", note=f"Note {i}")
        res = self.client.get("/api/overview/")
        self.assertEqual(len(res.data["activity"]), 5)
