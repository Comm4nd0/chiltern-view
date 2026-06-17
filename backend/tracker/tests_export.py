"""Tests for the CSV export endpoints (a self-hosted data backup)."""
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Animal, EggRecord


class ExportTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="marco", password="welly-boots-7")
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_export_requires_auth(self):
        self.client.credentials()  # drop the token
        res = self.client.get("/api/export/animals/")
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_export_animals_csv(self):
        Animal.objects.create(name="Gertie", species="goat", breed="Saanen")
        res = self.client.get("/api/export/animals/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res["Content-Type"], "text/csv")
        self.assertIn("attachment; filename=", res["Content-Disposition"])
        body = res.content.decode()
        self.assertIn("name,species,breed", body)
        self.assertIn("Gertie,goat,Saanen", body)

    def test_export_eggs_csv(self):
        EggRecord.objects.create(date="2026-06-01", count=6, source="Coop A")
        res = self.client.get("/api/export/eggs/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("2026-06-01,6,Coop A", res.content.decode())

    def test_unknown_dataset_404(self):
        res = self.client.get("/api/export/nonsense/")
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    def test_export_index_lists_datasets(self):
        res = self.client.get("/api/export/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("animals", res.data["datasets"])
        self.assertIn("journal", res.data["datasets"])
