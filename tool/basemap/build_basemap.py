import json
import sys
import time
import urllib.parse
import urllib.request

from shapely.geometry import LineString, Polygon, shape
from shapely.ops import unary_union

SOUTH, WEST, NORTH, EAST = 55.728, 37.505, 55.792, 37.680
BBOX = f"{SOUTH},{WEST},{NORTH},{EAST}"
ENDPOINTS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]
SCALE = 100000

ROAD_CLASSES = {
    "motorway": "major", "trunk": "major", "primary": "major", "motorway_link": "major", "trunk_link": "major",
    "secondary": "medium", "tertiary": "medium", "primary_link": "medium", "secondary_link": "medium",
    "residential": "minor", "unclassified": "minor", "living_street": "minor", "service": "minor",
    "pedestrian": "path", "footway": "path",
}


def overpass(query):
    body = urllib.parse.urlencode({"data": f"[out:json][timeout:300];{query}"}).encode()
    for attempt in range(6):
        for endpoint in ENDPOINTS:
            try:
                with urllib.request.urlopen(urllib.request.Request(endpoint, data=body), timeout=400) as response:
                    return json.load(response)
            except Exception as error:
                print(f"{endpoint}: {error}", file=sys.stderr)
        time.sleep(20 * (attempt + 1))
    raise SystemExit("overpass is unavailable")


def ways(query):
    return [element for element in overpass(query + "out geom;")["elements"] if element["type"] == "way"]


def coords(element):
    return [(point["lon"], point["lat"]) for point in element.get("geometry", []) if point]


def encode(geometry):
    flat = []
    for lon, lat in geometry:
        flat.extend([round((lon - WEST) * SCALE), round((lat - SOUTH) * SCALE)])
    deltas = flat[:2]
    for index in range(2, len(flat)):
        deltas.append(flat[index] - flat[index - 2])
    return deltas


def polygons(elements, tolerance):
    result = []
    for element in elements:
        points = coords(element)
        if len(points) < 4 or points[0] != points[-1]:
            continue
        polygon = Polygon(points).simplify(tolerance, preserve_topology=True)
        if polygon.is_empty or polygon.area < tolerance * tolerance:
            continue
        result.append(polygon)
    return result


def rings(geometry):
    if geometry.geom_type == "Polygon":
        return [list(geometry.exterior.coords)]
    if geometry.geom_type == "MultiPolygon":
        return [list(part.exterior.coords) for part in geometry.geoms]
    return []


def relation_polygons(query, tolerance):
    elements = overpass(query + "out geom;")["elements"]
    result = []
    for element in elements:
        if element["type"] == "way":
            result.extend(polygons([element], tolerance))
            continue
        outer = [LineString(coords(member)) for member in element.get("members", []) if member.get("role") == "outer" and len(coords(member)) > 1]
        from shapely.ops import polygonize
        merged = list(polygonize(unary_union(outer)))
        result.extend(polygon.simplify(tolerance, preserve_topology=True) for polygon in merged)
    return result


def main():
    water = relation_polygons(f'(way["natural"="water"]({BBOX});relation["natural"="water"]({BBOX});way["waterway"="riverbank"]({BBOX}););', 0.00004)
    green = relation_polygons(
        f'(way["leisure"~"park|garden"]({BBOX});relation["leisure"~"park|garden"]({BBOX});way["landuse"~"grass|forest|recreation_ground"]({BBOX});way["natural"="wood"]({BBOX}););',
        0.00004,
    )
    buildings = polygons(ways(f'way["building"]({BBOX});'), 0.00002)
    roads = {name: [] for name in ("major", "medium", "minor", "path")}
    for element in ways(f'way["highway"~"^({"|".join(ROAD_CLASSES)})$"]({BBOX});'):
        points = coords(element)
        if len(points) < 2:
            continue
        line = LineString(points).simplify(0.00002)
        roads[ROAD_CLASSES[element["tags"]["highway"]]].append(list(line.coords))
    rail = [list(LineString(coords(element)).simplify(0.00003).coords) for element in ways(f'way["railway"~"^(rail|light_rail)$"]["service"!~"."]({BBOX});') if len(coords(element)) > 1]
    stations = overpass(f'node["station"="subway"]["name"]({BBOX});out;')["elements"]
    names = {}
    for element in overpass(f'node["railway"="station"]["station"="subway"]["name"]({BBOX});out;')["elements"] + stations:
        names[element["tags"]["name"]] = (element["lon"], element["lat"])
    basemap = {
        "bounds": {"south": SOUTH, "west": WEST, "north": NORTH, "east": EAST},
        "scale": SCALE,
        "attribution": "© участники OpenStreetMap, ODbL",
        "water": [encode(ring) for polygon in water for ring in rings(polygon)],
        "green": [encode(ring) for polygon in green for ring in rings(polygon)],
        "buildings": [encode(ring) for polygon in buildings for ring in rings(polygon)],
        "roads": {name: [encode(line) for line in lines] for name, lines in roads.items()},
        "rail": [encode(line) for line in rail],
        "metro": [{"name": name, "point": encode([point])} for name, point in sorted(names.items())],
    }
    with open(sys.argv[1], "w", encoding="utf-8") as output:
        json.dump(basemap, output, ensure_ascii=False, separators=(",", ":"))
    print({key: len(value) if isinstance(value, list) else {k: len(v) for k, v in value.items()} if isinstance(value, dict) and key == "roads" else "" for key, value in basemap.items()})


main()
