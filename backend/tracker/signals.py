"""Auto-create care reminders from the built-in knowledge in ``care_knowledge``.

When an animal or crop is added (via the API or the admin), the routine jobs for
that kind of animal/crop are created as CareTasks. Creation is idempotent: each
task carries a stable ``auto_key`` and is made with ``get_or_create``, so existing
reminders are never duplicated (e.g. adding a second hen reuses the flock routine).
"""
from django.db.models.signals import post_save, pre_delete
from django.dispatch import receiver

from .care_knowledge import animal_care_specs, crop_care_specs
from .care_sync import delete_crop_tasks
from .models import Animal, CareTask, Crop


def apply_care_specs(specs):
    """Create a CareTask for each spec that doesn't already exist (by auto_key)."""
    created = []
    for spec in specs:
        task, was_created = CareTask.objects.get_or_create(
            auto_key=spec["auto_key"],
            defaults={
                "name": spec["name"],
                "recurrence_interval_days": spec.get("interval_days", 7),
                "due_date": spec.get("due_date"),
                "animal": spec.get("animal"),
            },
        )
        if was_created:
            created.append(task)
    return created


@receiver(post_save, sender=Animal, dispatch_uid="tracker_animal_care")
def create_animal_care(sender, instance, created, **kwargs):
    if created and instance.active:
        apply_care_specs(animal_care_specs(instance))


@receiver(post_save, sender=Crop, dispatch_uid="tracker_crop_care")
def create_crop_care(sender, instance, created, **kwargs):
    if created and not instance.harvested_on:
        apply_care_specs(crop_care_specs(instance))


@receiver(pre_delete, sender=Crop, dispatch_uid="tracker_crop_care_delete")
def remove_crop_care(sender, instance, **kwargs):
    """Deleting a crop takes its auto-generated reminders with it."""
    delete_crop_tasks(instance)
