from datetime import timedelta

from django.db.models import F, Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .crops import catalog_list
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


@api_view(["GET"])
@permission_classes([AllowAny])
def overview(request):
    """At-a-glance summary of the whole holding for the home dashboard.

    One call returns task counts / top-overdue, animal counts, potato status, and
    egg totals, so each client renders the front page with a single request.
    """
    today = timezone.localdate()

    # --- Tasks (reuse CareTask's computed scheduling fields) ---
    tasks = list(CareTask.objects.select_related("assignee").filter(active=True))
    tasks.sort(key=lambda task: task.days_overdue, reverse=True)
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

    return Response(
        {
            "tasks": {
                "overdue": sum(1 for t in tasks if t.days_overdue > 0),
                "due_today": sum(1 for t in tasks if t.days_overdue == 0),
                "upcoming": sum(1 for t in tasks if t.days_overdue < 0),
                "per_person": per_person,
                "top": top,
            },
            "animals": {"total": animals.count(), "by_species": by_species},
            "crops": {"growing": len(growing), "next_harvest": next_harvest},
            "eggs": {"today": eggs_today, "this_week": eggs_week},
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
        """
        queryset = self.get_queryset().filter(active=True)
        assignee = request.query_params.get("assignee")
        if assignee == "unassigned":
            queryset = queryset.filter(assignee__isnull=True)
        elif assignee:
            queryset = queryset.filter(assignee_id=assignee)
        tasks = list(queryset)
        tasks.sort(key=lambda task: task.days_overdue, reverse=True)
        if request.query_params.get("include") == "due":
            tasks = [task for task in tasks if task.days_overdue >= 0]
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
    queryset = LogEntry.objects.select_related("animal", "care_task").all()
    serializer_class = LogEntrySerializer
    filterset_fields = ["entry_type", "animal", "care_task", "occurred_on"]
    search_fields = ["note"]
    ordering_fields = ["occurred_on", "created_at"]


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
