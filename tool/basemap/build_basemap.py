import json
import sys

from shapely import box as make_box
from shapely.geometry import shape
from shapely.ops import unary_union

SOUTH, WEST, NORTH, EAST = 55.728, 37.505, 55.792, 37.680
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


def encode(points):
    flat = []
    for lon, lat in points:
        flat.extend([round((lon - WEST) * SCALE), round((lat - SOUTH) * SCALE)])
    deltas = flat[:2]
    for index in range(2, len(flat)):
        deltas.append(flat[index] - flat[index - 2])
    return deltas


def polygon_parts(geometry):
    if geometry.is_empty:
        return []
    if geometry.geom_type == "Polygon":
        return [geometry]
    if hasattr(geometry, "geoms"):
        return [part for item in geometry.geoms for part in polygon_parts(item)]
    return []


def line_parts(geometry):
    if geometry.is_empty:
        return []
    if geometry.geom_type == "LineString":
        return [geometry]
    if hasattr(geometry, "geoms"):
        return [part for item in geometry.geoms for part in line_parts(item)]
    return []


def rings(polygons):
    result = []
    for polygon in polygons:
        result.append(encode(list(polygon.exterior.coords)))
    return result


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
            return "road:" + ROAD_CLASSES[highway]
        if properties.get("railway") in ("rail", "light_rail") and not properties.get("service"):
            return "rail"
        return None
    if properties.get("station") == "subway" and properties.get("name"):
        return "metro"
    return None


def food_place(properties, geometry, frame):
    if properties.get("amenity") not in FOOD_AMENITIES:
        return None
    street = properties.get("addr:street")
    number = properties.get("addr:housenumber")
    if not street or not number:
        return None
    point = geometry.centroid if geometry.geom_type != "Point" else geometry
    if not frame.contains(point):
        return None
    return {
        "lat": round(point.y, 6),
        "lon": round(point.x, 6),
        "street": street,
        "housenumber": number,
        "amenity": properties["amenity"],
    }


def main():
    frame = make_box(WEST, SOUTH, EAST, NORTH)
    water, green, buildings, rail = [], [], [], []
    roads = {name: [] for name in ("major", "medium", "minor", "path")}
    metro = {}
    places = []
    for feature in features(sys.argv[1]):
        geometry = shape(feature["geometry"])
        properties = feature.get("properties") or {}
        place = food_place(properties, geometry, frame)
        if place is not None:
            places.append(place)
        kind = {"Polygon": "polygon", "MultiPolygon": "polygon", "LineString": "line", "MultiLineString": "line"}.get(
            geometry.geom_type, "point"
        )
        target = classify(properties, kind)
        if target is None:
            continue
        if target == "metro":
            point = geometry.centroid
            if frame.contains(point):
                metro.setdefault(properties["name"], (point.x, point.y))
            continue
        clipped = geometry.intersection(frame)
        if target in ("water", "green", "buildings"):
            tolerance = 0.00002 if target == "buildings" else 0.00004
            minimum = 1.2e-8 if target == "buildings" else 2e-8
            for polygon in polygon_parts(clipped):
                simple = polygon.simplify(tolerance, preserve_topology=True)
                if not simple.is_empty and simple.area >= minimum:
                    {"water": water, "green": green, "buildings": buildings}[target].extend(polygon_parts(simple))
            continue
        for line in line_parts(clipped):
            simple = line.simplify(0.00002)
            if simple.length > (0.0004 if target == "road:path" else 0):
                if target == "rail":
                    rail.append(simple)
                else:
                    roads[target.split(":")[1]].append(simple)
    water = polygon_parts(unary_union(water)) if water else []
    basemap = {
        "bounds": {"south": SOUTH, "west": WEST, "north": NORTH, "east": EAST},
        "scale": SCALE,
        "attribution": "© участники OpenStreetMap, ODbL",
        "water": rings(water),
        "green": rings(green),
        "buildings": rings(buildings),
        "roads": {name: [encode(list(line.coords)) for line in lines] for name, lines in roads.items()},
        "rail": [encode(list(line.coords)) for line in rail],
        "metro": [{"name": name, "point": encode([point])} for name, point in sorted(metro.items())],
    }
    with open(sys.argv[2], "w", encoding="utf-8") as output:
        json.dump(basemap, output, ensure_ascii=False, separators=(",", ":"))
    if len(sys.argv) > 3:
        unique = {(place["street"], place["housenumber"]): place for place in places}
        with open(sys.argv[3], "w", encoding="utf-8") as output:
            json.dump(sorted(unique.values(), key=lambda place: (place["lat"], place["lon"])), output, ensure_ascii=False)
    summary = {key: len(basemap[key]) for key in ("water", "green", "buildings", "rail", "metro")}
    summary["places"] = len(places)
    summary.update({f"roads.{name}": len(lines) for name, lines in roads.items()})
    print(summary)


main()
