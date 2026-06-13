"""Turn weather warnings into to-do reminders.

The dashboard's frost warning (``weather.frost_warning``) is only seen by whoever
opens the app. This promotes it to a real one-off ``CareTask`` so it flows through
the same to-do list and push reminders as everything else. Created idempotently,
keyed by the frost night, so the scheduler can call it on every loop and a given
cold snap raises exactly one reminder.
"""
from django.utils.dateparse import parse_date

from .models import CareTask
from .weather import frost_warning, get_weather


def sync_frost_task(weather=None):
    """Ensure a 'cover tender crops' reminder exists for a forecast frost.

    Returns the CareTask if one is in place for the coming frost, else None.
    """
    weather = weather or get_weather()
    warning = frost_warning(weather)
    if not warning:
        return None
    first_night = warning["nights"][0]
    task, _ = CareTask.objects.get_or_create(
        auto_key=f"weather:frost:{first_night}",
        defaults={"name": warning["message"], "due_date": parse_date(first_night)},
    )
    return task
