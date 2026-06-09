"""Keep a crop's auto-generated care reminders in step with its lifecycle.

``signals.py`` creates the reminders when a crop is added; this module retires
them when the crop is harvested, restores them if a harvest is undone or dates
change, and removes them when the crop is deleted. All lookups go through the
``crop:{pk}:`` auto_key prefix — the only link between a crop and its reminders.
"""
from .care_knowledge import crop_care_specs
from .models import CareTask


def crop_task_prefix(crop):
    return f"crop:{crop.pk}:"


def close_crop_tasks(crop):
    """Deactivate the crop's auto reminders (the crop is out of the ground)."""
    return CareTask.objects.filter(
        auto_key__startswith=crop_task_prefix(crop), active=True
    ).update(active=False)


def delete_crop_tasks(crop):
    """Remove the crop's auto reminders entirely (the crop row is going away).

    These are machine-made rows; ``LogEntry.care_task`` is SET_NULL, so any
    completion history survives the delete.
    """
    return CareTask.objects.filter(auto_key__startswith=crop_task_prefix(crop)).delete()


def resync_crop_tasks(crop):
    """Bring the crop's auto reminders back in line with its current state.

    Harvested crops get their reminders closed. Growing crops get the watering
    job and harvest reminder (re)created, reactivated if a harvest was undone,
    and the harvest reminder re-pointed at the current estimated date. Existing
    rows are updated explicitly because ``get_or_create`` alone would find a
    closed task and leave it inactive.
    """
    if crop.harvested_on:
        close_crop_tasks(crop)
        return
    for spec in crop_care_specs(crop):
        task, created = CareTask.objects.get_or_create(
            auto_key=spec["auto_key"],
            defaults={
                "name": spec["name"],
                "recurrence_interval_days": spec.get("interval_days", 7),
                "due_date": spec.get("due_date"),
            },
        )
        if created:
            continue
        updates = []
        if not task.active:
            task.active = True
            updates.append("active")
        if spec.get("due_date") and task.due_date != spec["due_date"]:
            task.due_date = spec["due_date"]
            updates.append("due_date")
        # Editing the crop type or bed changes the spec's name/interval too.
        if task.name != spec["name"]:
            task.name = spec["name"]
            updates.append("name")
        interval = spec.get("interval_days")
        if interval and task.recurrence_interval_days != interval:
            task.recurrence_interval_days = interval
            updates.append("recurrence_interval_days")
        if updates:
            task.save(update_fields=updates + ["updated_at"])
