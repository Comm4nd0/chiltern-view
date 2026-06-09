from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("tracker", "0004_crop_delete_potatoplanting"),
    ]

    operations = [
        migrations.AddField(
            model_name="caretask",
            name="due_date",
            field=models.DateField(
                blank=True,
                null=True,
                help_text="For one-off tasks: the date it's due. Leave blank for recurring tasks.",
            ),
        ),
        migrations.AddField(
            model_name="caretask",
            name="auto_key",
            field=models.CharField(
                blank=True,
                db_index=True,
                default="",
                help_text="Stable key for auto-generated reminders; blank for tasks added by hand.",
                max_length=120,
            ),
        ),
    ]
