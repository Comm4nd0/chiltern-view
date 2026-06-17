from django.contrib import admin

from .models import Animal, CareTask, Crop, EggRecord, LogEntry, Person, WeightRecord


@admin.register(Person)
class PersonAdmin(admin.ModelAdmin):
    list_display = ["name", "user"]
    list_select_related = ["user"]
    search_fields = ["name", "user__username"]


@admin.register(Animal)
class AnimalAdmin(admin.ModelAdmin):
    list_display = ["name", "species", "breed", "active", "acquired_on"]
    list_filter = ["species", "active"]
    search_fields = ["name", "breed", "notes"]


@admin.register(CareTask)
class CareTaskAdmin(admin.ModelAdmin):
    list_display = ["name", "assignee", "animal", "recurrence_interval_days", "last_completed", "next_due", "active"]
    list_filter = ["active", "assignee", "animal"]
    search_fields = ["name", "description"]

    @admin.display(description="Next due")
    def next_due(self, obj):
        return obj.next_due


@admin.register(LogEntry)
class LogEntryAdmin(admin.ModelAdmin):
    list_display = ["occurred_on", "entry_type", "animal", "care_task", "note"]
    list_filter = ["entry_type", "occurred_on"]
    search_fields = ["note"]
    date_hierarchy = "occurred_on"


@admin.register(WeightRecord)
class WeightRecordAdmin(admin.ModelAdmin):
    list_display = ["animal", "date", "weight_kg", "note"]
    list_filter = ["animal"]
    date_hierarchy = "date"


@admin.register(EggRecord)
class EggRecordAdmin(admin.ModelAdmin):
    list_display = ["date", "count", "source"]
    list_filter = ["source"]
    date_hierarchy = "date"


@admin.register(Crop)
class CropAdmin(admin.ModelAdmin):
    list_display = ["crop", "variety", "planted_on", "estimated_harvest", "current_stage", "harvested_on"]
    list_filter = ["crop", "harvested_on"]
    search_fields = ["crop", "variety", "bed", "notes"]

    @admin.display(description="Est. harvest")
    def estimated_harvest(self, obj):
        return obj.estimated_harvest

    @admin.display(description="Stage")
    def current_stage(self, obj):
        return obj.current_stage
