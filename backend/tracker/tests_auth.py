"""Tests for token authentication: the API is locked down except health/login."""
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Person


class AuthTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        self.person = Person.objects.create(name="Marco", user=self.user)

    def test_health_is_open(self):
        """The Docker healthcheck hits /api/health/ unauthenticated."""
        res = self.client.get("/api/health/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_endpoints_require_auth(self):
        # Includes the endpoints Home Assistant reads (overview, crop board): the
        # API is internet-facing, so HA authenticates with a token like any client.
        for path in (
            "/api/animals/",
            "/api/care-tasks/",
            "/api/overview/",
            "/api/crops/board/",
            "/api/egg-records/",
            "/api/auth/me/",
        ):
            res = self.client.get(path)
            self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED, path)

    def test_writes_require_auth(self):
        """The HA add-egg / complete-task write commands need a token too."""
        res = self.client.post("/api/egg-records/increment/", {"count": 1})
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_login_returns_token_and_linked_person(self):
        res = self.client.post(
            "/api/auth/login/", {"username": "marco", "password": "welly-boots-7"}
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["token"])
        self.assertEqual(res.data["user"]["username"], "marco")
        self.assertEqual(res.data["user"]["person_id"], self.person.id)
        self.assertEqual(res.data["user"]["person_name"], "Marco")

    def test_login_rejects_bad_password(self):
        res = self.client.post("/api/auth/login/", {"username": "marco", "password": "nope"})
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_token_grants_access_and_me(self):
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.assertEqual(self.client.get("/api/animals/").status_code, status.HTTP_200_OK)
        me = self.client.get("/api/auth/me/")
        self.assertEqual(me.status_code, status.HTTP_200_OK)
        self.assertEqual(me.data["person_name"], "Marco")

    def test_logout_revokes_token(self):
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.assertEqual(self.client.post("/api/auth/logout/").status_code, status.HTTP_204_NO_CONTENT)
        # The same token is now dead.
        self.assertEqual(self.client.get("/api/animals/").status_code, status.HTTP_401_UNAUTHORIZED)
