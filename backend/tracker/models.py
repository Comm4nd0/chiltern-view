"""Domain models for the Chiltern View smallholding tracker."""
from datetime import timedelta

from django.db import models
from django.utils import timezone

from .crops import CROP_CATALOG, DEFAULT_DAYS_TO_HARVEST, DEFAULT_STAGES


class Animal(models.Model):
    """An animal (or colony) kept on the smallholding."""

    class Species(models.TextChoices):
        CHICKEN = "chicken", "Chicken"
        DUCK = "duck", "Duck"
        GOOSE = "goose", "Goose"
        TURKEY = "turkey", "Turkey"
        GOAT = "goat", "Goat"
        SHEEP = "sheep", "Sheep"
        PIG = "pig", "Pig"
        COW = "cow", "Cow"
        RABBIT = "rabbit", "Rabbit"
        BEES = "bees", "Bee colony"
        HORSE = "horse", "Horse"
        TORTOISE = "tortoise", "Tortoise"
        DOG = "dog", "Dog"
        CAT = "cat", "Cat"
        OTHER = "other", "Other"

    name = models.CharField(max_length=100)
    species = models.CharField(max_length=20, choices=Species.choices, default=Species.CHICKEN)
    breed = models.CharField(max_length=100, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    acquired_on = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    active = models.BooleanField(default=True, help_text="Untick when the animal leaves the holding.")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return f"{self.name} ({self.get_species_display()})"


class Person(models.Model):
    """Someone who looks after the holding — used to assign care tasks.

    Lightweight (just a name), with an optional link to a login account: each
    household user (Marco, Claire) is a ``Person`` linked to an ``auth.User``.
    The link is nullable so a Person can exist without a login, and ``SET_NULL``
    keeps the Person (and their task history) if the account is ever deleted.
    """

    name = models.CharField(max_length=100, unique=True)
    user = models.OneToOneField(
        "auth.User",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="person",
        help_text="Login account linked to this person.",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]
        verbose_name_plural = "people"

    def __str__(self):
        return self.name


class CareTask(models.Model):
    """A recurring husbandry job, e.g. "worm the goats" every 90 days."""

    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    animal = models.ForeignKey(
        Animal,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="care_tasks",
        help_text="Leave blank for whole-holding tasks (e.g. 'clean the coop').",
    )
    assignee = models.ForeignKey(
        Person,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="care_tasks",
        help_text="Who's responsible. Leave blank for anyone.",
    )
    recurrence_interval_days = models.PositiveIntegerField(
        default=7,
        help_text="How often this task repeats, in days.",
    )
    last_completed = models.DateField(
        null=True,
        blank=True,
        help_text="When the task was last done. Drives the next due date.",
    )
    due_date = models.DateField(
        null=True,
        blank=True,
        help_text="For one-off tasks: the date it's due. Leave blank for recurring tasks.",
    )
    auto_key = models.CharField(
        max_length=120,
        blank=True,
        default="",
        db_index=True,
        help_text="Stable key for auto-generated reminders; blank for tasks added by hand.",
    )
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name

    # -- Scheduling helpers --------------------------------------------------
    @property
    def is_one_off(self):
        """A one-off task has a fixed due date and does not recur."""
        return self.due_date is not None

    @property
    def anchor_date(self):
        """The date the next due date is counted from."""
        if self.last_completed:
            return self.last_completed
        if self.created_at:
            return timezone.localtime(self.created_at).date()
        return timezone.localdate()

    @property
    def next_due(self):
        if self.due_date:
            return self.due_date
        return self.anchor_date + timedelta(days=self.recurrence_interval_days)

    @property
    def days_overdue(self):
        """Positive when overdue by N days, negative when due in N days."""
        return (timezone.localdate() - self.next_due).days

    @property
    def status(self):
        delta = self.days_overdue
        if delta > 0:
            return "overdue"
        if delta == 0:
            return "due_today"
        return "upcoming"

    def mark_done(self, on=None, note=""):
        """Record completion: stamp last_completed and write a log entry.

        A recurring task reschedules off the new last_completed; a one-off task is
        closed out (deactivated) so it drops off the list once done.
        """
        self.last_completed = on or timezone.localdate()
        if self.is_one_off:
            self.active = False
            self.save(update_fields=["last_completed", "active", "updated_at"])
        else:
            self.save(update_fields=["last_completed", "updated_at"])
        return LogEntry.objects.create(
            care_task=self,
            animal=self.animal,
            entry_type=LogEntry.EntryType.TASK_COMPLETED,
            note=note or f"Completed: {self.name}",
            occurred_on=self.last_completed,
        )


class LogEntry(models.Model):
    """A dated note about the holding, optionally tied to an animal or task."""

    class EntryType(models.TextChoices):
        GENERAL = "general", "General"
        HEALTH = "health", "Health"
        FEEDING = "feeding", "Feeding"
        BREEDING = "breeding", "Breeding"
        TASK_COMPLETED = "task_completed", "Task completed"

    entry_type = models.CharField(max_length=20, choices=EntryType.choices, default=EntryType.GENERAL)
    note = models.TextField()
    animal = models.ForeignKey(
        Animal, null=True, blank=True, on_delete=models.SET_NULL, related_name="log_entries"
    )
    care_task = models.ForeignKey(
        CareTask, null=True, blank=True, on_delete=models.SET_NULL, related_name="log_entries"
    )
    created_by = models.ForeignKey(
        Person,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="log_entries",
        help_text="Who wrote the note. Blank for system entries (task completions, harvests).",
    )
    occurred_on = models.DateField(default=timezone.localdate)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-occurred_on", "-created_at"]

    def __str__(self):
        return f"[{self.occurred_on}] {self.get_entry_type_display()}: {self.note[:40]}"


class EggRecord(models.Model):
    """Eggs collected on a given day, optionally split by coop/flock source."""

    date = models.DateField(default=timezone.localdate)
    count = models.PositiveIntegerField(default=0)
    source = models.CharField(
        max_length=100, blank=True, help_text="Optional coop or flock name."
    )
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-date"]
        constraints = [
            models.UniqueConstraint(
                fields=["date", "source"], name="unique_egg_record_per_day_source"
            )
        ]

    def __str__(self):
        label = f" [{self.source}]" if self.source else ""
        return f"{self.date}: {self.count} eggs{label}"


class PushSubscription(models.Model):
    """A browser registered for web-push task reminders (see ``tracker/push.py``).

    ``last_sent_date`` is the dedup stamp: the reminder job sends at most one
    batch per subscription per day, however often the scheduler runs it.
    """

    user = models.ForeignKey(
        "auth.User", on_delete=models.CASCADE, related_name="push_subscriptions"
    )
    endpoint = models.URLField(max_length=500, unique=True)
    p256dh = models.CharField(max_length=255)
    auth = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)
    last_sent_date = models.DateField(null=True, blank=True)

    def __str__(self):
        return f"{self.user.username} @ {self.endpoint[:40]}…"


class WeatherSnapshot(models.Model):
    """The most recently fetched Open-Meteo forecast.

    A single row shared by all gunicorn workers, refreshed on demand when it
    goes stale — see ``tracker/weather.py``. Kept as a model (not a cache) so
    it survives restarts and the push-reminder job can reuse it.
    """

    fetched_at = models.DateTimeField(default=timezone.now)
    payload = models.JSONField()

    class Meta:
        ordering = ["-fetched_at"]
        get_latest_by = "fetched_at"

    def __str__(self):
        return f"Weather @ {self.fetched_at:%Y-%m-%d %H:%M}"


class Crop(models.Model):
    """A planting of a crop, used to drive the growth timeline. The crop type and
    its growth stages/timing come from the catalog in ``crops.py``."""

    crop = models.CharField(max_length=50, help_text="Catalog key, e.g. 'carrots'.")
    variety = models.CharField(max_length=120, blank=True)
    planted_on = models.DateField(default=timezone.localdate)
    quantity = models.PositiveIntegerField(null=True, blank=True, help_text="Number planted/sown.")
    bed = models.CharField(max_length=120, blank=True, help_text="Bed / row / location.")
    expected_harvest = models.DateField(
        null=True, blank=True, help_text="Override the estimated harvest date."
    )
    harvested_on = models.DateField(null=True, blank=True)
    yield_kg = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-planted_on"]

    def __str__(self):
        return self.crop_label + (f" — {self.variety}" if self.variety else "")

    @property
    def _entry(self):
        return CROP_CATALOG.get(self.crop)

    @property
    def crop_label(self):
        entry = self._entry
        return entry["label"] if entry else self.crop.replace("_", " ").title()

    @property
    def season_days(self):
        entry = self._entry
        return entry["days_to_harvest"] if entry else DEFAULT_DAYS_TO_HARVEST

    @property
    def estimated_harvest(self):
        if self.expected_harvest:
            return self.expected_harvest
        return self.planted_on + timedelta(days=self.season_days)

    @property
    def stages(self):
        """The growth-stage timeline, scaled to this crop's season length."""
        total = (self.estimated_harvest - self.planted_on).days or 1
        blueprint = self._entry["stages"] if self._entry else DEFAULT_STAGES
        return [
            {"label": label, "date": self.planted_on + timedelta(days=round(total * frac))}
            for label, frac in blueprint
        ]

    @property
    def current_stage(self):
        if self.harvested_on:
            return "Harvested"
        today = timezone.localdate()
        current = self.stages[0]["label"]
        for stage in self.stages:
            if stage["date"] <= today:
                current = stage["label"]
            else:
                break
        return current

    @property
    def progress(self):
        """0.0 at planting through 1.0 at (or after) estimated harvest."""
        if self.harvested_on:
            return 1.0
        total = (self.estimated_harvest - self.planted_on).days or 1
        elapsed = (timezone.localdate() - self.planted_on).days
        return max(0.0, min(1.0, elapsed / total))
