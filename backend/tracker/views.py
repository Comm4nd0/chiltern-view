from datetime import timedelta
from decimal import Decimal, InvalidOperation

from django.db.models import F, Q, Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .care_sync import close_crop_tasks, resync_crop_tasks
from .crops import catalog_list
from .watering import apply_rain_deferral, effective_days_overdue, effective_status
from .weather import frost_warning, get_weather
from .models import Animal, CareTask, Crop, EggRecord, LogEntry, Person
from .serializers import (
    AnimalSerializer,
    CareTaskSerializer,
    CropSerializer,
    EggRecordSerializer,
    LogEntrySerializer,
    PersonSerializer,
)


@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    """Lightweight liveness probe for Docker / load balancers."""
    return Response({"status": "ok", "time": timezone.now().isoformat()})


def person_for(user):
    """The Person linked to a logged-in user, or None (link is optional)."""
    try:
        return user.person
    except (Person.DoesNotExist, AttributeError):
        return None


@api_view(["GET"])
def overview(request):
    """At-a-glance summary of the whole holding for the home dashboard.

    One call returns task counts / top-overdue, animal counts, potato status, and
    egg totals, so each client renders the front page with a single request.
    """
    today = timezone.localdate()

    # --- Weather (also drives rain-deferral of watering tasks below) ---
    weather = get_weather()

    # --- Tasks (reuse CareTask's computed scheduling fields) ---
    tasks = list(CareTask.objects.select_related("assignee").filter(active=True))
    apply_rain_deferral(tasks, weather)
    tasks.sort(key=effective_days_overdue, reverse=True)
    per_person = {}
    for task in tasks:
        label = task.assignee.name if task.assignee else "Unassigned"
        per_person[label] = per_person.get(label, 0) + 1
    top = [
        {
            "id": task.id,
            "name": task.name,
            "assignee_name": task.assignee.name if task.assignee else None,
            "days_overdue": task.days_overdue,
            "status": task.status,
            "rain_deferred": bool(getattr(task, "rain_deferred", False)),
            "weather_note": getattr(task, "weather_note", None),
        }
        for task in tasks[:5]
    ]

    # --- Animals ---
    animals = Animal.objects.filter(active=True)
    by_species = {}
    for animal in animals:
        label = animal.get_species_display()
        by_species[label] = by_species.get(label, 0) + 1

    # --- Crops still in the ground ---
    growing = list(Crop.objects.filter(harvested_on__isnull=True))
    next_harvest = None
    if growing:
        soonest = min(growing, key=lambda crop: crop.estimated_harvest)
        next_harvest = {"label": soonest.crop_label, "date": soonest.estimated_harvest}

    # --- Eggs ---
    week_start = today - timedelta(days=today.weekday())
    eggs_today = EggRecord.objects.filter(date=today).aggregate(n=Sum("count"))["n"] or 0
    eggs_week = EggRecord.objects.filter(date__gte=week_start).aggregate(n=Sum("count"))["n"] or 0

    # --- Recent activity: the latest human notes from the holding journal.
    # Task completions are excluded — they're already visible as task state.
    recent_notes = (
        LogEntry.objects.select_related("animal", "created_by")
        .exclude(entry_type=LogEntry.EntryType.TASK_COMPLETED)[:5]
    )
    activity = [
        {
            "id": entry.id,
            "entry_type": entry.entry_type,
            "entry_type_display": entry.get_entry_type_display(),
            "note": entry.note,
            "animal": entry.animal_id,
            "animal_name": entry.animal.name if entry.animal else None,
            "occurred_on": entry.occurred_on,
            "created_by_name": entry.created_by.name if entry.created_by else None,
        }
        for entry in recent_notes
    ]

    return Response(
        {
            "tasks": {
                # A rain-deferred watering job counts as upcoming, not due.
                "overdue": sum(1 for t in tasks if effective_status(t) == "overdue"),
                "due_today": sum(1 for t in tasks if effective_status(t) == "due_today"),
                "upcoming": sum(1 for t in tasks if effective_status(t) == "upcoming"),
                "per_person": per_person,
                "top": top,
            },
            "animals": {"total": animals.count(), "by_species": by_species},
            "crops": {"growing": len(growing), "next_harvest": next_harvest},
            "eggs": {"today": eggs_today, "this_week": eggs_week},
            "activity": activity,
            "weather": {**weather, "frost_warning": frost_warning(weather)} if weather else None,
        }
    )


class PersonViewSet(viewsets.ModelViewSet):
    queryset = Person.objects.all()
    serializer_class = PersonSerializer
    search_fields = ["name"]
    ordering_fields = ["name"]


class AnimalViewSet(viewsets.ModelViewSet):
    queryset = Animal.objects.all()
    serializer_class = AnimalSerializer
    filterset_fields = ["species", "active"]
    search_fields = ["name", "breed", "notes"]
    ordering_fields = ["name", "created_at", "date_of_birth"]


class CareTaskViewSet(viewsets.ModelViewSet):
    queryset = CareTask.objects.select_related("animal", "assignee").all()
    serializer_class = CareTaskSerializer
    filterset_fields = ["active", "animal", "assignee"]
    search_fields = ["name", "description"]
    ordering_fields = ["name", "recurrence_interval_days", "last_completed", "created_at"]

    @action(detail=False)
    def dashboard(self, request):
        """Active tasks ranked by overdue-ness (most overdue first).

        Query params:
          include=all (default) | due   -> 'due' drops tasks not yet due.
          assignee=<id> | unassigned    -> filter by who's responsible.
          animal=<id>                   -> that animal's tasks, including its
                                           species' shared routine (flock jobs).
        """
        queryset = self.get_queryset().filter(active=True)
        assignee = request.query_params.get("assignee")
        if assignee == "unassigned":
            queryset = queryset.filter(assignee__isnull=True)
        elif assignee:
            queryset = queryset.filter(assignee_id=assignee)
        animal_id = request.query_params.get("animal")
        if animal_id:
            animal = Animal.objects.filter(pk=animal_id).first() if animal_id.isdigit() else None
            if animal is None:
                queryset = queryset.none()
            else:
                # Species-routine auto keys are exactly "animal:<species>:<job>";
                # per-animal keys carry the pk too, so they only match their own FK.
                queryset = queryset.filter(
                    Q(animal_id=animal.pk)
                    | Q(auto_key__regex=rf"^animal:{animal.species}:[^:]+$")
                )
        tasks = list(queryset)
        # Rain takes care of due watering jobs: flag and rank them as upcoming.
        apply_rain_deferral(tasks, get_weather())
        tasks.sort(key=effective_days_overdue, reverse=True)
        if request.query_params.get("include") == "due":
            tasks = [task for task in tasks if effective_days_overdue(task) >= 0]
        serializer = self.get_serializer(tasks, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=["post"])
    def complete(self, request, pk=None):
        """Mark a task done. Optional body: {"date": "YYYY-MM-DD", "note": "..."}."""
        task = self.get_object()
        completed_on = parse_date(request.data.get("date", "") or "")
        log = task.mark_done(on=completed_on, note=request.data.get("note", ""))
        data = self.get_serializer(task).data
        data["log_entry_id"] = log.id
        return Response(data)


class LogEntryViewSet(viewsets.ModelViewSet):
    queryset = LogEntry.objects.select_related("animal", "care_task", "created_by").all()
    serializer_class = LogEntrySerializer
    filterset_fields = ["entry_type", "animal", "care_task", "occurred_on"]
    search_fields = ["note"]
    ordering_fields = ["occurred_on", "created_at"]

    def get_queryset(self):
        """Support ?types=health,feeding — a CSV multi-type filter the single
        entry_type param can't express (used to hide routine task completions)."""
        queryset = super().get_queryset()
        types = self.request.query_params.get("types")
        if types:
            wanted = [t.strip() for t in types.split(",") if t.strip()]
            queryset = queryset.filter(entry_type__in=wanted)
        return queryset

    def perform_create(self, serializer):
        serializer.save(created_by=person_for(self.request.user))


class EggRecordViewSet(viewsets.ModelViewSet):
    queryset = EggRecord.objects.all()
    serializer_class = EggRecordSerializer
    filterset_fields = ["date", "source"]
    ordering_fields = ["date", "count", "created_at"]

    @action(detail=False, methods=["post"])
    def increment(self, request):
        """Quick counter: add to today's tally (or a given date/source).

        Optional body: {"count": 1, "date": "YYYY-MM-DD", "source": "..."}.
        Uses an atomic F() update so rapid taps don't lose a count.
        """
        try:
            amount = int(request.data.get("count", 1))
        except (TypeError, ValueError):
            return Response({"detail": "count must be an integer."}, status=status.HTTP_400_BAD_REQUEST)
        on = parse_date(request.data.get("date", "") or "") or timezone.localdate()
        source = request.data.get("source", "") or ""
        record, _ = EggRecord.objects.get_or_create(date=on, source=source, defaults={"count": 0})
        EggRecord.objects.filter(pk=record.pk).update(count=F("count") + amount)
        record.refresh_from_db()
        return Response(self.get_serializer(record).data)

    @action(detail=False)
    def summary(self, request):
        """Totals for today, this week, this month and all time."""
        today = timezone.localdate()
        week_start = today - timedelta(days=today.weekday())
        month_start = today.replace(day=1)

        def total_since(start):
            return EggRecord.objects.filter(date__gte=start).aggregate(n=Sum("count"))["n"] or 0

        return Response(
            {
                "today": EggRecord.objects.filter(date=today).aggregate(n=Sum("count"))["n"] or 0,
                "this_week": total_since(week_start),
                "this_month": total_since(month_start),
                "total": EggRecord.objects.aggregate(n=Sum("count"))["n"] or 0,
            }
        )


class CropViewSet(viewsets.ModelViewSet):
    queryset = Crop.objects.all()
    serializer_class = CropSerializer
    filterset_fields = ["crop"]
    search_fields = ["crop", "variety", "bed", "notes"]
    ordering_fields = ["planted_on", "crop", "created_at"]

    @action(detail=False)
    def catalog(self, request):
        """The code-defined crop catalog (types + growth stages) for dropdowns."""
        return Response(catalog_list())

    @action(detail=False)
    def timeline(self, request):
        """Crops ordered oldest-first for the growth timeline.

        Query params: show=growing (default) | all  -> 'growing' hides harvested.
        """
        crops = self.get_queryset().order_by("planted_on")
        if request.query_params.get("show", "growing") == "growing":
            crops = crops.filter(harvested_on__isnull=True)
        serializer = self.get_serializer(crops, many=True)
        return Response(serializer.data)

    @action(detail=False)
    def board(self, request):
        """Growing crops with their stage, progress and harvest date, wrapped in a
        JSON object for Home Assistant.

        HA's RESTful sensor can expose a JSON object's keys as attributes but not a
        bare list, so the crop cards (mirroring the web/mobile dashboard) are nested
        under ``crops`` with a ``count`` alongside. Read-only; safe to poll.
        """
        crops = list(
            self.get_queryset().filter(harvested_on__isnull=True).order_by("planted_on")
        )
        cards = [
            {
                "id": crop.id,
                "label": crop.crop_label,
                "variety": crop.variety,
                "bed": crop.bed,
                "stage": crop.current_stage,
                "progress": round(crop.progress * 100),
                "estimated_harvest": crop.estimated_harvest,
            }
            for crop in crops
        ]
        return Response({"count": len(cards), "crops": cards})

    @action(detail=True, methods=["post"])
    def harvest(self, request, pk=None):
        """Mark a crop harvested and retire its auto reminders.

        Optional body: {"date": "YYYY-MM-DD", "yield_kg": 12.5, "note": "..."}.
        This is the canonical way to finish a crop — completing the auto
        "Harvest ..." to-do ticks the task off but does not set harvested_on.
        """
        crop = self.get_object()
        crop.harvested_on = parse_date(request.data.get("date", "") or "") or timezone.localdate()
        raw_yield = request.data.get("yield_kg")
        if raw_yield not in (None, ""):
            try:
                crop.yield_kg = Decimal(str(raw_yield))
            except InvalidOperation:
                return Response(
                    {"detail": "yield_kg must be a number."}, status=status.HTTP_400_BAD_REQUEST
                )
        note = (request.data.get("note") or "").strip()
        if note:
            crop.notes = f"{crop.notes}\n{note}".strip()
        crop.save()
        close_crop_tasks(crop)
        summary = f"Harvested {crop.crop_label}"
        if crop.bed:
            summary += f" ({crop.bed})"
        if crop.yield_kg is not None:
            summary += f" — {crop.yield_kg} kg"
        if note:
            summary += f". {note}"
        LogEntry.objects.create(
            entry_type=LogEntry.EntryType.GENERAL,
            note=summary,
            occurred_on=crop.harvested_on,
        )
        return Response(self.get_serializer(crop).data)

    def perform_update(self, serializer):
        """Keep the auto reminders in step when a crop is edited — dates moved,
        a harvest recorded via PATCH, or a harvest undone."""
        crop = serializer.save()
        resync_crop_tasks(crop)
