import json
import sys
from pathlib import Path

import shapefile
from shapely.geometry import mapping, shape

AREAS = [
    {"region": "moscow", "code": "RU-MOS", "town": None},
    {"region": "moscow", "code": "RU-MOW", "town": "nearest"},
    {"region": "spb", "code": "RU-SPE", "town": "Санкт-Петербург"},
]


def main():
    reader = shapefile.Reader(str(Path(sys.argv[1]) / "ne_10m_admin_1_states_provinces"), encoding="utf-8")
    shapes = {
        item.record["iso_3166_2"]: shape(item.shape.__geo_interface__)
        for item in reader.iterShapeRecords()
        if item.record["adm0_a3"] == "RUS"
    }
    areas = []
    for area in AREAS:
        geometry = shapes[area["code"]].simplify(0.002, preserve_topology=True)
        coordinates = mapping(geometry)["coordinates"]
        polygons = [coordinates] if geometry.geom_type == "Polygon" else list(coordinates)
        areas.append({
            "region": area["region"],
            "town": area["town"],
            "polygons": [[[[round(x, 4), round(y, 4)] for x, y in ring] for ring in polygon] for polygon in polygons],
        })
    Path(__file__).with_name("areas.json").write_text(json.dumps(areas, ensure_ascii=False), encoding="utf-8")


main()
