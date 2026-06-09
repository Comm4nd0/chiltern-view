"""Code-defined catalog of crops and their growth stages.

Each crop has a season length (days to harvest) and a list of growth stages given
as (label, fraction-of-season-at-which-the-stage-begins). Stage dates for a given
planting are computed from its planted date and season length. To teach the app a
new crop, add an entry here.
"""

# Reusable stage blueprints by crop family.
_POTATO_STAGES = [
    ("Planted", 0.0),
    ("Sprouting", 0.18),
    ("Earthing up", 0.35),
    ("Flowering", 0.55),
    ("Tuber bulking", 0.70),
    ("Ready to harvest", 1.0),
]
_ROOT_STAGES = [
    ("Sown", 0.0),
    ("Germination", 0.15),
    ("Thinning", 0.30),
    ("Root development", 0.60),
    ("Ready to harvest", 1.0),
]
_ALLIUM_STAGES = [
    ("Planted", 0.0),
    ("Establishing", 0.20),
    ("Bulbing", 0.60),
    ("Ready to harvest", 1.0),
]
_LEGUME_STAGES = [
    ("Sown", 0.0),
    ("Germination", 0.15),
    ("Flowering", 0.50),
    ("Podding", 0.75),
    ("Ready to harvest", 1.0),
]
_CUCURBIT_STAGES = [
    ("Sown", 0.0),
    ("Germination", 0.15),
    ("Vining", 0.40),
    ("Flowering", 0.60),
    ("Fruiting", 0.80),
    ("Ready to harvest", 1.0),
]
_FRUIT_STAGES = [
    ("Sown", 0.0),
    ("Germination", 0.12),
    ("Growing", 0.35),
    ("Flowering", 0.55),
    ("Fruiting", 0.75),
    ("Ready to harvest", 1.0),
]
_LEAFY_STAGES = [
    ("Sown", 0.0),
    ("Germination", 0.20),
    ("Growing", 0.50),
    ("Ready to harvest", 1.0),
]
_BRASSICA_STAGES = [
    ("Sown", 0.0),
    ("Germination", 0.12),
    ("Growing", 0.40),
    ("Heading", 0.70),
    ("Ready to harvest", 1.0),
]

# key -> {label, days_to_harvest, stages}
CROP_CATALOG = {
    "potatoes_first_early": {"label": "Potatoes (first early)", "days_to_harvest": 75, "stages": _POTATO_STAGES},
    "potatoes_second_early": {"label": "Potatoes (second early)", "days_to_harvest": 95, "stages": _POTATO_STAGES},
    "potatoes_maincrop": {"label": "Potatoes (maincrop)", "days_to_harvest": 125, "stages": _POTATO_STAGES},
    "potatoes_salad": {"label": "Potatoes (salad)", "days_to_harvest": 110, "stages": _POTATO_STAGES},
    "carrots": {"label": "Carrots", "days_to_harvest": 75, "stages": _ROOT_STAGES},
    "beetroot": {"label": "Beetroot", "days_to_harvest": 70, "stages": _ROOT_STAGES},
    "parsnips": {"label": "Parsnips", "days_to_harvest": 120, "stages": _ROOT_STAGES},
    "onions": {"label": "Onions", "days_to_harvest": 100, "stages": _ALLIUM_STAGES},
    "garlic": {"label": "Garlic", "days_to_harvest": 240, "stages": _ALLIUM_STAGES},
    "leeks": {"label": "Leeks", "days_to_harvest": 120, "stages": _ALLIUM_STAGES},
    "lettuce": {"label": "Lettuce", "days_to_harvest": 50, "stages": _LEAFY_STAGES},
    "spinach": {"label": "Spinach", "days_to_harvest": 45, "stages": _LEAFY_STAGES},
    "kale": {"label": "Kale", "days_to_harvest": 60, "stages": _LEAFY_STAGES},
    "peas": {"label": "Peas", "days_to_harvest": 70, "stages": _LEGUME_STAGES},
    "broad_beans": {"label": "Broad beans", "days_to_harvest": 90, "stages": _LEGUME_STAGES},
    "runner_beans": {"label": "Runner beans", "days_to_harvest": 80, "stages": _LEGUME_STAGES},
    "french_beans": {"label": "French beans", "days_to_harvest": 65, "stages": _LEGUME_STAGES},
    "courgettes": {"label": "Courgettes", "days_to_harvest": 60, "stages": _CUCURBIT_STAGES},
    "cucumbers": {"label": "Cucumbers", "days_to_harvest": 65, "stages": _CUCURBIT_STAGES},
    "pumpkins": {"label": "Pumpkins & squash", "days_to_harvest": 110, "stages": _CUCURBIT_STAGES},
    "tomatoes": {"label": "Tomatoes", "days_to_harvest": 100, "stages": _FRUIT_STAGES},
    "sweetcorn": {"label": "Sweetcorn", "days_to_harvest": 90, "stages": _FRUIT_STAGES},
    "cabbage": {"label": "Cabbage", "days_to_harvest": 100, "stages": _BRASSICA_STAGES},
    "broccoli": {"label": "Broccoli", "days_to_harvest": 95, "stages": _BRASSICA_STAGES},
    "cauliflower": {"label": "Cauliflower", "days_to_harvest": 100, "stages": _BRASSICA_STAGES},
}

DEFAULT_DAYS_TO_HARVEST = 90
DEFAULT_STAGES = [("Planted", 0.0), ("Growing", 0.40), ("Ready to harvest", 1.0)]


def catalog_list():
    """The catalog as a JSON-serialisable list, for the API + client dropdowns."""
    return [
        {
            "key": key,
            "label": entry["label"],
            "days_to_harvest": entry["days_to_harvest"],
            "stages": [{"label": label, "fraction": frac} for label, frac in entry["stages"]],
        }
        for key, entry in CROP_CATALOG.items()
    ]
