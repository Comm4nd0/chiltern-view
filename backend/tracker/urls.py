from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views
from .auth import LoginView, logout, me

router = DefaultRouter()
router.register("people", views.PersonViewSet)
router.register("animals", views.AnimalViewSet)
router.register("care-tasks", views.CareTaskViewSet)
router.register("log-entries", views.LogEntryViewSet)
router.register("egg-records", views.EggRecordViewSet)
router.register("crops", views.CropViewSet)

urlpatterns = [
    path("health/", views.health, name="health"),
    path("overview/", views.overview, name="overview"),
    path("auth/login/", LoginView.as_view(), name="auth-login"),
    path("auth/logout/", logout, name="auth-logout"),
    path("auth/me/", me, name="auth-me"),
    path("", include(router.urls)),
]
