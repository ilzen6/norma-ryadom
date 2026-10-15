import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, load_api_json, tags_of, write_menu

SOURCE_URL = "https://api.papajohns.ru/catalog/goods?city_id=1&lang=ru"
MAX_PERSONAL_PIZZA_CM = 25
SKIPPED_CATEGORIES = ("combo",)
CATEGORY_DEFAULTS = {"zakuski": "side", "deserty": "dessert", "napitki": "drink", "sauce": "sauce"}
ALLERGENS = re.compile(r"Аллергены:\s*([^.]*)", re.IGNORECASE)


def characteristics(variation):
    return {item["code"]: item["value"] for item in variation.get("characteristics") or []}


def per_100g(values):
    energy = (values.get("energy") or "").split("/")[0]
    return energy, values.get("protein"), values.get("fats"), values.get("carbohydrates")


def label(good, variation, siblings):
    name = re.sub(r"\s+", " ", good["name"]).strip()
    size = variation.get("size") or {}
    if good.get("is_pizza") and size.get("value"):
        return f"{name}, {size['value']} {size.get('unit') or 'см'}"
    if len(siblings) > 1 and size.get("value"):
        return f"{name}, {size['value']} {size.get('unit') or ''}".strip()
    return name


def variants(good):
    found = [variation for variation in good.get("variations") or [] if variation.get("stuffed_crust", "none") == "none"]
    if good.get("is_pizza"):
        found = [
            variation
            for variation in found
            if (variation.get("size") or {}).get("value", 0) <= MAX_PERSONAL_PIZZA_CM
        ]
    return found


def item(good, variation, category, siblings):
    values = characteristics(variation)
    kcal, protein, fat, carbs = per_100g(values)
    weight = values.get("weight") or variation.get("weight")
    composition = variation.get("full_description") or good.get("description") or ""
    allergens = ", ".join(ALLERGENS.findall(composition))
    name = label(good, variation, siblings)
    entry = {"name": name, "price": variation.get("price"), "portion": weight}
    try:
        factor = float(weight) / 100
        entry.update(
            kcal=round(float(kcal) * factor, 1),
            protein=round(float(protein) * factor, 1),
            fat=round(float(fat) * factor, 1),
            carbs=round(float(carbs) * factor, 1),
        )
    except (TypeError, ValueError):
        return entry
    entry["category"] = "main" if good.get("is_pizza") else food_category(name, CATEGORY_DEFAULTS.get(category, "main"))
    entry["tags"] = tags_of(name, composition, allergens) or [""]
    return entry


def main(path):
    catalog, api_url, day = load_api_json(path, "/catalog/goods")
    items = []
    for category in catalog:
        if category.get("alias") in SKIPPED_CATEGORIES:
            continue
        for good in category.get("goods") or []:
            found = variants(good)
            for variation in found:
                items.append(item(good, variation, category.get("alias"), found))
    write_menu(
        "papa-djons",
        "Папа Джонс",
        items,
        api_url or SOURCE_URL,
        day,
        "Каталог сайта papajohns.ru для Москвы (city_id=1): characteristics energy/protein/fats/carbohydrates — "
        "пищевая ценность на 100 г, weight — вес порции; значения пересчитаны на порцию. Состав и аллергены — из "
        "full_description. Пиццы — только 23 см (порция на одного) без сырного борта. Пропущены комбо и позиции без "
        "полного КБЖУ (напитки, соусы).",
    )


if __name__ == "__main__":
    main(sys.argv[1])
