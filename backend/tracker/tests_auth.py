"""Tests for token auth in read-only mode: reads are public, writes need a token
(plus `me` and the CSV export, which stay sign-in only)."""
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Animal, Person


class AuthTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        self.person = Person.objects.create(name="Marco", user=self.user)

    def test_health_is_open(self):
        """The Docker healthcheck hits /api/health/ unauthenticated."""
        res = self.client.get("/api/health/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_reads_are_public(self):
        # Read-only mode: browsing data needs no login. Includes the endpoints
        # Home Assistant reads (overview, crop board).
        for path in (
            "/api/animals/",
            "/api/care-tasks/",
            "/api/overview/",
            "/api/crops/board/",
            "/api/egg-records/",
        ):
            res = self.client.get(path)
            self.assertEqual(res.status_code, status.HTTP_200_OK, path)

    def test_me_and_export_still_require_auth(self):
        # `me` (whoami) and the bulk CSV export stay sign-in only even though
        # they're GETs.
        for path in ("/api/auth/me/", "/api/export/animals/", "/api/export/"):
            res = self.client.get(path)
            self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED, path)

    def test_writes_require_auth(self):
        animal = Animal.objects.create(name="Gertie", species="goat")
        # Create / edit / delete and the custom write actions all need a token.
        self.assertEqual(
            self.client.post("/api/egg-records/increment/", {"count": 1}).status_code,
            status.HTTP_401_UNAUTHORIZED,
        )
        self.assertEqual(
            self.client.post("/api/animals/", {"name": "Billy", "species": "goat"}).status_code,
            status.HTTP_401_UNAUTHORIZED,
        )
        self.assertEqual(
            self.client.patch(f"/api/animals/{animal.id}/", {"breed": "Saanen"}).status_code,
            status.HTTP_401_UNAUTHORIZED,
        )
        self.assertEqual(
            self.client.delete(f"/api/animals/{animal.id}/").status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

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

    def test_token_grants_write_and_me(self):
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        res = self.client.post("/api/animals/", {"name": "Billy", "species": "goat"})
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        me = self.client.get("/api/auth/me/")
        self.assertEqual(me.status_code, status.HTTP_200_OK)
        self.assertEqual(me.data["person_name"], "Marco")

    def test_logout_revokes_token(self):
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.assertEqual(self.client.post("/api/auth/logout/").status_code, status.HTTP_204_NO_CONTENT)
        # The token is now dead: a write with it is rejected (reads stay public).
        self.assertEqual(
            self.client.post("/api/animals/", {"name": "Nope", "species": "goat"}).status_code,
            status.HTTP_401_UNAUTHORIZED,
        )
