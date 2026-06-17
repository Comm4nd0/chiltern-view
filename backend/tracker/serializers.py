from rest_framework import serializers

from .models import Animal, CareTask, Crop, EggRecord, LogEntry, Person, Supply, WeightRecord


class PersonSerializer(serializers.ModelSerializer):
    class Meta:
        model = Person
        fields = ["id", "name"]


class AnimalSerializer(serializers.ModelSerializer):
    species_display = serializers.CharField(source="get_species_display", read_only=True)

    class Meta:
        model = Animal
        fields = [
            "id", "name", "species", "species_display", "breed",
            "date_of_birth", "acquired_on", "notes", "active",
            "created_at", "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]


class CareTaskSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source="animal.name", read_only=True, default=None)
    species_display = serializers.CharField(source="get_species_display", read_only=True, default="")
    assignee_name = serializers.CharField(source="assignee.name", read_only=True, default=None)
    # Computed scheduling fields the dashboard ranks on.
    next_due = serializers.DateField(read_only=True)
    days_overdue = serializers.IntegerField(read_only=True)
    status = serializers.CharField(read_only=True)
    times_done_today = serializers.IntegerField(read_only=True)
    # Request-scoped weather flags set by tracker/watering.py (absent → defaults).
    rain_deferred = serializers.SerializerMethodField()
    weather_note = serializers.SerializerMethodField()

    class Meta:
        model = CareTask
        fields = [
            "id", "name", "description", "animal", "animal_name",
            "species", "species_display",
            "assignee", "assignee_name",
            "recurrence_interval_days", "times_per_day", "times_done_today",
            "last_completed", "due_date", "due_time", "snoozed_until", "auto_key", "active",
            "next_due", "days_overdue", "status",
            "rain_deferred", "weather_note",
            "created_at", "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at", "auto_key"]

    def validate(self, attrs):
        """A task done once at a fixed point can't also repeat during its day, so a
        due_date (one-off) or a due_time (clock-timed, e.g. the 07:30 feed) forces
        times_per_day back to 1."""
        due_date = attrs.get(
            "due_date", self.instance.due_date if self.instance else None
        )
        due_time = attrs.get(
            "due_time", self.instance.due_time if self.instance else None
        )
        if due_date is not None or due_time is not None:
            attrs["times_per_day"] = 1
        return attrs

    def get_rain_deferred(self, obj):
        return bool(getattr(obj, "rain_deferred", False))

    def get_weather_note(self, obj):
        return getattr(obj, "weather_note", None)


class LogEntrySerializer(serializers.ModelSerializer):
    entry_type_display = serializers.CharField(source="get_entry_type_display", read_only=True)
    animal_name = serializers.CharField(source="animal.name", read_only=True, default=None)
    care_task_name = serializers.CharField(source="care_task.name", read_only=True, default=None)
    created_by_name = serializers.CharField(source="created_by.name", read_only=True, default=None)
    withdrawal_until = serializers.DateField(read_only=True)
    withdrawal_active = serializers.BooleanField(read_only=True)

    class Meta:
        model = LogEntry
        fields = [
            "id", "entry_type", "entry_type_display", "note",
            "medicine", "withdrawal_days", "withdrawal_until", "withdrawal_active",
            "animal", "animal_name", "care_task", "care_task_name",
            "created_by", "created_by_name",
            "occurred_on", "created_at",
        ]
        # created_by is stamped from the logged-in user, not client-supplied.
        read_only_fields = ["created_at", "created_by"]


class WeightRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = WeightRecord
        fields = ["id", "animal", "date", "weight_kg", "note", "created_at"]
        read_only_fields = ["created_at"]


class SupplySerializer(serializers.ModelSerializer):
    is_low = serializers.BooleanField(read_only=True)

    class Meta:
        model = Supply
        fields = [
            "id", "name", "unit", "quantity", "reorder_at", "is_low",
            "notes", "active", "created_at", "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]


class EggRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = EggRecord
        fields = ["id", "date", "count", "source", "notes", "created_at", "updated_at"]
        read_only_fields = ["created_at", "updated_at"]


class CropStageSerializer(serializers.Serializer):
    label = serializers.CharField()
    date = serializers.DateField()


class CropSerializer(serializers.ModelSerializer):
    crop_label = serializers.CharField(read_only=True)
    family = serializers.CharField(read_only=True, default=None)
    family_label = serializers.CharField(read_only=True, default=None)
    estimated_harvest = serializers.DateField(read_only=True)
    current_stage = serializers.CharField(read_only=True)
    progress = serializers.FloatField(read_only=True)
    stages = CropStageSerializer(many=True, read_only=True)

    class Meta:
        model = Crop
        fields = [
            "id", "crop", "crop_label", "family", "family_label", "variety",
            "planted_on", "quantity", "bed",
            "expected_harvest", "harvested_on", "yield_kg", "notes",
            "estimated_harvest", "current_stage", "progress", "stages",
            "created_at", "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]
