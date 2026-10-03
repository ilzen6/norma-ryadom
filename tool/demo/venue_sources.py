import csv
from collections import Counter
import json
import math
import sys
from pathlib import Path

from shapely.geometry import Point, shape
from shapely.prepared import prep

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "app/assets/map/index.json"
PLACES = Path(__file__).with_name("places")
AREAS = Path(__file__).with_name("areas.json")
TOWN_REACH_METERS = 15_000
HEADER = ["name", "address", "lat", "lon", "external_id", "confirmed_on"]
FRESH_YEARS = 3
MASS_EDIT_PLACES = 100

STREET_TYPES = [
    ("улица", "ул."),
    ("проспект", "просп."),
    ("набережная", "наб."),
    ("переулок", "пер."),
    ("площадь", "пл."),
    ("бульвар", "бул."),
    ("шоссе", "ш."),
    ("проезд", "пр."),
    ("тупик", "туп."),
]


def distance(a, b):
    lat = math.radians((a[0] + b[0]) / 2)
    dy = (a[0] - b[0]) * 111_320
    dx = (a[1] - b[1]) * 111_320 * math.cos(lat)
    return math.hypot(dx, dy)


def short_street(street):
    words = street.split()
    for full, short in STREET_TYPES:
        if full in words:
            rest = [word for word in words if word != full]
            if full == "улица" and words[-1] == full:
                return f"{short} {' '.join(rest)}", " ".join(rest)
            index = words.index(full)
            return " ".join(words[:index] + [short] + words[index + 1:]), " ".join(rest)
    return street, street


def regions():
    atlas = json.loads(ATLAS.read_text(encoding="utf-8"))
    return [
        (
            region["id"],
            [(station["name"], (station["lat"], station["lon"])) for station in region["metro"]],
            [(label["name"], (label["lat"], label["lon"])) for label in region["labels"]],
        )
        for region in atlas["regions"]
    ]


def areas():
    return [
        (
            area["region"],
            area["town"],
            prep(shape({"type": "MultiPolygon", "coordinates": area["polygons"]})),
        )
        for area in json.loads(AREAS.read_text(encoding="utf-8"))
    ]


def town_of(point, region, towns, zones):
    location = Point(point[1], point[0])
    for zone_region, town, polygon in zones:
        if zone_region != region or not polygon.contains(location):
            continue
        if town != "nearest":
            return True, town
        inside = [item for item in towns if polygon.contains(Point(item[1][1], item[1][0]))]
        if not inside:
            return False, None
        name, place = min(inside, key=lambda item: distance(point, item[1]))
        return distance(point, place) < TOWN_REACH_METERS, name
    return False, None


