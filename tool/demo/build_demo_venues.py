import csv
import json
import math
import sys
from pathlib import Path

from shapely.geometry import Point, shape
from shapely.prepared import prep

ROOT = Path(__file__).resolve().parents[2]
DEMO = ROOT / "server/src/main/resources/demo"
ATLAS = ROOT / "app/assets/map/index.json"
PLACES = Path(__file__).with_name("places")
AREAS = Path(__file__).with_name("areas.json")
TOWN_REACH_METERS = 15_000
MIN_GAP_METERS = 40
HEADER = ["name", "address", "lat", "lon", "external_id"]

CHAINS = {
    "grill-house": ("Гриль Хаус", ["restaurant", "bar", "pub", "fast_food"]),
    "warm-bowl": ("Тёплая плошка", ["restaurant", "cafe"]),
    "blinnaya": ("Блинная Масленица", ["fast_food", "cafe"]),
    "zerno": ("Кофейня Зерно", ["cafe"]),
    "pizza-square": ("Пицца Квадрат", ["fast_food", "restaurant"]),
    "green-bar": ("Зелёный бар", ["cafe", "bar"]),
    "lozhka": ("Столовая Ложка", ["restaurant", "food_court", "cafe"]),
    "nori": ("Суши Нори", ["restaurant", "bar", "pub"]),
    "volna": ("Поке Волна", ["fast_food", "cafe"]),
    "kolos": ("Пекарня Колос", ["cafe"]),
}

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


def read_venues(key):
    with open(DEMO / f"{key}-venues.csv", encoding="utf-8") as source:
        return list(csv.DictReader(source, delimiter=";"))


def main():
    venues = {
        key: [row for row in read_venues(key) if "-osm-" not in row["external_id"]]
        if (DEMO / f"{key}-venues.csv").exists() else []
        for key in CHAINS
    }
    taken = [(float(row["lat"]), float(row["lon"])) for rows in venues.values() for row in rows]
    order = sorted(CHAINS)
    counters = {key: 0 for key in CHAINS}
    turn = 0
    zones = areas()
    for region, stations, towns in regions():
        source = PLACES / f"{region}.json"
        if not source.exists():
            continue
        cell = {}
        for point in taken:
            cell.setdefault((round(point[0], 3), round(point[1], 3)), []).append(point)
        for place in json.loads(source.read_text(encoding="utf-8")):
            point = (place["lat"], place["lon"])
            key_cell = (round(point[0], 3), round(point[1], 3))
            nearby = [
                other
                for dy in (-0.001, 0, 0.001)
                for dx in (-0.001, 0, 0.001)
                for other in cell.get((round(key_cell[0] + dy, 3), round(key_cell[1] + dx, 3)), [])
            ]
            if any(distance(point, other) < MIN_GAP_METERS for other in nearby):
                continue
            if any(mark in place["street"] + place["housenumber"] for mark in ';"'):
                continue
            served, town = town_of(point, region, towns, zones)
            if not served:
                continue
            candidates = [key for key in order if place["amenity"] in CHAINS[key][1]]
            if not candidates:
                continue
            key = min(candidates, key=lambda candidate: (counters[candidate], (order.index(candidate) - turn) % len(order)))
            turn += 1
            chain, _ = CHAINS[key]
            address, bare_street = short_street(place["street"])
            if town:
                address = f"{town}, {address}"
            names = {row["name"] for row in venues[key]}
            prefix = f"{chain}, {town}" if town else chain
            label = bare_street
            if stations:
                station, station_point = min(stations, key=lambda item: distance(point, item[1]))
                if distance(point, station_point) < 700:
                    label = station
            name = f"{prefix}, {label}"
            if name in names:
                name = f"{prefix}, {bare_street}"
            if name in names:
                name = f"{prefix}, {bare_street}, {place['housenumber']}"
            if name in names:
                continue
            counters[key] += 1
            venues[key].append({
                "name": name,
                "address": f"{address}, {place['housenumber']}",
                "lat": f"{place['lat']:.6f}",
                "lon": f"{place['lon']:.6f}",
                "external_id": f"{key}-osm-{counters[key]:05d}",
            })
            taken.append(point)
            cell.setdefault(key_cell, []).append(point)
    for key, rows in venues.items():
        with open(DEMO / f"{key}-venues.csv", "w", encoding="utf-8", newline="") as output:
            writer = csv.DictWriter(output, fieldnames=HEADER, delimiter=";", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
    print({key: len(rows) for key, rows in venues.items()}, sum(len(rows) for rows in venues.values()), file=sys.stderr)


main()
