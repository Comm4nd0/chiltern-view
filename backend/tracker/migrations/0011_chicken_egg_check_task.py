"""Backfill the new "Check for & collect eggs" routine for an existing flock.

The animal-care signal only runs when an animal is created, so chickens already
on the holding would never pick up the egg-check job added to the catalog.
Idempotent the same way the signal is: keyed on auto_key, get_or_create.
"""
from django.db import migrations


def add_egg_check(apps, schema_editor):
    Animal = apps.get_model("tracker", "Animal")
    CareTask = apps.get_model("tracker", "CareTask")
    chicken = Animal.objects.filter(species="chicken", active=True).order_by("pk").first()
    if chicken is None:
        return
    CareTask.objects.get_or_create(
        auto_key="animal:chicken:eggs",
        defaults={
            "name": "Check for & collect eggs",
            "recurrence_interval_days": 1,
            "animal_id": chicken.pk,
        },
    )


def remove_egg_check(apps, schema_editor):
    CareTask = apps.get_model("tracker", "CareTask")
    CareTask.objects.filter(auto_key="animal:chicken:eggs").delete()


class Migration(migrations.Migration):

    dependencies = [
        ("tracker", "0010_caretask_times_done_caretask_times_per_day"),
    ]

    operations = [
        migrations.RunPython(add_egg_check, remove_egg_check),
    ]
