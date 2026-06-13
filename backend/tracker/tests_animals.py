"""Tests for animal auto-reminders: the routine must follow the flock/herd as
animals are added, retired, returned, re-typed, and deleted."""
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Animal, CareTask


class AnimalCareTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="claire", password="welly-boots-7")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def make_animal(self, **overrides):
        # JSON, like the real web/Flutter clients — so the model's active=True
        # default applies (a missing boolean in multipart form data reads False).
        payload = {"name": "Henrietta", "species": "chicken", **overrides}
        res = self.client.post("/api/animals/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        return Animal.objects.get(pk=res.data["id"])

    def species_tasks(self, species):
        return CareTask.objects.filter(auto_key__startswith=f"animal:{species}:")

    def test_adding_a_known_species_creates_the_flock_routine(self):
        self.make_animal()
        keys = set(self.species_tasks("chicken").values_list("auto_key", flat=True))
        self.assertIn("animal:chicken:let_out", keys)
        self.assertIn("animal:chicken:clean_coop", keys)

    def test_flock_routine_is_whole_holding_not_linked_to_one_bird(self):
        self.make_animal()
        # Species-level jobs ("shut the hens in") belong to the holding, not a bird.
        self.assertFalse(self.species_tasks("chicken").exclude(animal__isnull=True).exists())

    def test_second_animal_of_a_species_does_not_duplicate_the_routine(self):
        self.make_animal(name="Henrietta")
        before = self.species_tasks("chicken").count()
        self.make_animal(name="Mabel")
        self.assertEqual(self.species_tasks("chicken").count(), before)

    def test_retiring_the_last_animal_deactivates_the_routine(self):
        animal = self.make_animal()
        self.assertTrue(self.species_tasks("chicken").filter(active=True).exists())
        self.client.patch(f"/api/animals/{animal.pk}/", {"active": False}, format="json")
        self.assertFalse(self.species_tasks("chicken").filter(active=True).exists())

    def test_routine_survives_while_one_of_the_species_remains(self):
        first = self.make_animal(name="Henrietta")
        self.make_animal(name="Mabel")
        self.client.patch(f"/api/animals/{first.pk}/", {"active": False}, format="json")
        self.assertTrue(self.species_tasks("chicken").filter(active=True).exists())

    def test_returning_an_animal_reactivates_the_routine(self):
        animal = self.make_animal()
        self.client.patch(f"/api/animals/{animal.pk}/", {"active": False}, format="json")
        self.assertFalse(self.species_tasks("chicken").filter(active=True).exists())
        self.client.patch(f"/api/animals/{animal.pk}/", {"active": True}, format="json")
        self.assertTrue(self.species_tasks("chicken").filter(active=True).exists())

    def test_changing_species_retires_the_old_routine_and_starts_the_new(self):
        animal = self.make_animal(species="goat", name="Billy")
        self.assertTrue(self.species_tasks("goat").filter(active=True).exists())
        self.client.patch(f"/api/animals/{animal.pk}/", {"species": "sheep"}, format="json")
        self.assertFalse(self.species_tasks("goat").filter(active=True).exists())
        self.assertTrue(self.species_tasks("sheep").filter(active=True).exists())

    def test_unknown_species_uses_a_per_individual_routine(self):
        animal = self.make_animal(species="other", name="Gerald")
        keys = list(
            CareTask.objects.filter(
                auto_key__startswith=f"animal:other:{animal.pk}:"
            ).values_list("auto_key", flat=True)
        )
        self.assertTrue(keys)
        # The generic routine is linked to its own animal.
        self.assertTrue(
            CareTask.objects.filter(
                auto_key__startswith=f"animal:other:{animal.pk}:", animal=animal
            ).exists()
        )

    def test_deleting_an_animal_removes_its_private_routine(self):
        animal = self.make_animal(species="other", name="Gerald")
        prefix = f"animal:other:{animal.pk}:"
        self.assertTrue(CareTask.objects.filter(auto_key__startswith=prefix).exists())
        res = self.client.delete(f"/api/animals/{animal.pk}/")
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(CareTask.objects.filter(auto_key__startswith=prefix).exists())

    def test_deleting_the_last_of_a_species_retires_the_shared_routine(self):
        animal = self.make_animal()
        self.client.delete(f"/api/animals/{animal.pk}/")
        # Shared routine is kept for history but deactivated.
        self.assertTrue(self.species_tasks("chicken").exists())
        self.assertFalse(self.species_tasks("chicken").filter(active=True).exists())
