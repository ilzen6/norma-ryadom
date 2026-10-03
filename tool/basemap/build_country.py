import json
import sys
from pathlib import Path

import shapefile
from shapely import box as make_box
from shapely.geometry import shape
from shapely.ops import unary_union

SOUTH, WEST, NORTH, EAST = 41.0, 19.0, 82.0, 180.0
SCALE = 1000
COUNTRY = "RUS"


def encode(points):
    flat = []
    for lon, lat in points:
        flat.extend([round((lon - WEST) * SCALE), round((lat - SOUTH) * SCALE)])
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


def polygon_rings(polygon, minimum):
    rings = [encode(list(polygon.exterior.coords))]
    for interior in polygon.interiors:
        if shape({"type": "Polygon", "coordinates": [list(interior.coords)]}).area > minimum:
            rings.append(encode(list(interior.coords)))
    return rings


def records(source, name):
    reader = shapefile.Reader(str(source / name), encoding="utf-8")
    for item in reader.iterShapeRecords():
        if item.shape.shapeType == shapefile.NULL:
            continue
        yield shape(item.shape.__geo_interface__), item.record.as_dict()


def clipped(geometry, frame):
    return geometry.intersection(frame) if geometry.intersects(frame) else None


def polygons(source, name, frame, tolerance, minimum, keep=lambda record: True):
    result = []
    for geometry, record in records(source, name):
        if not keep(record):
            continue
        part = clipped(geometry, frame)
        if part is None:
            continue
        for polygon in parts(part.simplify(tolerance, preserve_topology=True), "Polygon"):
            if polygon.area >= minimum:
                result.append(polygon)
    return result


def lines(source, name, frame, tolerance, keep=lambda record: True, minimum=0.0):
    result = []
    for geometry, record in records(source, name):
        if not keep(record):
            continue
        part = clipped(geometry, frame)
        if part is None:
            continue
        for line in parts(part.simplify(tolerance), "LineString"):
            if line.length > minimum:
                result.append(encode(list(line.coords)))
    return result


def label_rank(record):
    if record["ADM0CAP"]:
        return 0
    population = record["POP_MAX"] or 0
    if population >= 1_000_000:
        return 1
    if population >= 300_000:
        return 2
    if population >= 100_000:
        return 3
    return 4


def main():
    source = Path(sys.argv[1])
    russia = next(
        geometry for geometry, record in records(source, "ne_10m_admin_0_countries") if record["ADM0_A3"] == COUNTRY
    )
    frame = russia.simplify(0.02).buffer(0.05).intersection(make_box(WEST, SOUTH, EAST, NORTH))
    extent = make_box(WEST, SOUTH, EAST, NORTH)
    ocean = polygons(source, "ne_10m_ocean", extent, 0.02, 0.002)
    lakes = polygons(source, "ne_10m_lakes", extent, 0.01, 0.002, lambda record: (record["scalerank"] or 0) <= 6)
    water = parts(unary_union(ocean + lakes), "Polygon")
    labels = []
    for geometry, record in records(source, "ne_10m_populated_places"):
        if record["ADM0_A3"] != COUNTRY:
            continue
        name = record.get("NAME_RU") or record["NAME"]
        labels.append({"name": name, "point": encode([(geometry.x, geometry.y)]), "rank": label_rank(record)})
    labels.sort(key=lambda label: label["rank"])
    country = {
        "bounds": {"south": SOUTH, "west": WEST, "north": NORTH, "east": EAST},
        "scale": SCALE,
        "attribution": "Natural Earth",
        "water": [polygon_rings(polygon, 0.01) for polygon in water],
        "green": [],
        "buildings": [],
        "roads": {
            "major": lines(
                source,
                "ne_10m_roads",
                frame,
                0.01,
                lambda record: record["type"] == "Major Highway",
            ),
            "medium": lines(
                source,
                "ne_10m_roads",
                frame,
                0.01,
                lambda record: record["type"] in ("Secondary Highway", "Road"),
                0.05,
            ),
        },
        "rail": lines(source, "ne_10m_railroads", frame, 0.01, lambda record: (record["scalerank"] or 10) <= 7, 0.05),
        "rivers": lines(
            source,
            "ne_10m_rivers_lake_centerlines",
            extent,
            0.01,
            lambda record: record["featurecla"] == "River" and (record["scalerank"] or 10) <= 8,
        ),
        "borders": lines(source, "ne_10m_admin_0_boundary_lines_land", extent, 0.01),
        "admin": lines(
            source, "ne_10m_admin_1_states_provinces_lines", frame, 0.01, lambda record: record["ADM0_A3"] == COUNTRY
        ),
        "metro": [],
        "labels": labels,
    }
    Path(sys.argv[2]).write_text(json.dumps(country, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print({key: len(value) for key, value in country.items() if isinstance(value, list)},
          {key: len(value) for key, value in country["roads"].items()})


main()
