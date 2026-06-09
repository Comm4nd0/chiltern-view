from rest_framework import serializers

from .models import Animal, CareTask, Crop, EggRecord, LogEntry, Person


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
    assignee_name = serializers.CharField(source="assignee.name", read_only=True, default=None)
    # Computed scheduling fields the dashboard ranks on.
    next_due = serializers.DateField(read_only=True)
    days_overdue = serializers.IntegerField(read_only=True)
    status = serializers.CharField(read_only=True)

    class Meta:
        model = CareTask
        fields = [
            "id", "name", "description", "animal", "animal_name",
            "assignee", "assignee_name",
            "recurrence_interval_days", "last_completed", "active",
            "next_due", "days_overdue", "status",
            "created_at", "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]


class LogEntrySerializer(serializers.ModelSerializer):
    entry_type_display = serializers.CharField(source="get_entry_type_display", read_only=True)
    animal_name = serializers.CharField(source="animal.name", read_only=True, default=None)
    care_task_name = serializers.CharField(source="care_task.name", read_only=True, default=None)

    class Meta:
        model = LogEntry
        fields = [
            "id", "entry_type", "entry_type_display", "note",
            "animal", "animal_name", "care_task", "care_task_name",
            "occurred_on", "created_at",
        ]
        read_only_fields = ["created_at"]


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
    estimated_harvest = serializers.DateField(read_only=True)
    current_stage = serializers.CharField(read_only=True)
    progress = serializers.FloatField(read_only=True)
    stages = CropStageSerializer(many=True, read_only=True)

    class Meta:
        model = Crop
        fields = [
            "id", "crop", "crop_label", "variety",
            "planted_on", "quantity", "bed",
            "expected_harvest", "harvested_on", "yield_kg", "notes",
            "estimated_harvest", "current_stage", "progress", "stages",
            "created_at", "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]
