import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from regions import REGIONS

print(json.dumps({
    "directory": sys.argv[1],
    "extracts": [
        {"output": f"{key}.osm.pbf", "bbox": [west - 0.01, south - 0.01, east + 0.01, north + 0.01]}
        for key, (south, west, north, east) in ((key, config["bounds"]) for key, config in REGIONS.items())
    ],
}))
