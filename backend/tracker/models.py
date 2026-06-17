"""Domain models for the Chiltern View smallholding tracker."""
from datetime import timedelta
from decimal import Decimal

from django.core.validators import MinValueValidator
from django.db import models
from django.utils import timezone

from .crops import (
    CROP_CATALOG,
    DEFAULT_DAYS_TO_HARVEST,
    DEFAULT_STAGES,
    crop_family,
    crop_family_label,
)


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
    photo = models.ImageField(upload_to="animals/", null=True, blank=True)
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
    species = models.CharField(
        max_length=20,
        blank=True,
        default="",
        db_index=True,
        choices=Animal.Species.choices,
        help_text="Assign to a whole animal type (e.g. all chickens — collecting "
        "the eggs) rather than one individual. Leave blank for a single-animal "
        "(see `animal`) or whole-holding job.",
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
    times_per_day = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)],
        help_text="How many times the task needs doing on its due day, "
        "e.g. 4 for a dog fed four times a day.",
    )
    times_done = models.PositiveIntegerField(
        default=0,
        help_text="Completions recorded on last_completed — progress through "
        "a several-times-a-day task.",
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
    due_time = models.TimeField(
        null=True,
        blank=True,
        help_text="Optional clock time the task is due / its reminder fires, "
        "e.g. 07:30 to feed the dog. Blank = anytime that day (e.g. collect the eggs).",
    )
    snoozed_until = models.DateField(
        null=True,
        blank=True,
        help_text="'Remind me later': hold the task back until this date. "
        "Cleared automatically when the task is completed.",
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
    def times_done_today(self):
        """Completions so far today — 0 unless the task was last done today."""
        if self.last_completed == timezone.localdate():
            return self.times_done
        return 0

    def _base_next_due(self):
        if self.due_date:
            return self.due_date
        # A several-times-a-day task stays due until today's repeats are all done.
        today = timezone.localdate()
        if self.times_per_day > 1 and self.last_completed == today and self.times_done < self.times_per_day:
            return today
        return self.anchor_date + timedelta(days=self.recurrence_interval_days)

    @property
    def next_due(self):
        base = self._base_next_due()
        # A snooze only ever pushes a task later, never pulls it earlier.
        if self.snoozed_until and self.snoozed_until > base:
            return self.snoozed_until
        return base

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

    def mark_done(self, on=None, note="", by=None):
        """Record completion: stamp last_completed and write a log entry.

        A recurring task reschedules off the new last_completed; a one-off task is
        closed out (deactivated) so it drops off the list once done. A several-
        times-a-day task counts completions and stays due until the day's quota
        is met. ``by`` is the Person who did it — recorded on the log entry so the
        activity feed can show who completed each task.
        """
        on = on or timezone.localdate()
        if not self.is_one_off and self.times_per_day > 1 and self.last_completed == on:
            self.times_done += 1
        else:
            self.times_done = 1
        self.last_completed = on
        # Completing a task clears any "remind me later" hold.
        self.snoozed_until = None
        if self.is_one_off:
            self.active = False
            self.save(
                update_fields=["last_completed", "times_done", "active", "snoozed_until", "updated_at"]
            )
        else:
            self.save(
                update_fields=["last_completed", "times_done", "snoozed_until", "updated_at"]
            )
        default_note = f"Completed: {self.name}"
        if self.times_per_day > 1:
            default_note += f" ({self.times_done} of {self.times_per_day} today)"
        return LogEntry.objects.create(
            care_task=self,
            animal=self.animal,
            entry_type=LogEntry.EntryType.TASK_COMPLETED,
            note=note or default_note,
            occurred_on=self.last_completed,
            created_by=by,
        )

    def uncomplete(self):
        """Undo the most recent completion, restoring the prior schedule.

        Reverses one ``mark_done`` using the TASK_COMPLETED log entries it writes,
        so the previous ``last_completed`` is restored from history rather than
        guessed: drop the latest completion, then re-read state from whatever
        completion is now newest. Steps back one repeat of a several-times-a-day
        task, and revives a one-off that completing had deactivated. Returns True
        if anything was undone, False if there was nothing to undo.
        """
        completions = self.log_entries.filter(
            entry_type=LogEntry.EntryType.TASK_COMPLETED
        ).order_by("-occurred_on", "-created_at")
        latest = completions.first()
        if latest is None:
            return False
        latest.delete()
        remaining = self.log_entries.filter(
            entry_type=LogEntry.EntryType.TASK_COMPLETED
        ).order_by("-occurred_on", "-created_at")
        newest = remaining.first()
        if newest is not None:
            self.last_completed = newest.occurred_on
            self.times_done = remaining.filter(occurred_on=newest.occurred_on).count()
        else:
            self.last_completed = None
            self.times_done = 0
        if self.is_one_off:
            self.active = True
        self.save(update_fields=["last_completed", "times_done", "active", "updated_at"])
        return True


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
    # Medication tracking (health entries): the product given and its food-safety
    # withdrawal period. While within the period, produce from the treated animal
    # mustn't be eaten — the dashboards surface a "do not eat until …" banner.
    medicine = models.CharField(
        max_length=120, blank=True, default="", help_text="Medicine/treatment given, if any."
    )
    withdrawal_days = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Days after treatment that eggs/meat must not be eaten.",
    )
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

    @property
    def withdrawal_until(self):
        """Last day produce from the treated animal must not be eaten, or None."""
        if self.withdrawal_days:
            return self.occurred_on + timedelta(days=self.withdrawal_days)
        return None

    @property
    def withdrawal_active(self):
        """True while the withdrawal period is still in force (today included)."""
        until = self.withdrawal_until
        return until is not None and until >= timezone.localdate()


class WeightRecord(models.Model):
    """A dated weight reading for an animal — drives the growth/weight trend."""

    animal = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name="weight_records"
    )
    date = models.DateField(default=timezone.localdate)
    weight_kg = models.DecimalField(
        max_digits=7, decimal_places=2, validators=[MinValueValidator(Decimal("0"))]
    )
    note = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date", "-created_at"]

    def __str__(self):
        return f"{self.animal_id}: {self.weight_kg} kg on {self.date}"


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


class PushReminderLog(models.Model):
    """Dedup stamp for *timed* web-push pings — one per subscription/task/day.

    The digest dedups via ``PushSubscription.last_sent_date`` (one batch a day),
    but a task pinned to a clock time fires on its own schedule, so it needs its
    own per-task stamp to keep the scheduler loop from re-sending it each run.
    """

    subscription = models.ForeignKey(
        PushSubscription, on_delete=models.CASCADE, related_name="timed_reminders"
    )
    care_task = models.ForeignKey(
        CareTask, on_delete=models.CASCADE, related_name="timed_reminders"
    )
    sent_date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["subscription", "care_task", "sent_date"],
                name="unique_timed_reminder_per_day",
            )
        ]

    def __str__(self):
        return f"{self.care_task_id} → {self.subscription_id} on {self.sent_date}"


class Supply(models.Model):
    """A consumable kept on the holding (feed, hay, bedding, wormer, …) with a
    reorder threshold, so the dashboard can flag what's running low."""

    name = models.CharField(max_length=120)
    unit = models.CharField(
        max_length=30, blank=True, help_text="Unit it's counted in, e.g. kg, bags, bales."
    )
    quantity = models.DecimalField(
        max_digits=9, decimal_places=2, default=Decimal("0"),
        validators=[MinValueValidator(Decimal("0"))],
    )
    reorder_at = models.DecimalField(
        max_digits=9, decimal_places=2, default=Decimal("0"),
        validators=[MinValueValidator(Decimal("0"))],
        help_text="Flag as low when quantity drops to or below this.",
    )
    notes = models.TextField(blank=True)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        verbose_name_plural = "supplies"

    def __str__(self):
        return f"{self.name}: {self.quantity} {self.unit}".strip()

    @property
    def is_low(self):
        """True when stock has dropped to or below the reorder threshold."""
        return self.quantity <= self.reorder_at


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
    photo = models.ImageField(upload_to="crops/", null=True, blank=True)
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
    def family(self):
        """Botanical family code (drives crop-rotation warnings), or None."""
        return crop_family(self.crop)

    @property
    def family_label(self):
        """Human botanical family label, or None for an unknown crop."""
        return crop_family_label(self.crop)

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
