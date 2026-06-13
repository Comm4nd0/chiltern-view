"""Keep auto-generated care reminders in step with their crop or animal.

``signals.py`` creates the reminders when a crop or animal is added; this module
retires and restores them as the crop/animal changes. Crops: reminders are retired
on harvest, restored if a harvest is undone or dates change, and removed on delete
(all via the ``crop:{pk}:`` auto_key prefix). Animals: the shared species routine
is deactivated when the last animal of that species leaves and reactivated when one
returns, while a generic (per-individual) routine follows that one animal — see
``reconcile_animal_care``.
"""
import re

from .care_knowledge import animal_care_specs, crop_care_specs
from .models import Animal, CareTask


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
        if not task.active and not _completed_one_off(task, spec):
            # Reactivate a reminder closed by harvest, but don't resurrect a
            # one-off (a stage or harvest job) the user has already ticked off.
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


def _completed_one_off(task, spec):
    """True for a one-off reminder the user already completed (so leave it closed)."""
    return bool(spec.get("due_date") and task.last_completed)


# --- Animals ---------------------------------------------------------------
# Auto-keys are either species-level ("animal:chicken:feed", whole-flock, shared)
# or per-individual ("animal:other:42:check", for species with no built-in
# routine). This splits the two so the reconcile below can treat them correctly.
_ANIMAL_KEY = re.compile(r"^animal:(?P<species>[^:]+):(?:(?P<pk>\d+):)?(?P<leaf>.+)$")


def reconcile_animal_care():
    """Switch animal reminders on/off to match which animals are still kept.

    A species' shared routine is active while at least one animal of that species
    is active, and deactivated otherwise (the last hen left). A per-individual
    routine follows its own animal: deactivated when that animal is retired, and
    deleted outright once the animal row is gone. Idempotent — safe to run on
    every animal save or delete.
    """
    active_species = set(
        Animal.objects.filter(active=True).values_list("species", flat=True)
    )
    active_pks = set(Animal.objects.filter(active=True).values_list("pk", flat=True))
    existing_pks = set(Animal.objects.values_list("pk", flat=True))

    for task in CareTask.objects.filter(auto_key__startswith="animal:"):
        match = _ANIMAL_KEY.match(task.auto_key)
        if not match:
            continue
        if match.group("pk") is not None:
            pk = int(match.group("pk"))
            if pk not in existing_pks:
                task.delete()  # the animal is gone — its private routine goes too
                continue
            should_be_active = pk in active_pks
        else:
            should_be_active = match.group("species") in active_species
        if task.active != should_be_active:
            task.active = should_be_active
            task.save(update_fields=["active", "updated_at"])
