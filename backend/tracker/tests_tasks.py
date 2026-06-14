"""Tests for care-task scheduling: several-times-a-day recurrence, the per-animal
dashboard filter (own tasks + the species' shared routine), and the chicken
egg-check routine."""
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Animal, CareTask, Person


class TimesPerDayTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        self.person = Person.objects.create(name="Marco", user=self.user)
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        patcher = patch("tracker.views.get_weather", return_value=None)
        self.addCleanup(patcher.stop)
        patcher.start()

    def _feed_task(self, times=4):
        return CareTask.objects.create(
            name="Feed the dog", recurrence_interval_days=1, times_per_day=times
        )

    def test_stays_due_until_days_quota_met(self):
        task = self._feed_task(times=4)
        today = timezone.localdate()
        for done in range(1, 4):
            task.mark_done()
            self.assertEqual(task.times_done_today, done)
            self.assertEqual(task.next_due, today, f"still due after {done} of 4")
            self.assertEqual(task.status, "due_today")
        task.mark_done()
        self.assertEqual(task.times_done_today, 4)
        self.assertEqual(task.next_due, today + timedelta(days=1))
        self.assertEqual(task.status, "upcoming")

    def test_counter_resets_on_a_new_day(self):
        task = self._feed_task(times=4)
        task.last_completed = timezone.localdate() - timedelta(days=1)
        task.times_done = 2  # never finished yesterday's feeds
        task.save()
        self.assertEqual(task.times_done_today, 0)
        self.assertEqual(task.next_due, timezone.localdate())
        task.mark_done()
        self.assertEqual(task.times_done_today, 1)

    def test_completion_log_notes_progress(self):
        task = self._feed_task(times=2)
        log = task.mark_done()
        self.assertEqual(log.note, "Completed: Feed the dog (1 of 2 today)")

    def test_once_a_day_task_unaffected(self):
        task = CareTask.objects.create(name="Walk the dog", recurrence_interval_days=1)
        task.mark_done()
        self.assertEqual(task.next_due, timezone.localdate() + timedelta(days=1))
        self.assertEqual(task.times_done_today, 1)

    def test_api_create_and_edit_times_per_day(self):
        res = self.client.post(
            "/api/care-tasks/",
            {"name": "Feed the dog", "recurrence_interval_days": 1, "times_per_day": 4},
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["times_per_day"], 4)
        self.assertEqual(res.data["times_done_today"], 0)
        # Weight back up — drop to twice a day.
        res = self.client.patch(
            f"/api/care-tasks/{res.data['id']}/", {"times_per_day": 2}
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["times_per_day"], 2)

    def test_one_off_cannot_repeat_during_the_day(self):
        res = self.client.post(
            "/api/care-tasks/",
            {
                "name": "Vet visit",
                "due_date": str(timezone.localdate()),
                "times_per_day": 3,
            },
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["times_per_day"], 1)

    def test_complete_endpoint_reports_progress(self):
        task = self._feed_task(times=4)
        res = self.client.post(f"/api/care-tasks/{task.id}/complete/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["times_done_today"], 1)
        self.assertEqual(res.data["status"], "due_today")


class UndoCompletionTests(APITestCase):
    """Undoing an accidental "Done" via the uncomplete action."""

    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        self.person = Person.objects.create(name="Marco", user=self.user)
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_uncomplete_reverts_a_fresh_completion(self):
        task = CareTask.objects.create(name="Walk the dog", recurrence_interval_days=1)
        task.mark_done()
        self.assertEqual(task.last_completed, timezone.localdate())
        self.assertTrue(task.uncomplete())
        self.assertIsNone(task.last_completed)
        self.assertEqual(task.times_done, 0)

    def test_uncomplete_restores_the_previous_completion(self):
        task = CareTask.objects.create(name="Walk the dog", recurrence_interval_days=1)
        yesterday = timezone.localdate() - timedelta(days=1)
        task.mark_done(on=yesterday)
        task.mark_done()  # today
        task.uncomplete()
        self.assertEqual(task.last_completed, yesterday)
        self.assertEqual(task.times_done, 1)

    def test_uncomplete_steps_back_one_of_several_per_day(self):
        task = CareTask.objects.create(
            name="Feed the dog", recurrence_interval_days=1, times_per_day=4
        )
        for _ in range(3):
            task.mark_done()
        self.assertEqual(task.times_done_today, 3)
        task.uncomplete()
        self.assertEqual(task.times_done_today, 2)
        self.assertEqual(task.next_due, timezone.localdate())

    def test_uncomplete_revives_a_completed_one_off(self):
        task = CareTask.objects.create(name="Vet visit", due_date=timezone.localdate())
        task.mark_done()
        self.assertFalse(task.active)
        task.uncomplete()
        self.assertTrue(task.active)
        self.assertIsNone(task.last_completed)

    def test_uncomplete_is_a_noop_when_never_done(self):
        task = CareTask.objects.create(name="Walk the dog", recurrence_interval_days=1)
        self.assertFalse(task.uncomplete())
        self.assertIsNone(task.last_completed)

    def test_uncomplete_endpoint(self):
        task = CareTask.objects.create(name="Walk the dog", recurrence_interval_days=1)
        self.client.post(f"/api/care-tasks/{task.id}/complete/")
        res = self.client.post(f"/api/care-tasks/{task.id}/uncomplete/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["times_done_today"], 0)
        self.assertIsNone(res.data["last_completed"])


class DueTimeTests(APITestCase):
    """Clock-timed tasks (e.g. the 07:30 / 16:00 dog feeds)."""

    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        Person.objects.create(name="Marco", user=self.user)
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_due_time_round_trips(self):
        res = self.client.post(
            "/api/care-tasks/",
            {"name": "Feed the dog", "recurrence_interval_days": 1, "due_time": "07:30"},
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["due_time"], "07:30:00")

    def test_due_time_forces_once_a_day(self):
        res = self.client.post(
            "/api/care-tasks/",
            {
                "name": "Feed the dog",
                "recurrence_interval_days": 1,
                "due_time": "07:30",
                "times_per_day": 4,
            },
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["times_per_day"], 1)

    def test_timeless_task_has_null_due_time(self):
        res = self.client.post(
            "/api/care-tasks/",
            {"name": "Collect the eggs", "recurrence_interval_days": 1},
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIsNone(res.data["due_time"])


class AnimalTaskFilterTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="claire", password="welly-boots-7")
        Person.objects.create(name="Claire", user=self.user)
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        patcher = patch("tracker.views.get_weather", return_value=None)
        self.addCleanup(patcher.stop)
        patcher.start()

    def _names(self, res):
        return {task["name"] for task in res.data}

    def test_animal_filter_includes_species_routine(self):
        first_hen = Animal.objects.create(name="Margo", species="chicken")
        second_hen = Animal.objects.create(name="Peggy", species="chicken")
        dog = Animal.objects.create(name="Bella", species="dog")
        CareTask.objects.create(name="Bella's medicine", animal=dog, recurrence_interval_days=1)

        # The flock routine hangs off the first hen, but shows for every hen.
        res = self.client.get("/api/care-tasks/dashboard/", {"animal": second_hen.id})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        names = self._names(res)
        self.assertIn("Check for & collect eggs", names)
        self.assertIn("Let the hens out & check water", names)
        self.assertNotIn("Feed the dog", names)
        self.assertNotIn("Bella's medicine", names)

        res = self.client.get("/api/care-tasks/dashboard/", {"animal": first_hen.id})
        self.assertEqual(self._names(res), names)

        # The dog's page: its species routine plus its own hand-added task.
        res = self.client.get("/api/care-tasks/dashboard/", {"animal": dog.id})
        names = self._names(res)
        self.assertIn("Feed the dog", names)
        self.assertIn("Bella's medicine", names)
        self.assertNotIn("Check for & collect eggs", names)

    def test_unknown_animal_returns_nothing(self):
        Animal.objects.create(name="Margo", species="chicken")
        res = self.client.get("/api/care-tasks/dashboard/", {"animal": "9999"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data, [])

    def test_new_chicken_gets_egg_check_routine(self):
        Animal.objects.create(name="Margo", species="chicken")
        task = CareTask.objects.get(auto_key="animal:chicken:eggs")
        self.assertEqual(task.name, "Check for & collect eggs")
        self.assertEqual(task.recurrence_interval_days, 1)
