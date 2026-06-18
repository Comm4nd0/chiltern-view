"""Token-auth endpoints: login (obtain token), logout (revoke), me (whoami).

The app is a two-person household tool, so we use DRF's built-in
``TokenAuthentication``: each user gets one long-lived token, sent as
``Authorization: Token <key>``. Accounts are created in the Django admin and
linked to a :class:`~tracker.models.Person` (see ``Person.user``).
"""
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response


def user_payload(user):
    """The shape returned by both login and ``me`` — who you are + your Person."""
    person = getattr(user, "person", None)
    return {
        "id": user.id,
        "username": user.username,
        "person_id": person.id if person else None,
        "person_name": person.name if person else None,
    }


class LoginView(ObtainAuthToken):
    """POST {username, password} -> {token, user: {...}}.

    Open to anyone (it *is* the login). Reuses DRF's ``AuthTokenSerializer`` to
    validate credentials, then returns the token plus the linked Person so the
    client can show who's signed in and default "me" for task assignment.
    """

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data["user"]
        token, _ = Token.objects.get_or_create(user=user)
        return Response({"token": token.key, "user": user_payload(user)})


@api_view(["POST"])
def logout(request):
    """Revoke the caller's token so it can't be reused (sign out)."""
    Token.objects.filter(user=request.user).delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    """Who am I? Lets a client validate a stored token on startup. Requires auth
    (a GET, but it must 401 for guests so the client knows it's signed out)."""
    return Response(user_payload(request.user))
