from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register("people", views.PersonViewSet)
router.register("animals", views.AnimalViewSet)
router.register("care-tasks", views.CareTaskViewSet)
router.register("log-entries", views.LogEntryViewSet)
router.register("egg-records", views.EggRecordViewSet)
router.register("potato-plantings", views.PotatoPlantingViewSet)

urlpatterns = [
    path("health/", views.health, name="health"),
    path("overview/", views.overview, name="overview"),
    path("", include(router.urls)),
]
