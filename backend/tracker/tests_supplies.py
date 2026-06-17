"""Tests for the feed/supply inventory and its low-stock surfacing."""
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Supply


class SupplyTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="marco", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_is_low_flag(self):
        res = self.client.post(
            "/api/supplies/",
            {"name": "Layer pellets", "unit": "kg", "quantity": "5", "reorder_at": "10"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data["is_low"])

    def test_not_low_when_above_threshold(self):
        res = self.client.post(
            "/api/supplies/",
            {"name": "Straw", "unit": "bales", "quantity": "20", "reorder_at": "5"},
            format="json",
        )
        self.assertFalse(res.data["is_low"])

    def test_overview_lists_low_supplies(self):
        Supply.objects.create(name="Layer pellets", unit="kg", quantity="3", reorder_at="10")
        Supply.objects.create(name="Straw", unit="bales", quantity="20", reorder_at="5")
        # Inactive low supply must not show.
        Supply.objects.create(name="Old wormer", quantity="0", reorder_at="1", active=False)
        res = self.client.get("/api/overview/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        low = res.data["supplies_low"]
        self.assertEqual(len(low), 1)
        self.assertEqual(low[0]["name"], "Layer pellets")
