"""Web-push subscription endpoints.

The phone app schedules its reminders on-device; this is the web equivalent.
The browser registers its push subscription here, and the scheduled
``send_push_reminders`` management command delivers a morning digest plus
due-today pings through the browser's push service.
"""
from django.conf import settings
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import PushSubscription


@api_view(["GET"])
def vapid_public_key(request):
    """The public half of the VAPID keypair, needed to subscribe a browser."""
    if not settings.VAPID_PUBLIC_KEY:
        return Response(
            {"detail": "Web push is not configured on this server."},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    return Response({"key": settings.VAPID_PUBLIC_KEY})


@api_view(["POST"])
def subscribe(request):
    """Register this browser for the logged-in user's reminders.

    Body = the browser's ``PushSubscription.toJSON()``:
    ``{"endpoint": ..., "keys": {"p256dh": ..., "auth": ...}}``. Upserts by
    endpoint and re-assigns the user — when Marco and Claire share a browser,
    reminders follow whoever signed in last.
    """
    endpoint = request.data.get("endpoint")
    keys = request.data.get("keys") or {}
    if not endpoint or not keys.get("p256dh") or not keys.get("auth"):
        return Response(
            {"detail": "Not a valid push subscription."}, status=status.HTTP_400_BAD_REQUEST
        )
    PushSubscription.objects.update_or_create(
        endpoint=endpoint,
        defaults={"user": request.user, "p256dh": keys["p256dh"], "auth": keys["auth"]},
    )
    return Response({"ok": True}, status=status.HTTP_201_CREATED)


@api_view(["POST"])
def unsubscribe(request):
    """Forget a subscription (sign-out or the reminders toggle turned off)."""
    endpoint = request.data.get("endpoint")
    if endpoint:
        PushSubscription.objects.filter(endpoint=endpoint).delete()
    return Response(status=status.HTTP_204_NO_CONTENT)
