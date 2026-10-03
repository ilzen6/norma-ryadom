import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REAL = ROOT / "server/src/main/resources/demo/real"
MENUS = ROOT / "tool/menus"
PROFILE = ROOT / "server/src/main/resources/application-demo.yml"
BRANDS = Path(__file__).with_name("brands.json")
OSM = "https://www.openstreetmap.org/copyright"


def quoted(value):
    return json.dumps(value, ensure_ascii=False)


def main():
    brands = json.loads(BRANDS.read_text(encoding="utf-8"))
    chains = []
    for brand in brands:
        slug = Path(brand["venues"]).name.removesuffix("-venues.csv")
        meta_file = MENUS / f"{slug}.json"
        menu = REAL / f"{slug}-menu.csv"
        meta = json.loads(meta_file.read_text(encoding="utf-8")) if meta_file.exists() and menu.exists() else None
        chains.append((brand, slug, meta))
    chains.sort(key=lambda entry: (entry[2] is None, -entry[0]["count"]))
    lines = ["demo:", "  places: classpath:demo/real/places-venues.csv", "  chains:"]
    for brand, slug, meta in chains:
        lines.append(f"    - name: {quoted(brand['name'])}")
        lines.append(f"      source-url: {quoted(meta['source_url'] if meta else OSM)}")
        if meta:
            if meta.get("source_date"):
                lines.append(f"      source-date: {meta['source_date']}")
            lines.append(f"      menu: classpath:demo/real/{slug}-menu.csv")
        lines.append(f"      venues: classpath:demo/real/{slug}-venues.csv")
    PROFILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    with_menu = [brand["name"] for brand, _, meta in chains if meta]
    print("chains", len(chains), "with official menu", with_menu)


if __name__ == "__main__":
    main()
