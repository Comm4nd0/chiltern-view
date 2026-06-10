"""Send web-push task reminders: a morning digest plus due-today pings.

Mirrors the phone app's on-device reminders (``notification_service.dart``):
after ``PUSH_REMINDER_HOUR`` local time, each subscription gets one digest
listing everything due or overdue for its person — same wording as mobile —
plus a "Due today" ping per task actually due today (capped). Rain-deferred
watering jobs are left out, matching the dashboard.

Idempotent via ``PushSubscription.last_sent_date``: the scheduler loop can run
this every few minutes and each browser still gets at most one batch a day.
A transient send failure leaves the stamp unset so the next run retries; a
404/410 from the push service deletes the subscription (browser revoked it).
"""
import json

from django.conf import settings
from django.core.management.base import BaseCommand
from django.utils import timezone
from pywebpush import WebPushException, webpush

from ...models import CareTask, PushSubscription
from ...views import person_for
from ...watering import apply_rain_deferral
from ...weather import get_weather

MAX_PINGS = 5  # cap per-task notifications; the digest covers the rest


def digest_body(due):
    """Same wording as the mobile digest, so both platforms read identically."""
    names = ", ".join(task.name for task in due[:4])
    extra = f" +{len(due) - 4} more" if len(due) > 4 else ""
    plural = "" if len(due) == 1 else "s"
    return f"{len(due)} task{plural} to do: {names}{extra}"


class Command(BaseCommand):
    help = "Send due-task web push reminders (at most one batch per subscription per day)."

    def handle(self, *args, **options):
        if not settings.VAPID_PRIVATE_KEY:
            self.stdout.write("Web push not configured (no VAPID keys); nothing to do.")
            return
        now = timezone.localtime()
        today = now.date()
        if now.hour < settings.PUSH_REMINDER_HOUR:
            return
        subscriptions = list(
            PushSubscription.objects.select_related("user").exclude(last_sent_date=today)
        )
        if not subscriptions:
            return
        weather = get_weather()
        for sub in subscriptions:
            person = person_for(sub.user)
            if person is None:
                # Same gate as mobile: reminders need a linked person.
                self._stamp(sub, today)
                continue
            tasks = list(
                CareTask.objects.select_related("animal").filter(active=True, assignee=person)
            )
            apply_rain_deferral(tasks, weather)
            due = [
                task
                for task in tasks
                if task.days_overdue >= 0 and not getattr(task, "rain_deferred", False)
            ]
            due.sort(key=lambda task: task.days_overdue, reverse=True)
            if not due:
                self._stamp(sub, today)
                continue
            outcome = self._push(sub, "Tasks to do", digest_body(due), tag="chiltern-digest")
            if outcome is None:
                continue  # subscription pruned
            if outcome:
                for task in [t for t in due if t.days_overdue == 0][:MAX_PINGS]:
                    detail = f"For {task.animal.name}" if task.animal else "Care task due today"
                    self._push(sub, f"Due today: {task.name}", detail, tag=f"task-{task.id}")
                self._stamp(sub, today)
            # outcome is False → transient failure: leave unstamped so the
            # next scheduler run retries.
        self.stdout.write(f"Processed {len(subscriptions)} subscription(s).")

    def _stamp(self, sub, today):
        sub.last_sent_date = today
        sub.save(update_fields=["last_sent_date"])

    def _push(self, sub, title, body, tag):
        """One notification. Returns True/False, or None when the subscription
        was pruned because the push service reports it gone (404/410)."""
        payload = json.dumps({"title": title, "body": body, "url": "/todo", "tag": tag})
        try:
            webpush(
                subscription_info={
                    "endpoint": sub.endpoint,
                    "keys": {"p256dh": sub.p256dh, "auth": sub.auth},
                },
                data=payload,
                vapid_private_key=settings.VAPID_PRIVATE_KEY,
                vapid_claims={"sub": f"mailto:{settings.VAPID_CLAIMS_EMAIL}"},
                ttl=6 * 3600,
            )
            return True
        except WebPushException as exc:
            status_code = getattr(getattr(exc, "response", None), "status_code", None)
            if status_code in (404, 410):
                sub.delete()
                return None
            self.stderr.write(f"Push failed for {sub.endpoint[:40]}: {exc}")
            return False
        except Exception as exc:  # network down etc. — transient, retry next run
            self.stderr.write(f"Push errored for {sub.endpoint[:40]}: {exc}")
            return False
