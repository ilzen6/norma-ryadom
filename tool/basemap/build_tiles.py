import json
import math
import sys
from pathlib import Path

from shapely import box as make_box
from shapely.geometry import shape
from shapely.ops import unary_union

sys.path.insert(0, str(Path(__file__).parent))

from regions import REGIONS

TILE_ZOOM = 14
SCALE = 100000


ROAD_CLASSES = {
    "motorway": "major", "trunk": "major", "primary": "major", "motorway_link": "major", "trunk_link": "major",
    "secondary": "medium", "tertiary": "medium", "primary_link": "medium", "secondary_link": "medium",
    "tertiary_link": "medium",
    "residential": "minor", "unclassified": "minor", "living_street": "minor", "service": "minor",
    "pedestrian": "path", "footway": "path", "cycleway": "path",
}
GREEN_LEISURE = {"park", "garden", "pitch", "playground"}
GREEN_LANDUSE = {"grass", "forest", "recreation_ground", "meadow", "village_green", "cemetery"}
GREEN_NATURAL = {"wood", "scrub", "grassland"}
FOOD_AMENITIES = {"restaurant", "cafe", "fast_food", "food_court", "bar", "pub"}
POLYGON_KINDS = ("water", "green", "buildings")
LINE_KINDS = ("major", "medium", "minor", "path", "rail")


def tile_x(lon):
    return int((lon + 180) / 360 * (1 << TILE_ZOOM))


def tile_y(lat):
    rad = math.radians(lat)
    return int((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * (1 << TILE_ZOOM))


def tile_bounds(x, y):
    n = 1 << TILE_ZOOM
    west = x / n * 360 - 180
    east = (x + 1) / n * 360 - 180
    north = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
    south = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * (y + 1) / n))))
    return south, west, north, east


def encode(points, south, west):
    flat = []
    for lon, lat in points:
        flat.extend([round((lon - west) * SCALE), round((lat - south) * SCALE)])
    deltas = flat[:2]
    for index in range(2, len(flat)):
        deltas.append(flat[index] - flat[index - 2])
    return deltas


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
    return None


def food_place(properties, geometry):
    if properties.get("amenity") not in FOOD_AMENITIES:
        return None
    street = properties.get("addr:street")
    number = properties.get("addr:housenumber")
    if not street or not number:
        return None
    point = geometry if geometry.geom_type == "Point" else geometry.representative_point()
    return {"lat": round(point.y, 6), "lon": round(point.x, 6), "street": street, "housenumber": number,
            "amenity": properties["amenity"]}


class Region:
    def __init__(self, key, config):
        self.key = key
        self.config = config
        south, west, north, east = config["bounds"]
        self.frame = make_box(west, south, east, north)
        self.overview = {kind: [] for kind in POLYGON_KINDS + LINE_KINDS}
        self.metro = {}
        self.places = {}

    def add_overview(self, kind, geometry):
        if kind == "water":
            for polygon in parts(geometry, "Polygon"):
                simple = polygon.simplify(0.00015, preserve_topology=True)
                if simple.area >= 3e-7:
                    self.overview["water"].append(simple)
        elif kind == "green":
            for polygon in parts(geometry, "Polygon"):
                if polygon.area >= 1.5e-6:
                    self.overview["green"].append(polygon.simplify(0.0001, preserve_topology=True))
        elif kind in ("major", "medium", "rail"):
            for line in parts(geometry, "LineString"):
                simple = line.simplify(0.00005)
                if simple.length > 0.0003:
                    self.overview[kind].append(simple)

    def overview_json(self):
        south, west, north, east = self.config["bounds"]
        water = parts(unary_union(self.overview["water"]), "Polygon") if self.overview["water"] else []
        return {
            "bounds": {"south": south, "west": west, "north": north, "east": east},
            "scale": SCALE,
            "attribution": "© участники OpenStreetMap, ODbL",
            "water": [encode(list(p.exterior.coords), south, west) for p in water],
            "green": [encode(list(p.exterior.coords), south, west) for p in self.overview["green"]],
            "buildings": [],
            "roads": {
                kind: [encode(list(line.coords), south, west) for line in self.overview[kind]]
                for kind in ("major", "medium")
            },
            "rail": [encode(list(line.coords), south, west) for line in self.overview["rail"]],
            "metro": [{"name": name, "point": encode([point], south, west)} for name, point in sorted(self.metro.items())],
        }


class Tiles:
    def __init__(self):
        self.tiles = {}

    def add(self, kind, geometry):
        minx, miny, maxx, maxy = geometry.bounds
        for x in range(tile_x(minx), tile_x(maxx) + 1):
            for y in range(tile_y(maxy), tile_y(miny) + 1):
                south, west, north, east = tile_bounds(x, y)
                clipped = geometry.intersection(make_box(west, south, east, north))
                if clipped.is_empty:
                    continue
                bucket = self.tiles.setdefault((x, y), {key: [] for key in POLYGON_KINDS + LINE_KINDS})
                if kind in POLYGON_KINDS:
                    for polygon in parts(clipped, "Polygon"):
                        if polygon.area > 0:
                            bucket[kind].append(encode(list(polygon.exterior.coords), south, west))
                else:
                    for line in parts(clipped, "LineString"):
                        if line.length > 0:
                            bucket[kind].append(encode(list(line.coords), south, west))

    def write(self, directory):
        directory.mkdir(parents=True, exist_ok=True)
        for (x, y), bucket in self.tiles.items():
            south, west, north, east = tile_bounds(x, y)
            data = {
                "bounds": {"south": south, "west": west, "north": north, "east": east},
                "scale": SCALE,
                "attribution": "",
                "water": bucket["water"],
                "green": bucket["green"],
                "buildings": bucket["buildings"],
                "roads": {kind: bucket[kind] for kind in ("major", "medium", "minor", "path")},
                "rail": bucket["rail"],
                "metro": [],
            }
            (directory / f"{x}_{y}.json").write_text(
                json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
            )
        return sorted(f"{x}_{y}" for x, y in self.tiles)


def process(region, path, tiles):
    for feature in features(path):
        geometry = shape(feature["geometry"])
        properties = feature.get("properties") or {}
        place = food_place(properties, geometry)
        if place is not None and region.frame.contains(geometry.representative_point()):
            region.places[(place["street"], place["housenumber"])] = place
        kind = {"Polygon": "polygon", "MultiPolygon": "polygon", "LineString": "line", "MultiLineString": "line"}.get(
            geometry.geom_type, "point"
        )
        target = classify(properties, kind)
        if target is None:
            continue
        if target == "metro":
            point = geometry.representative_point()
            if region.frame.contains(point):
                region.metro.setdefault(properties["name"], (point.x, point.y))
            continue
        clipped = geometry.intersection(region.frame)
        if clipped.is_empty:
            continue
        if target in POLYGON_KINDS:
            tolerance = 0.00002 if target == "buildings" else 0.00004
            minimum = 1.2e-8 if target == "buildings" else 2e-8
            for polygon in parts(clipped, "Polygon"):
                simple = polygon.simplify(tolerance, preserve_topology=True)
                if simple.is_empty or simple.area < minimum:
                    continue
                tiles.add(target, simple)
                region.add_overview(target, simple)
        else:
            for line in parts(clipped, "LineString"):
                simple = line.simplify(0.00002)
                if simple.length <= (0.0004 if target == "path" else 0):
                    continue
                tiles.add(target, simple)
                region.add_overview(target, simple)


def main():
    source = Path(sys.argv[1])
    out = Path(sys.argv[2])
    tiles = Tiles()
    index = {"tileZoom": TILE_ZOOM, "regions": []}
    (out / "map").mkdir(parents=True, exist_ok=True)
    (out / "places").mkdir(parents=True, exist_ok=True)
    for key, config in REGIONS.items():
        region = Region(key, config)
        process(region, source / f"{key}.geojsonseq", tiles)
        overview = f"overview_{key}.json"
        (out / "map" / overview).write_text(
            json.dumps(region.overview_json(), ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
        )
        places = sorted(region.places.values(), key=lambda place: (place["lat"], place["lon"]))
        (out / "places" / f"{key}.json").write_text(json.dumps(places, ensure_ascii=False), encoding="utf-8")
        south, west, north, east = config["bounds"]
        index["regions"].append({
            "id": key,
            "name": config["name"],
            "bounds": {"south": south, "west": west, "north": north, "east": east},
            "center": {"lat": config["center"][0], "lon": config["center"][1]},
            "overview": overview,
            "metro": [
                {"name": name, "lat": round(lat, 6), "lon": round(lon, 6)}
                for name, (lon, lat) in sorted(region.metro.items())
            ],
        })
        print(key, {kind: len(items) for kind, items in region.overview.items()}, "places", len(places), flush=True)
    index["tiles"] = tiles.write(out / "map" / "tiles")
    (out / "map" / "index.json").write_text(json.dumps(index, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("tiles", len(index["tiles"]))


main()
