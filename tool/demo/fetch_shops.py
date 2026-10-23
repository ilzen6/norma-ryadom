import json
import math
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "basemap"))

from regions import REGIONS

PLACES = Path(__file__).with_name("places")
OVERPASS = "https://overpass-api.de/api/interpreter"
AGENT = "norma-ryadom-coursework/1.0"
BRANDS = {
    "вкусвилл": "ВкусВилл",
    "азбука вкуса": "Азбука вкуса",
    "перекресток": "Перекрёсток",
    "глобус гурмэ": "Глобус Гурмэ",
}
PATTERN = "^(ВкусВилл|Вкусвилл|Азбука [Вв]куса|Перекр[её]сток|Глобус Гурм[эе])$"
CHECK_DATE_TAGS = ("check_date", "survey:date", "check_date:opening_hours", "check_date:shop", "source:date")
SHOP_KINDS = "supermarket|convenience|deli|food"


ADDRESS_REACH_METERS = 40
TILE_DEGREES = 0.15


def shops_query(bounds):
    south, west, north, east = bounds
    box = f"({south},{west},{north},{east})"
    return (
        f"("
        f'nwr["shop"~"^({SHOP_KINDS})$"]["brand"~"{PATTERN}"]{box};'
        f'nwr["shop"~"^({SHOP_KINDS})$"]["name"~"{PATTERN}"]{box};'
        f")"
    )


def query(bounds):
    return f"[out:json][timeout:300];{shops_query(bounds)};out center meta;"


def addresses_query(bounds):
    return (
        f"[out:json][timeout:180];{shops_query(bounds)}->.shops;"
        f'(nwr(around.shops:{ADDRESS_REACH_METERS})["addr:street"]["addr:housenumber"];);out center tags;'
    )


def fetch(bounds, text=None):
    body = urllib.parse.urlencode({"data": text or query(bounds)}).encode()
    request = urllib.request.Request(OVERPASS, data=body, headers={"User-Agent": AGENT, "Accept": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=400) as response:
                return json.load(response)["elements"]
        except OSError as error:
            print("повтор", attempt + 1, error, file=sys.stderr)
            time.sleep(30 * (attempt + 1))
    raise SystemExit("Overpass не ответил")


def brand_of(tags):
    for value in (tags.get("brand"), tags.get("name")):
        key = (value or "").lower().replace("ё", "е")
        if key in BRANDS:
            return BRANDS[key]
    return None


def calendar_date(value):
    value = (value or "").strip()[:10]
    return value if len(value) == 10 and value[4] == "-" and value[7] == "-" else None


def point_of(element):
    return element.get("lat", element.get("center", {}).get("lat")), element.get("lon", element.get("center", {}).get("lon"))


def meters(a, b):
    lat = math.radians((a[0] + b[0]) / 2)
    return math.hypot((a[0] - b[0]) * 111_320, (a[1] - b[1]) * 111_320 * math.cos(lat))


def nearest_address(point, addresses):
    candidates = [(meters(point, spot), street, number) for spot, street, number in addresses]
    near = [candidate for candidate in candidates if candidate[0] <= ADDRESS_REACH_METERS]
    return min(near)[1:] if near else (None, None)


def place_of(element, addresses):
    tags = element.get("tags", {})
    brand = brand_of(tags)
    lat, lon = point_of(element)
    street, number = tags.get("addr:street"), tags.get("addr:housenumber")
    if lat is not None and not (street and number):
        street, number = nearest_address((lat, lon), addresses)
    if not brand or lat is None or not street or not number:
        return None
    dates = [calendar_date(element.get("timestamp"))] + [calendar_date(tags.get(tag)) for tag in CHECK_DATE_TAGS]
    dates = [date for date in dates if date]
    return {
        "lat": round(lat, 6),
        "lon": round(lon, 6),
        "street": street,
        "housenumber": number,
        "amenity": "shop",
        "confirmed": max(dates) if dates else None,
        "hours": "opening_hours" in tags,
        "name": brand,
        "brand": brand,
        "brand_wikidata": tags.get("brand:wikidata"),
        "cuisine": None,
    }


def tiles_without_address(elements):
    tiles = set()
    for element in elements:
        tags = element.get("tags", {})
        lat, lon = point_of(element)
        if lat is not None and not (tags.get("addr:street") and tags.get("addr:housenumber")):
            tiles.add((math.floor(lat / TILE_DEGREES), math.floor(lon / TILE_DEGREES)))
    return sorted(tiles)


def nearby_addresses(elements):
    addresses = []
    tiles = tiles_without_address(elements)
    for index, (row, column) in enumerate(tiles):
        bounds = (row * TILE_DEGREES, column * TILE_DEGREES, (row + 1) * TILE_DEGREES, (column + 1) * TILE_DEGREES)
        found = fetch(bounds, addresses_query(bounds))
        addresses += [(point_of(item), item["tags"]["addr:street"], item["tags"]["addr:housenumber"])
                      for item in found if point_of(item)[0] is not None]
        print(f"адреса: квадрат {index + 1} из {len(tiles)}", file=sys.stderr)
        time.sleep(2)
    return addresses


def main():
    for key, config in REGIONS.items():
        places = {}
        elements = fetch(config["bounds"])
        addresses = nearby_addresses(elements)
        for element in elements:
            place = place_of(element, addresses)
            if place:
                places.setdefault((place["street"], place["housenumber"], round(place["lat"], 4), round(place["lon"], 4)), place)
        rows = sorted(places.values(), key=lambda place: (place["lat"], place["lon"]))
        (PLACES / f"{key}-shops.json").write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")
        print(key, "shops", len(rows), file=sys.stderr)


if __name__ == "__main__":
    main()
