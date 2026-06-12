"""Built-in husbandry knowledge: the default care reminders for each animal type
and for crops.

When an animal or crop is added, these specs are auto-created as ``CareTask`` rows
(see ``signals.py``), so the to-do list comes pre-populated with the routine jobs
that kind of animal or crop needs. Auto-creation is idempotent via
``CareTask.auto_key`` — adding a second chicken does not duplicate the flock's
routine, because the keys for a known species are shared across the species.

Each routine entry is ``(key, name, interval_days)``. To add knowledge about a new
animal or to tweak a schedule, edit the tables below — nothing else needs to change.
"""

# --- Animals ---------------------------------------------------------------
# Per-species recurring routines. Names are written for the holding ("the hens"),
# because these are species-level jobs (you shut the whole flock in at once), not
# per-individual ones. interval_days: 1 = daily, 7 = weekly, 30 ≈ monthly, etc.
ANIMAL_CARE = {
    "chicken": [
        ("let_out", "Let the hens out & check water", 1),
        ("eggs", "Check for & collect eggs", 1),
        ("shut_in", "Shut the hens in for the night", 1),
        ("feed", "Top up hen feed & grit", 3),
        ("clean_coop", "Clean out the coop", 7),
        ("mites", "Check the coop for red mite", 30),
    ],
    "duck": [
        ("let_out", "Let the ducks out & refresh water", 1),
        ("shut_in", "Shut the ducks in for the night", 1),
        ("feed", "Top up duck feed", 3),
        ("clean", "Clean the duck house", 7),
    ],
    "goose": [
        ("let_out", "Let the geese out & refresh water", 1),
        ("shut_in", "Shut the geese in for the night", 1),
        ("clean", "Clean the geese house", 7),
    ],
    "turkey": [
        ("feed", "Feed & water the turkeys", 1),
        ("clean", "Clean the turkey housing", 7),
    ],
    "goat": [
        ("check", "Check the goats — feed & water", 1),
        ("minerals", "Top up the goats' mineral lick", 30),
        ("hooves", "Trim the goats' hooves", 42),
        ("worm", "Worm the goats", 90),
    ],
    "sheep": [
        ("check", "Check the sheep — feed & water", 1),
        ("feet", "Check & trim the sheep's feet", 42),
        ("worm", "Worm the sheep", 90),
        ("shear", "Shearing", 365),
    ],
    "pig": [
        ("feed", "Feed & water the pigs", 1),
        ("muck", "Muck out the pig ark", 7),
        ("worm", "Worm the pigs", 90),
    ],
    "cow": [
        ("check", "Check the cattle — feed & water", 1),
        ("feet", "Foot check / trim", 180),
        ("worm", "Worm the cattle", 90),
    ],
    "rabbit": [
        ("feed", "Feed & water the rabbits", 1),
        ("clean", "Clean out the hutch", 7),
        ("nails", "Check & clip nails", 60),
    ],
    "bees": [
        ("inspect", "Inspect the hive", 7),
        ("varroa", "Check for varroa", 30),
        ("stores", "Check the hive's stores", 30),
    ],
    "horse": [
        ("muck", "Muck out the stable", 1),
        ("feed", "Feed & water the horse", 1),
        ("hooves", "Pick out the horse's hooves", 1),
        ("farrier", "Farrier visit", 42),
        ("worm", "Worm the horse", 90),
        ("dentist", "Horse vaccinations / dentist check", 180),
    ],
    "tortoise": [
        ("feed", "Feed the tortoise & fresh water", 1),
        ("clean", "Clean the tortoise enclosure", 7),
        ("weigh", "Weigh the tortoise", 30),
    ],
    "dog": [
        ("walk", "Walk the dog", 1),
        ("feed", "Feed the dog", 1),
        ("flea", "Dog flea & tick treatment", 30),
        ("worm", "Worm the dog", 90),
        ("vet", "Dog vet check / boosters", 365),
    ],
    "cat": [
        ("feed", "Feed the cat", 1),
        ("litter", "Clean the litter tray", 1),
        ("flea", "Cat flea & tick treatment", 30),
        ("worm", "Worm the cat", 90),
        ("vet", "Cat vet check / boosters", 365),
    ],
}

# Fallback routine for species with no specific table above (incl. "other").
# Uses the individual animal's name, so it's keyed per-animal rather than shared.
GENERIC_ANIMAL_CARE = [
    ("check", "Check on {animal} — feed & water", 1),
    ("clean", "Clean out {animal}'s housing", 7),
    ("health", "Health check: {animal}", 90),
]


def animal_care_specs(animal):
    """Care-task specs for an animal, as a list of dicts with keys:
    ``auto_key``, ``name``, ``interval_days``, ``animal``.

    For a known species the auto_key is shared across the species, so the routine
    is created once however many of that animal you keep. Unknown species fall
    back to a generic per-animal routine.
    """
    routine = ANIMAL_CARE.get(animal.species)
    if routine:
        prefix = f"animal:{animal.species}"
        return [
            {"auto_key": f"{prefix}:{key}", "name": name,
             "interval_days": interval, "animal": animal}
            for key, name, interval in routine
        ]
    prefix = f"animal:{animal.species}:{animal.pk}"
    return [
        {"auto_key": f"{prefix}:{key}", "name": name.format(animal=animal.name),
         "interval_days": interval, "animal": animal}
        for key, name, interval in GENERIC_ANIMAL_CARE
    ]


# --- Crops -----------------------------------------------------------------
# How often to water, in days, by catalog key. Thirsty crops (leafy, cucurbits,
# new beans) get watered more often than established roots and alliums. Stage 4
# will nudge these based on the Medmenham forecast; for now they're fixed.
DEFAULT_WATER_INTERVAL = 3
WATER_INTERVAL = {
    "lettuce": 2, "spinach": 2, "kale": 2,
    "courgettes": 2, "cucumbers": 2, "pumpkins": 2, "tomatoes": 2,
    "runner_beans": 2, "french_beans": 2, "peas": 3, "broad_beans": 3,
    "carrots": 4, "parsnips": 4, "beetroot": 4, "leeks": 4,
    "onions": 5, "garlic": 5,
    "potatoes_first_early": 3, "potatoes_second_early": 3,
    "potatoes_maincrop": 4, "potatoes_salad": 3,
}


def crop_care_specs(crop):
    """Care-task specs for a crop planting: a recurring watering job plus a one-off
    harvest reminder on the estimated harvest date.

    Returned dicts may carry ``interval_days`` (recurring) or ``due_date`` (one-off).
    """
    where = f" ({crop.bed})" if crop.bed else ""
    label = crop.crop_label
    return [
        {
            "auto_key": f"crop:{crop.pk}:water",
            "name": f"Water {label}{where}",
            "interval_days": WATER_INTERVAL.get(crop.crop, DEFAULT_WATER_INTERVAL),
        },
        {
            "auto_key": f"crop:{crop.pk}:harvest",
            "name": f"Harvest {label}{where}",
            "due_date": crop.estimated_harvest,
        },
    ]
