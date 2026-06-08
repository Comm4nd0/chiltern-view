from django.contrib import admin

from .models import Animal, CareTask, EggRecord, LogEntry, Person, PotatoPlanting


@admin.register(Person)
class PersonAdmin(admin.ModelAdmin):
    list_display = ["name"]
    search_fields = ["name"]


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


@admin.register(EggRecord)
class EggRecordAdmin(admin.ModelAdmin):
    list_display = ["date", "count", "source"]
    list_filter = ["source"]
    date_hierarchy = "date"


@admin.register(PotatoPlanting)
class PotatoPlantingAdmin(admin.ModelAdmin):
    list_display = ["variety", "category", "planted_on", "estimated_harvest", "current_stage", "harvested_on"]
    list_filter = ["category", "harvested_on"]
    search_fields = ["variety", "bed", "notes"]

    @admin.display(description="Est. harvest")
    def estimated_harvest(self, obj):
        return obj.estimated_harvest

    @admin.display(description="Stage")
    def current_stage(self, obj):
        return obj.current_stage
