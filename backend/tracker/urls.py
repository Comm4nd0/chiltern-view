from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views
from .auth import LoginView, logout, me
from .push import subscribe, unsubscribe, vapid_public_key

router = DefaultRouter()
router.register("people", views.PersonViewSet)
router.register("animals", views.AnimalViewSet)
router.register("care-tasks", views.CareTaskViewSet)
router.register("log-entries", views.LogEntryViewSet)
router.register("weight-records", views.WeightRecordViewSet)
router.register("supplies", views.SupplyViewSet)
router.register("egg-records", views.EggRecordViewSet)
router.register("crops", views.CropViewSet)

urlpatterns = [
    path("health/", views.health, name="health"),
    path("overview/", views.overview, name="overview"),
    path("auth/login/", LoginView.as_view(), name="auth-login"),
    path("auth/logout/", logout, name="auth-logout"),
    path("auth/me/", me, name="auth-me"),
    path("push/vapid-public-key/", vapid_public_key, name="push-vapid-key"),
    path("push/subscribe/", subscribe, name="push-subscribe"),
    path("push/unsubscribe/", unsubscribe, name="push-unsubscribe"),
    path("", include(router.urls)),
]
