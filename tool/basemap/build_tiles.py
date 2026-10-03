import json
import math
import sys
from pathlib import Path

from shapely import box as make_box
from shapely.geometry import Polygon, shape
from shapely.ops import unary_union

sys.path.insert(0, str(Path(__file__).parent))

from regions import REGIONS, TILESETS

SCALES = {"overview": 20000, "suburb": 50000, "city": 100000}
MERGED = {key: ("water", "green", "urban") for key in ("overview", "suburb", "city")}
ROAD_CLASSES = {
    "motorway": "major", "trunk": "major", "primary": "major", "motorway_link": "major", "trunk_link": "major",
    "secondary": "medium", "tertiary": "medium", "primary_link": "medium", "secondary_link": "medium",
    "tertiary_link": "medium",
    "residential": "minor", "unclassified": "minor", "living_street": "minor", "service": "service",
    "pedestrian": "path", "footway": "path", "cycleway": "path",
}
GREEN_LEISURE = {"park", "garden", "pitch", "playground"}
GREEN_LANDUSE = {"grass", "forest", "recreation_ground", "meadow", "village_green", "cemetery"}
GREEN_NATURAL = {"wood", "scrub", "grassland"}
URBAN_LANDUSE = {"residential", "commercial", "retail"}
FOOD_AMENITIES = {"restaurant", "cafe", "fast_food", "food_court", "bar", "pub"}
POLYGON_KINDS = ("water", "green", "urban", "buildings")
LINE_KINDS = ("major", "medium", "minor", "path", "rail")
ADDRESS_CELL = 0.001
ADDRESS_REACH_METERS = 60

LEVELS = {
    "overview": {
        "polygons": {"water": (0.0006, 4e-6), "green": (0.0008, 2e-5), "urban": (0.0006, 8e-6)},
        "lines": {"major": (0.0004, 0.002), "medium": (0.0004, 0.004), "rail": (0.0004, 0.003)},
    },
    "suburb": {
        "polygons": {"water": (0.00015, 5e-7), "green": (0.0002, 2e-6), "urban": (0.00015, 1e-6)},
        "lines": {"major": (0.0001, 0), "medium": (0.0001, 0), "minor": (0.0001, 0.0004), "rail": (0.0001, 0)},
    },
    "city": {
        "polygons": {"water": (0.00004, 2e-8), "green": (0.00004, 2e-8), "urban": (0.00004, 2e-8),
                     "buildings": (0.00002, 1.2e-8)},
        "lines": {"major": (0.00002, 0), "medium": (0.00002, 0), "minor": (0.00002, 0), "path": (0.00002, 0.0004),
                  "rail": (0.00002, 0)},
    },
}


def tile_x(lon, zoom):
    return int((lon + 180) / 360 * (1 << zoom))


def tile_y(lat, zoom):
    rad = math.radians(lat)
    return int((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * (1 << zoom))


def tile_bounds(x, y, zoom):
    n = 1 << zoom
    west = x / n * 360 - 180
    east = (x + 1) / n * 360 - 180
    north = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
    south = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * (y + 1) / n))))
    return south, west, north, east


def encode(points, south, west, scale):
    deltas = []
    previous = None
    for lon, lat in points:
        current = (round((lon - west) * scale), round((lat - south) * scale))
        if previous is None:
            deltas.extend(current)
        elif current != previous:
            deltas.extend([current[0] - previous[0], current[1] - previous[1]])
        else:
            continue
        previous = current
    return deltas


def decode(deltas, south, west, scale):
    points = []
    x = y = 0
    for index in range(0, len(deltas), 2):
        x += deltas[index]
        y += deltas[index + 1]
        points.append((west + x / scale, south + y / scale))
    return points


def encode_polygon(polygon, south, west, minimum, scale):
    rings = [encode(list(polygon.exterior.coords), south, west, scale)]
    for interior in polygon.interiors:
        hole = interior.coords
        if len(hole) >= 4 and abs(Polygon(hole).area) > minimum:
            rings.append(encode(list(hole), south, west, scale))
    return [ring for ring in rings if len(ring) >= 6] if len(rings[0]) >= 6 else []


def parts(geometry, kind):
    if geometry.is_empty:
        return []
    if geometry.geom_type == kind:
        return [geometry]
    if hasattr(geometry, "geoms"):
        return [part for item in geometry.geoms for part in parts(item, kind)]
    return []


def features(path):
    with open(path, encoding="utf-8") as source:
        for line in source:
            line = line.strip().lstrip("\x1e")
            if line:
                yield json.loads(line)


def classify(properties, kind):
    if kind == "polygon":
        if properties.get("building"):
            return "buildings"
        if properties.get("natural") == "water" or properties.get("waterway") == "riverbank" or properties.get("water"):
            return "water"
        if (
            properties.get("leisure") in GREEN_LEISURE
            or properties.get("landuse") in GREEN_LANDUSE
            or properties.get("natural") in GREEN_NATURAL
        ):
            return "green"
        if properties.get("landuse") in URBAN_LANDUSE:
            return "urban"
        return None
    if kind == "line":
        highway = properties.get("highway")
        if highway in ROAD_CLASSES and properties.get("area") != "yes":
            if highway == "service" and properties.get("service"):
                return None
            if highway in ("footway", "cycleway") and (
                properties.get("footway") in ("sidewalk", "crossing") or properties.get("indoor") == "yes"
            ):
                return None
            if properties.get("tunnel") == "yes" or properties.get("layer", "0").startswith("-"):
                return None
            return ROAD_CLASSES[highway]
        if properties.get("railway") in ("rail", "light_rail") and not properties.get("service"):
            return "rail"
        return None
    if properties.get("station") == "subway" and properties.get("name"):
        return "metro"
    if properties.get("place") in ("city", "town") and properties.get("name"):
        return "label"
    return None


def meters(lat1, lon1, lat2, lon2):
    scale = math.cos(math.radians((lat1 + lat2) / 2))
    return math.hypot((lat1 - lat2) * 111_320, (lon1 - lon2) * 111_320 * scale)


class Tileset:
    def __init__(self, key):
        self.key = key
        self.zoom = TILESETS[key]["zoom"]
        self.pack = TILESETS[key]["pack"]
        self.scale = SCALES[key]
        self.tiles = {}

    def add(self, kind, geometry, minimum):
        minx, miny, maxx, maxy = geometry.bounds
        for x in range(tile_x(minx, self.zoom), tile_x(maxx, self.zoom) + 1):
            for y in range(tile_y(maxy, self.zoom), tile_y(miny, self.zoom) + 1):
                south, west, north, east = tile_bounds(x, y, self.zoom)
                clipped = geometry.intersection(make_box(west, south, east, north))
                if clipped.is_empty:
                    continue
                bucket = self.tiles.setdefault((x, y), {name: [] for name in POLYGON_KINDS + LINE_KINDS})
                if kind in POLYGON_KINDS:
                    for polygon in parts(clipped, "Polygon"):
                        rings = encode_polygon(polygon, south, west, minimum, self.scale) if polygon.area > 0 else []
                        if rings:
                            bucket[kind].append(rings)
                else:
                    for line in parts(clipped, "LineString"):
                        encoded = encode(list(line.coords), south, west, self.scale) if line.length > 0 else []
                        if len(encoded) >= 4:
                            bucket[kind].append(encoded)

    def merged(self, kind, shapes, south, west):
        tolerance, minimum = LEVELS[self.key]["polygons"][kind]
        polygons = []
        for rings in shapes:
            outer, *holes = [decode(ring, south, west, self.scale) for ring in rings]
            polygon = Polygon(outer, holes).buffer(0)
            if not polygon.is_empty:
                polygons.append(polygon)
        if not polygons:
            return []
        union = unary_union(polygons).simplify(tolerance / 2, preserve_topology=True)
        result = []
        for polygon in parts(union, "Polygon"):
            if polygon.area >= minimum:
                rings = encode_polygon(polygon, south, west, minimum, self.scale)
                if rings:
                    result.append(rings)
        return result

    def write(self, directory):
        packs = {}
        shift = self.zoom - self.pack
        for (x, y), bucket in self.tiles.items():
            south, west, north, east = tile_bounds(x, y, self.zoom)
            for kind in MERGED.get(self.key, ()):
                bucket[kind] = self.merged(kind, bucket[kind], south, west)
            packs.setdefault((x >> shift, y >> shift), {})[f"{x}_{y}"] = {
                "bounds": {"south": south, "west": west, "north": north, "east": east},
                "scale": self.scale,
                "water": bucket["water"],
                "green": bucket["green"],
                "urban": bucket["urban"],
                "buildings": bucket["buildings"],
                "roads": {name: bucket[name] for name in ("major", "medium", "minor", "path")},
                "rail": bucket["rail"],
            }
        target = directory / self.key
        target.mkdir(parents=True, exist_ok=True)
        for (px, py), tiles in packs.items():
            (target / f"{px}_{py}.json").write_text(
                json.dumps(tiles, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
            )
        return {"zoom": self.zoom, "packZoom": self.pack, "packs": sorted(f"{px}_{py}" for px, py in packs)}


class Region:
    def __init__(self, key, config):
        self.key = key
        self.config = config
        south, west, north, east = config["bounds"]
        self.frame = make_box(west, south, east, north)
        c_south, c_west, c_north, c_east = config["city"]
        self.city = make_box(c_west, c_south, c_east, c_north)
        self.metro = {}
        self.labels = {}
        self.places = {}
        self.unaddressed = []
        self.addresses = {}

    def add_address(self, lat, lon, street, number):
        self.addresses.setdefault((int(lat / ADDRESS_CELL), int(lon / ADDRESS_CELL)), []).append((lat, lon, street, number))

    def nearest_address(self, lat, lon):
        cell = (int(lat / ADDRESS_CELL), int(lon / ADDRESS_CELL))
        best = None
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                for candidate in self.addresses.get((cell[0] + dy, cell[1] + dx), []):
                    distance = meters(lat, lon, candidate[0], candidate[1])
                    if distance <= ADDRESS_REACH_METERS and (best is None or distance < best[0]):
                        best = (distance, candidate)
        return None if best is None else best[1]

    def resolve_places(self):
        for place in self.unaddressed:
            found = self.nearest_address(place["lat"], place["lon"])
            if found is not None:
                place["street"], place["housenumber"] = found[2], found[3]
                key = (place["street"], place["housenumber"], round(place["lat"], 4), round(place["lon"], 4))
                self.places.setdefault(key, place)


def add_to_levels(region, target, clipped, tilesets):
    in_city = clipped.intersects(region.city)
    for level, tileset in tilesets.items():
        if level == "city" and not in_city:
            continue
        geometry = clipped.intersection(region.city) if level == "city" else clipped
        kind = "minor" if target == "service" else target
        if target == "service" and level != "city":
            continue
        if kind in POLYGON_KINDS:
            rule = LEVELS[level]["polygons"].get(kind)
            if rule is None:
                continue
            tolerance, minimum = rule
            for polygon in parts(geometry, "Polygon"):
                simple = polygon.simplify(tolerance, preserve_topology=True)
                if not simple.is_empty and simple.area >= minimum:
                    tileset.add(kind, simple, minimum)
        else:
            rule = LEVELS[level]["lines"].get(kind)
            if rule is None:
                continue
            tolerance, minimum = rule
            for line in parts(geometry, "LineString"):
                simple = line.simplify(tolerance)
                if simple.length > minimum:
                    tileset.add(kind, simple, 0)


def process(region, path, tilesets):
    for feature in features(path):
        geometry = shape(feature["geometry"])
        properties = feature.get("properties") or {}
        point = geometry if geometry.geom_type == "Point" else None
        street, number = properties.get("addr:street"), properties.get("addr:housenumber")
        if street and number:
            anchor = point or geometry.representative_point()
            region.add_address(anchor.y, anchor.x, street, number)
        if properties.get("amenity") in FOOD_AMENITIES:
            anchor = point or geometry.representative_point()
            if region.frame.contains(anchor):
                place = {"lat": round(anchor.y, 6), "lon": round(anchor.x, 6), "street": street, "housenumber": number,
                         "amenity": properties["amenity"]}
                if street and number:
                    region.places.setdefault((street, number, round(anchor.y, 4), round(anchor.x, 4)), place)
                else:
                    region.unaddressed.append(place)
        kind = {"Polygon": "polygon", "MultiPolygon": "polygon", "LineString": "line", "MultiLineString": "line"}.get(
            geometry.geom_type, "point"
        )
        target = classify(properties, kind)
        if target is None:
            continue
        if target in ("metro", "label"):
            anchor = geometry.representative_point()
            if not region.frame.contains(anchor):
                continue
            if target == "metro":
                region.metro.setdefault(properties["name"], (anchor.x, anchor.y))
            else:
                population = int("".join(ch for ch in properties.get("population", "") if ch.isdigit()) or 0)
                rank = 2 if properties["place"] == "city" or population >= 100_000 else 4
                region.labels.setdefault(properties["name"], (anchor.x, anchor.y, rank))
            continue
        clipped = geometry.intersection(region.frame)
        if not clipped.is_empty:
            add_to_levels(region, target, clipped, tilesets)


def main():
    source = Path(sys.argv[1])
    out = Path(sys.argv[2])
    (out / "map" / "packs").mkdir(parents=True, exist_ok=True)
    (out / "places").mkdir(parents=True, exist_ok=True)
    tilesets = {key: Tileset(key) for key in TILESETS}
    index = {"country": "country.json", "regions": []}
    for key, config in REGIONS.items():
        region = Region(key, config)
        process(region, source / f"{key}.geojsonseq", tilesets)
        region.resolve_places()
        places = sorted(region.places.values(), key=lambda place: (place["lat"], place["lon"]))
        (out / "places" / f"{key}.json").write_text(json.dumps(places, ensure_ascii=False), encoding="utf-8")
        south, west, north, east = config["bounds"]
        c_south, c_west, c_north, c_east = config["city"]
        index["regions"].append({
            "id": key,
            "name": config["name"],
            "bounds": {"south": south, "west": west, "north": north, "east": east},
            "city": {"south": c_south, "west": c_west, "north": c_north, "east": c_east},
            "center": {"lat": config["center"][0], "lon": config["center"][1]},
            "metro": [
                {"name": name, "lat": round(lat, 6), "lon": round(lon, 6)}
                for name, (lon, lat) in sorted(region.metro.items())
            ],
            "labels": [
                {"name": name, "lat": round(lat, 6), "lon": round(lon, 6), "rank": rank}
                for name, (lon, lat, rank) in sorted(region.labels.items(), key=lambda item: item[1][2])
            ],
        })
        print(key, "places", len(places), "labels", len(region.labels), "metro", len(region.metro), flush=True)
    index["tilesets"] = {key: tileset.write(out / "map" / "packs") for key, tileset in tilesets.items()}
    for key, tileset in index["tilesets"].items():
        print(key, "packs", len(tileset["packs"]), "tiles", len(tilesets[key].tiles))
    (out / "map" / "index.json").write_text(json.dumps(index, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


main()
