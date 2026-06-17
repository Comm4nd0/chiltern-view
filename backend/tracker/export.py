"""CSV export of the holding's data — a simple self-hosted backup.

One authenticated endpoint per dataset, ``GET /api/export/<dataset>/``, streaming
a downloadable CSV. Read-only; requires a token like every other endpoint.
"""
import csv

from django.http import Http404, HttpResponse
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import Animal, Crop, EggRecord, LogEntry, Supply, WeightRecord


def _rows_animals():
    yield ["id", "name", "species", "breed", "date_of_birth", "acquired_on", "active", "notes"]
    for a in Animal.objects.all():
        yield [a.id, a.name, a.species, a.breed, a.date_of_birth, a.acquired_on, a.active, a.notes]


def _rows_crops():
    yield ["id", "crop", "variety", "planted_on", "bed", "quantity",
           "expected_harvest", "harvested_on", "yield_kg", "notes"]
    for c in Crop.objects.all():
        yield [c.id, c.crop, c.variety, c.planted_on, c.bed, c.quantity,
               c.expected_harvest, c.harvested_on, c.yield_kg, c.notes]


def _rows_eggs():
    yield ["id", "date", "count", "source", "notes"]
    for e in EggRecord.objects.all():
        yield [e.id, e.date, e.count, e.source, e.notes]


def _rows_weights():
    yield ["id", "animal", "date", "weight_kg", "note"]
    for w in WeightRecord.objects.select_related("animal"):
        yield [w.id, w.animal.name if w.animal else "", w.date, w.weight_kg, w.note]


def _rows_supplies():
    yield ["id", "name", "unit", "quantity", "reorder_at", "active", "notes"]
    for s in Supply.objects.all():
        yield [s.id, s.name, s.unit, s.quantity, s.reorder_at, s.active, s.notes]


def _rows_journal():
    yield ["id", "occurred_on", "entry_type", "animal", "note",
           "medicine", "withdrawal_days", "created_by"]
    for e in LogEntry.objects.select_related("animal", "created_by"):
        yield [e.id, e.occurred_on, e.entry_type, e.animal.name if e.animal else "",
               e.note, e.medicine, e.withdrawal_days, e.created_by.name if e.created_by else ""]


DATASETS = {
    "animals": _rows_animals,
    "crops": _rows_crops,
    "eggs": _rows_eggs,
    "weights": _rows_weights,
    "supplies": _rows_supplies,
    "journal": _rows_journal,
}


@api_view(["GET"])
def export_csv(request, dataset):
    """Download one dataset as CSV. ``dataset`` is one of DATASETS' keys."""
    builder = DATASETS.get(dataset)
    if builder is None:
        raise Http404("Unknown dataset")
    response = HttpResponse(content_type="text/csv")
    response["Content-Disposition"] = f'attachment; filename="chiltern_{dataset}.csv"'
    writer = csv.writer(response)
    for row in builder():
        writer.writerow(row)
    return response


@api_view(["GET"])
def export_index(request):
    """List the datasets a client can export, for the export UI."""
    return Response({"datasets": sorted(DATASETS)})
