import csv
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from venue_sources import (
    FRESH_YEARS,
    HEADER,
    MASS_EDIT_PLACES,
    PLACES,
    areas,
    regions,
    short_street,
    town_of,
)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "server/src/main/resources/demo/real"
BRANDS = Path(__file__).with_name("brands.json")
STATUS = Path(__file__).with_name("chain_status.json")
MIN_CHAIN_PLACES = 5
MIN_UNBRANDED_CHAIN_PLACES = 10
GENERIC_NAMES = {
    "кафе", "бар", "кофейня", "пекарня", "столовая", "буфет", "кебаб", "шаверма", "шаурма", "шавуха", "донер",
    "хинкальная", "чайхана", "чайхона", "пиццерия", "суши", "бургерная", "блинная", "пельменная", "чебуречная",
    "кулинария", "закусочная", "ресторан", "пивной бар", "паб", "кофе", "кафетерий", "пончики", "пышечная",
    "шашлычная", "бистро", "кофе с собой", "восток", "кофе на вынос", "фастфуд", "гриль", "пироги",
}
TRANSLIT = str.maketrans("абвгдеёжзийклмнопрстуфхцчшщъыьэюя", "abvgdeejziiklmnoprstufhccss_y_eua")


def key_of(name):
    return re.sub(r"[^0-9a-z]", "", (name or "").lower().replace("ё", "е").translate(TRANSLIT))


def display_name(spellings):
    ranked = sorted(spellings.items(), key=lambda item: (not item[0][:1].isupper(), -item[1], item[0]))
    return ranked[0][0]


def slug_of(name):
    return re.sub(r"_+", "-", re.sub(r"[^0-9a-z]+", "_", name.lower().translate(TRANSLIT))).strip("-_")


def fresh_places():
    sources = {region: json.loads((PLACES / f"{region}.json").read_text(encoding="utf-8"))
               for region, _, _ in regions() if (PLACES / f"{region}.json").exists()}
    newest = max(place["confirmed"] for places in sources.values() for place in places if place.get("confirmed"))
    fresh_since = f"{int(newest[:4]) - FRESH_YEARS}{newest[4:]}"
    zones = areas()
    towns = {region: labels for region, _, labels in regions()}
    stats = Counter()
    for region, places in sources.items():
        bulk = {day for day, count in Counter(place.get("confirmed") for place in places).items()
                if day and count > MASS_EDIT_PLACES}
        for place in places:
            if not place.get("name"):
                stats["unnamed"] += 1
            elif place.get("confirmed") in bulk:
                stats["bulk edit"] += 1
            elif (place.get("confirmed") or "") < fresh_since:
                stats["stale"] += 1
            elif any(mark in place["street"] + place["housenumber"] + place["name"] for mark in ';"'):
                stats["unsafe text"] += 1
            else:
                served, town = town_of((place["lat"], place["lon"]), region, towns[region], zones)
                if not served:
                    stats["outside service area"] += 1
                    continue
                stats["kept"] += 1
                yield place, town
    print(dict(stats), "fresh since", fresh_since, file=sys.stderr)


def main():
    status = {key_of(entry["chain"]): entry for entry in json.loads(STATUS.read_text(encoding="utf-8"))}

    def current(name):
        entry = status.get(key_of(name))
        if entry is None:
            return name
        return entry["now"] if entry["status"] == "renamed" else None

    kept = []
    dropped = Counter()
    for place, town in fresh_places():
        brand = current(place["brand"]) if place.get("brand") else None
        name = current(place["name"])
        if (place.get("brand") and brand is None) or name is None:
            dropped[place.get("brand") or place["name"]] += 1
            continue
        kept.append(({**place, "brand": brand, "name": name if brand is None else brand}, town))
    print("dropped by chain status", dict(dropped), file=sys.stderr)
    branded = defaultdict(Counter)
    for place, _ in kept:
        if place.get("brand"):
            branded[key_of(place["brand"])][place["brand"]] += 1
    chains = {key: display_name(spellings)
              for key, spellings in branded.items() if sum(spellings.values()) >= MIN_CHAIN_PLACES}
    unbranded = defaultdict(Counter)
    for place, _ in kept:
        if not place.get("brand") and place["name"].strip().lower() not in GENERIC_NAMES:
            unbranded[key_of(place["name"])][place["name"]] += 1
    chains.update({key: display_name(spellings) for key, spellings in unbranded.items()
                   if key not in chains and sum(spellings.values()) >= MIN_UNBRANDED_CHAIN_PLACES})
    rows = defaultdict(list)
    seen = set()
    for place, town in kept:
        key = key_of(place.get("brand")) or key_of(place["name"])
        chain = key if key in chains else None
        name = chains[chain] if chain else place["name"]
        street, _ = short_street(place["street"])
        address = f"{street}, {place['housenumber']}"
        identity = (key_of(name), round(place["lat"], 4), round(place["lon"], 4))
        if identity in seen:
            continue
        seen.add(identity)
        rows[chain].append({
            "name": name,
            "address": f"{town}, {address}" if town else address,
            "lat": f"{place['lat']:.6f}",
            "lon": f"{place['lon']:.6f}",
            "external_id": f"osm-{place['lat']:.5f}-{place['lon']:.5f}",
            "confirmed_on": place["confirmed"],
        })
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*-venues.csv"):
        old.unlink()
    brands = []
    for chain, venues in sorted(rows.items(), key=lambda item: (item[0] is not None, -len(item[1]))):
        file = "places-venues.csv" if chain is None else f"{slug_of(chains[chain])}-venues.csv"
        with open(OUT / file, "w", encoding="utf-8", newline="") as output:
            writer = csv.DictWriter(output, fieldnames=HEADER, delimiter=";", lineterminator="\n")
            writer.writeheader()
            writer.writerows(sorted(venues, key=lambda row: row["external_id"]))
        if chain is not None:
            brands.append({"name": chains[chain], "venues": f"demo/real/{file}", "count": len(venues)})
    brands.sort(key=lambda brand: -brand["count"])
    BRANDS.write_text(json.dumps(brands, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("chains", len(brands), "chain venues", sum(b["count"] for b in brands),
          "independent", len(rows[None]), file=sys.stderr)


if __name__ == "__main__":
    main()
