from django.apps import AppConfig


class TrackerConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "tracker"
    verbose_name = "Smallholding tracker"

    def ready(self):
        # Connect the post_save handlers that auto-create care reminders.
        from . import signals  # noqa: F401
