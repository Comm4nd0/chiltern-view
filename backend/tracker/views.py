from datetime import timedelta

from django.db.models import F, Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import Animal, CareTask, EggRecord, LogEntry, Person, PotatoPlanting
from .serializers import (
    AnimalSerializer,
    CareTaskSerializer,
    EggRecordSerializer,
    LogEntrySerializer,
    PersonSerializer,
    PotatoPlantingSerializer,
)


@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    """Lightweight liveness probe for Docker / load balancers."""
    return Response({"status": "ok", "time": timezone.now().isoformat()})


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


class PotatoPlantingViewSet(viewsets.ModelViewSet):
    queryset = PotatoPlanting.objects.all()
    serializer_class = PotatoPlantingSerializer
    filterset_fields = ["category", "variety"]
    search_fields = ["variety", "bed", "notes"]
    ordering_fields = ["planted_on", "variety", "created_at"]

    @action(detail=False)
    def timeline(self, request):
        """Plantings ordered oldest-first for the growth timeline.

        Query params: show=growing (default) | all  -> 'growing' hides harvested.
        """
        plantings = self.get_queryset().order_by("planted_on")
        if request.query_params.get("show", "growing") == "growing":
            plantings = plantings.filter(harvested_on__isnull=True)
        serializer = self.get_serializer(plantings, many=True)
        return Response(serializer.data)
