"""Domain models for the Chiltern View smallholding tracker."""
from datetime import timedelta

from django.db import models
from django.utils import timezone


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

    Deliberately lightweight (just a name): this is a trusted-LAN app with no
    login. A Person can later gain a OneToOne link to ``auth.User`` if real
    accounts are introduced, without changing how tasks reference it.
    """

    name = models.CharField(max_length=100, unique=True)
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
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name

    # -- Scheduling helpers --------------------------------------------------
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
        """Record completion: stamp last_completed and write a log entry."""
        self.last_completed = on or timezone.localdate()
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


class PotatoPlanting(models.Model):
    """A planting of seed potatoes, used to drive the growth timeline."""

    class Category(models.TextChoices):
        FIRST_EARLY = "first_early", "First early"
        SECOND_EARLY = "second_early", "Second early"
        MAINCROP = "maincrop", "Maincrop"
        SALAD = "salad", "Salad"

    # Approximate days from planting to harvest, by category (UK growing guide).
    DAYS_TO_HARVEST = {
        "first_early": 75,
        "second_early": 95,
        "maincrop": 125,
        "salad": 110,
    }

    # Fraction of the season at which each growth stage typically begins.
    STAGE_BLUEPRINT = [
        ("Planted", 0.0),
        ("Sprouting", 0.18),
        ("Earthing up", 0.35),
        ("Flowering", 0.55),
        ("Tuber bulking", 0.70),
        ("Ready to harvest", 1.0),
    ]

    variety = models.CharField(max_length=120)
    category = models.CharField(max_length=20, choices=Category.choices, default=Category.MAINCROP)
    planted_on = models.DateField(default=timezone.localdate)
    quantity = models.PositiveIntegerField(null=True, blank=True, help_text="Number of seed potatoes.")
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
        return f"{self.variety} ({self.get_category_display()})"

    @property
    def season_days(self):
        return self.DAYS_TO_HARVEST.get(self.category, 110)

    @property
    def estimated_harvest(self):
        if self.expected_harvest:
            return self.expected_harvest
        return self.planted_on + timedelta(days=self.season_days)

    @property
    def stages(self):
        """The growth-stage timeline, scaled to this variety's season length."""
        total = (self.estimated_harvest - self.planted_on).days or 1
        return [
            {"label": label, "date": self.planted_on + timedelta(days=round(total * frac))}
            for label, frac in self.STAGE_BLUEPRINT
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
