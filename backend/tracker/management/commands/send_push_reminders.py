"""Send web-push task reminders: timed pings plus a morning digest.

Mirrors the phone app's on-device reminders (``notification_service.dart``):

* A task pinned to a clock time (e.g. feed the dog at 07:30) gets a **timed
  ping** when its time arrives, whatever the hour — deduped per task per day via
  ``PushReminderLog`` so the scheduler loop only sends it once.
* Everything else (timeless jobs like collecting eggs) is gathered into one
  **morning digest** after ``PUSH_REMINDER_HOUR`` — same wording as mobile — plus
  a "Due today" ping per timeless task actually due today (capped). The digest is
  deduped per subscription per day via ``PushSubscription.last_sent_date``.

Rain-deferred watering jobs are left out, matching the dashboard. The scheduler
loop can run this every few minutes; both passes are idempotent. A transient send
failure leaves the dedup stamp unset so the next run retries; a 404/410 from the
push service deletes the subscription (browser revoked it).
"""
import json
from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand
from django.utils import timezone
from pywebpush import WebPushException, webpush

from ...models import CareTask, PushReminderLog, PushSubscription
from ...views import person_for
from ...watering import apply_rain_deferral
from ...weather import get_weather

MAX_PINGS = 5  # cap per-task notifications; the digest covers the rest
PRUNE_AFTER_DAYS = 7  # keep timed-ping dedup rows around briefly, then bin them


def digest_body(due):
    """Same wording as the mobile digest, so both platforms read identically."""
    names = ", ".join(task.name for task in due[:4])
    extra = f" +{len(due) - 4} more" if len(due) > 4 else ""
    plural = "" if len(due) == 1 else "s"
    return f"{len(due)} task{plural} to do: {names}{extra}"


class Command(BaseCommand):
    help = "Send due-task web push reminders (timed pings + one daily digest per browser)."

    def handle(self, *args, **options):
        if not settings.VAPID_PRIVATE_KEY:
            self.stdout.write("Web push not configured (no VAPID keys); nothing to do.")
            return
        now = timezone.localtime()
        today = now.date()
        subscriptions = list(PushSubscription.objects.select_related("user"))
        if not subscriptions:
            return
        weather = get_weather()
        digest_due = now.hour >= settings.PUSH_REMINDER_HOUR
        for sub in subscriptions:
            person = person_for(sub.user)
            if person is None:
                # Same gate as mobile: reminders need a linked person. Stamp the
                # digest (after the hour) so we don't reconsider it all day.
                if digest_due and sub.last_sent_date != today:
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
            # Pass 1: timed pings — any hour, deduped per task per day.
            if not self._send_timed(sub, due, now, today):
                continue  # subscription pruned mid-pass; don't touch it again
            # Pass 2: morning digest — timeless tasks only, once a day.
            if digest_due and sub.last_sent_date != today:
                self._send_digest(sub, due, today)
        self._prune(today)
        self.stdout.write(f"Processed {len(subscriptions)} subscription(s).")

    def _send_timed(self, sub, due, now, today):
        """Ping each clock-timed task whose time has arrived. Returns False if the
        subscription was pruned (browser gone), True otherwise."""
        pending = [
            task
            for task in due
            if task.due_time is not None
            and task.due_time <= now.time()
            and not PushReminderLog.objects.filter(
                subscription=sub, care_task=task, sent_date=today
            ).exists()
        ]
        pending.sort(key=lambda task: task.due_time)
        for task in pending:
            detail = f"For {task.animal.name}" if task.animal else "Care task due now"
            outcome = self._push(sub, f"Time to: {task.name}", detail, tag=f"task-{task.id}")
            if outcome is None:
                return False  # subscription pruned
            if outcome:
                PushReminderLog.objects.get_or_create(
                    subscription=sub, care_task=task, sent_date=today
                )
            # outcome False → transient: leave unlogged so the next run retries.
        return True

    def _send_digest(self, sub, due, today):
        """One digest of timeless due tasks, plus a ping per timeless task due
        today. Timed tasks are handled by ``_send_timed``."""
        timeless = [task for task in due if task.due_time is None]
        timeless.sort(key=lambda task: task.days_overdue, reverse=True)
        if not timeless:
            self._stamp(sub, today)
            return
        outcome = self._push(sub, "Tasks to do", digest_body(timeless), tag="chiltern-digest")
        if outcome is None:
            return  # subscription pruned
        if outcome:
            for task in [t for t in timeless if t.days_overdue == 0][:MAX_PINGS]:
                detail = f"For {task.animal.name}" if task.animal else "Care task due today"
                self._push(sub, f"Due today: {task.name}", detail, tag=f"task-{task.id}")
            self._stamp(sub, today)
        # outcome False → transient failure: leave unstamped so the next run retries.

    def _prune(self, today):
        cutoff = today - timedelta(days=PRUNE_AFTER_DAYS)
        PushReminderLog.objects.filter(sent_date__lt=cutoff).delete()

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
