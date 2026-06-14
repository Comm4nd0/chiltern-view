"""Tests for web push: subscription endpoints and the daily reminder command."""
import datetime as dt
import json
from datetime import timedelta
from unittest.mock import Mock, patch

from django.contrib.auth.models import User
from django.core.management import call_command
from django.test import override_settings
from django.utils import timezone
from pywebpush import WebPushException
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import CareTask, Person, PushReminderLog, PushSubscription


def noon_today(*args, **kwargs):
    """A fixed local 'now' (12:00 today) so timed-task tests aren't wall-clock flaky.
    Accepts/ignores args since patching timezone.localtime catches incidental calls.
    Uses dt.date.today() (not timezone.localdate, which would recurse via localtime)."""
    return timezone.make_aware(dt.datetime.combine(dt.date.today(), dt.time(12, 0)))

SUB_JSON = {
    "endpoint": "https://push.example/abc",
    "keys": {"p256dh": "key-p256dh", "auth": "key-auth"},
}


def make_subscription(user, endpoint="https://push.example/abc"):
    return PushSubscription.objects.create(
        user=user, endpoint=endpoint, p256dh="key-p256dh", auth="key-auth"
    )


@override_settings(
    VAPID_PUBLIC_KEY="test-public",
    VAPID_PRIVATE_KEY="test-private",
    PUSH_REMINDER_HOUR=0,  # always past the send hour in tests
)
class PushApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        self.person = Person.objects.create(name="Marco", user=self.user)
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_vapid_public_key(self):
        res = self.client.get("/api/push/vapid-public-key/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["key"], "test-public")

    def test_subscribe_upserts_and_follows_login(self):
        res = self.client.post("/api/push/subscribe/", SUB_JSON, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        sub = PushSubscription.objects.get()
        self.assertEqual(sub.user, self.user)

        # Claire signs in on the same browser: the endpoint moves to her.
        claire = User.objects.create_user(username="claire", password="welly-boots-8")
        claire_token = Token.objects.create(user=claire)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {claire_token.key}")
        res = self.client.post("/api/push/subscribe/", SUB_JSON, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(PushSubscription.objects.count(), 1)
        self.assertEqual(PushSubscription.objects.get().user, claire)

    def test_subscribe_rejects_garbage(self):
        res = self.client.post("/api/push/subscribe/", {"endpoint": ""}, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_unsubscribe_deletes(self):
        make_subscription(self.user)
        res = self.client.post(
            "/api/push/unsubscribe/", {"endpoint": SUB_JSON["endpoint"]}, format="json"
        )
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(PushSubscription.objects.count(), 0)


@override_settings(
    VAPID_PUBLIC_KEY="test-public",
    VAPID_PRIVATE_KEY="test-private",
    PUSH_REMINDER_HOUR=0,
)
@patch("tracker.management.commands.send_push_reminders.get_weather", return_value=None)
class PushCommandTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        self.person = Person.objects.create(name="Marco", user=self.user)
        self.sub = make_subscription(self.user)

    def make_due_task(self, name="Feed the pigs"):
        return CareTask.objects.create(
            name=name,
            assignee=self.person,
            recurrence_interval_days=7,
            last_completed=timezone.localdate() - timedelta(days=7),  # due today
        )

    @patch("tracker.management.commands.send_push_reminders.webpush")
    def test_sends_digest_and_ping_once_per_day(self, mock_push, _weather):
        self.make_due_task()
        call_command("send_push_reminders")
        titles = [
            __import__("json").loads(call.kwargs["data"])["title"]
            for call in mock_push.call_args_list
        ]
        self.assertIn("Tasks to do", titles)
        self.assertIn("Due today: Feed the pigs", titles)
        self.sub.refresh_from_db()
        self.assertEqual(self.sub.last_sent_date, timezone.localdate())

        # A second run the same day sends nothing more.
        mock_push.reset_mock()
        call_command("send_push_reminders")
        mock_push.assert_not_called()

    @patch("tracker.management.commands.send_push_reminders.webpush")
    def test_nothing_due_stamps_without_sending(self, mock_push, _weather):
        CareTask.objects.create(
            name="Worm the goats",
            assignee=self.person,
            recurrence_interval_days=90,
            last_completed=timezone.localdate(),  # not due for ages
        )
        call_command("send_push_reminders")
        mock_push.assert_not_called()
        self.sub.refresh_from_db()
        self.assertEqual(self.sub.last_sent_date, timezone.localdate())

    @patch("tracker.management.commands.send_push_reminders.webpush")
    def test_dead_subscription_is_pruned(self, mock_push, _weather):
        self.make_due_task()
        gone = WebPushException("gone", response=Mock(status_code=410))
        mock_push.side_effect = gone
        call_command("send_push_reminders")
        self.assertEqual(PushSubscription.objects.count(), 0)

    @patch("tracker.management.commands.send_push_reminders.webpush")
    def test_transient_failure_retries_next_run(self, mock_push, _weather):
        self.make_due_task()
        mock_push.side_effect = WebPushException("boom", response=Mock(status_code=500))
        call_command("send_push_reminders")
        self.sub.refresh_from_db()
        self.assertIsNone(self.sub.last_sent_date)  # unstamped → retried next run

    @patch("tracker.management.commands.send_push_reminders.webpush")
    def test_user_without_person_is_skipped(self, mock_push, _weather):
        loner = User.objects.create_user(username="loner", password="x")
        lonely_sub = make_subscription(loner, endpoint="https://push.example/loner")
        call_command("send_push_reminders")
        lonely_sub.refresh_from_db()
        self.assertEqual(lonely_sub.last_sent_date, timezone.localdate())
        sent_to = [call.kwargs["subscription_info"]["endpoint"] for call in mock_push.call_args_list]
        self.assertNotIn("https://push.example/loner", sent_to)

    def make_timed_task(self, due_time, name="Feed the dog"):
        """A daily task due today, pinned to a clock time."""
        return CareTask.objects.create(
            name=name,
            assignee=self.person,
            recurrence_interval_days=1,
            last_completed=timezone.localdate() - timedelta(days=1),  # due today
            due_time=due_time,
        )

    @patch("tracker.management.commands.send_push_reminders.timezone.localtime", side_effect=noon_today)
    @patch("tracker.management.commands.send_push_reminders.webpush")
    def test_timed_task_pings_once_when_its_time_has_passed(self, mock_push, _now, _weather):
        self.make_timed_task(dt.time(7, 30))  # 07:30, already past noon-fixed now
        call_command("send_push_reminders")
        titles = [json.loads(call.kwargs["data"])["title"] for call in mock_push.call_args_list]
        self.assertIn("Time to: Feed the dog", titles)
        self.assertNotIn("Tasks to do", titles)  # timed task isn't in the digest
        self.assertEqual(PushReminderLog.objects.count(), 1)

        # A second run the same day must not re-ping it.
        mock_push.reset_mock()
        call_command("send_push_reminders")
        mock_push.assert_not_called()

    @patch("tracker.management.commands.send_push_reminders.timezone.localtime", side_effect=noon_today)
    @patch("tracker.management.commands.send_push_reminders.webpush")
    def test_timed_task_waits_until_its_time(self, mock_push, _now, _weather):
        self.make_timed_task(dt.time(16, 0))  # 16:00, still ahead of noon-fixed now
        call_command("send_push_reminders")
        mock_push.assert_not_called()
        self.assertEqual(PushReminderLog.objects.count(), 0)
