"""Create weather-driven reminders (currently: frost-protection for tender crops).

Run by the compose ``scheduler`` service alongside ``send_push_reminders``. Unlike
that command it has no config gate, so frost reminders work even when web push is
disabled. Idempotent — one reminder per frost night (see ``weather_tasks``).
"""
from django.core.management.base import BaseCommand

from ...weather_tasks import sync_frost_task


class Command(BaseCommand):
    help = "Create care reminders from the local weather forecast (e.g. frost cover)."

    def handle(self, *args, **options):
        task = sync_frost_task()
        if task:
            self.stdout.write(f"Frost reminder in place: {task.name}")
        else:
            self.stdout.write("No weather reminders needed.")
