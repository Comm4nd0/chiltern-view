"""Tests for animal/crop photo uploads (multipart)."""
import io
import shutil
import tempfile

from django.contrib.auth.models import User
from django.test import override_settings
from PIL import Image
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Animal

_MEDIA = tempfile.mkdtemp()


def _png_bytes():
    buf = io.BytesIO()
    Image.new("RGB", (4, 4), (120, 180, 90)).save(buf, format="PNG")
    buf.seek(0)
    buf.name = "test.png"
    return buf


@override_settings(MEDIA_ROOT=_MEDIA)
class PhotoUploadTests(APITestCase):
    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(_MEDIA, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        user = User.objects.create_user(username="marco", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_upload_animal_photo(self):
        animal = Animal.objects.create(name="Gertie", species="goat")
        res = self.client.patch(
            f"/api/animals/{animal.id}/",
            {"photo": _png_bytes()},
            format="multipart",
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["photo"])  # a URL is returned
        animal.refresh_from_db()
        self.assertTrue(animal.photo.name.startswith("animals/"))

    def test_create_crop_then_photo(self):
        res = self.client.post("/api/crops/", {"crop": "carrots", "planted_on": "2026-04-01"})
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        crop_id = res.data["id"]
        res = self.client.patch(
            f"/api/crops/{crop_id}/", {"photo": _png_bytes()}, format="multipart"
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["photo"])
