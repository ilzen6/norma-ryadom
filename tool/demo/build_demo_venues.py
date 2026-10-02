import csv
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEMO = ROOT / "server/src/main/resources/demo"
BASEMAP = ROOT / "app/assets/map/basemap.json"
PLACES = Path(__file__).with_name("places.json")
MIN_GAP_METERS = 60
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


def metro_stations():
    basemap = json.loads(BASEMAP.read_text(encoding="utf-8"))
    south = basemap["bounds"]["south"]
    west = basemap["bounds"]["west"]
    scale = basemap["scale"]
    return [
        (station["name"], (south + station["point"][1] / scale, west + station["point"][0] / scale))
        for station in basemap["metro"]
    ]


def read_venues(key):
    with open(DEMO / f"{key}-venues.csv", encoding="utf-8") as source:
        return list(csv.DictReader(source, delimiter=";"))


def main():
    stations = metro_stations()
    places = json.loads(PLACES.read_text(encoding="utf-8"))
    venues = {key: [row for row in read_venues(key) if not row["external_id"].startswith(f"{key}-osm-")] if (DEMO / f"{key}-venues.csv").exists() else [] for key in CHAINS}
    taken = [(float(row["lat"]), float(row["lon"])) for rows in venues.values() for row in rows]
    order = sorted(CHAINS)
    turn = 0
    for place in places:
        point = (place["lat"], place["lon"])
        if any(distance(point, other) < MIN_GAP_METERS for other in taken):
            continue
        candidates = [key for key in order if place["amenity"] in CHAINS[key][1]]
        if not candidates:
            continue
        key = min(candidates, key=lambda candidate: (len(venues[candidate]), (order.index(candidate) - turn) % len(order)))
        turn += 1
        chain, _ = CHAINS[key]
        address, bare_street = short_street(place["street"])
        station, station_point = min(stations, key=lambda item: distance(point, item[1]))
        names = {row["name"] for row in venues[key]}
        name = f"{chain}, {station}" if distance(point, station_point) < 700 else f"{chain}, {bare_street}"
        if name in names:
            name = f"{chain}, {bare_street}"
        if name in names:
            name = f"{chain}, {bare_street}, {place['housenumber']}"
        if name in names:
            continue
        venues[key].append({
            "name": name,
            "address": f"{address}, {place['housenumber']}",
            "lat": f"{place['lat']:.6f}",
            "lon": f"{place['lon']:.6f}",
            "external_id": f"{key}-osm-{len(venues[key]) + 1:03d}",
        })
        taken.append(point)
    for key, rows in venues.items():
        with open(DEMO / f"{key}-venues.csv", "w", encoding="utf-8", newline="") as output:
            writer = csv.DictWriter(output, fieldnames=HEADER, delimiter=";", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
    print({key: len(rows) for key, rows in venues.items()}, sum(len(rows) for rows in venues.values()), file=sys.stderr)


main()
