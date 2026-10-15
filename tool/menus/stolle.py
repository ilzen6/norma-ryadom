import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://msk.stolle.ru/"
SECTION_DEFAULTS = {
    "Первые блюда": "main",
    "Вторые блюда": "main",
    "Готовые блюда": "main",
    "Гарниры": "side",
    "Салаты": "salad",
    "Десерты и сладости": "dessert",
    "Печенье": "dessert",
    "Печенье CrmblBrd": "dessert",
    "Напитки": "drink",
}
MAX_PORTION = 500
ALLERGENS = re.compile(r"Аллергены?:\s*([^\n.]*)", re.IGNORECASE)


def amount(item, key):
    value = item.get(key)
    try:
        return float(str(value).replace(",", "."))
    except ValueError:
        return None


def main(path):
    path = Path(path)
    catalog = json.loads(path.read_text(encoding="utf-8"))
    items = []
    for section in catalog:
        default = SECTION_DEFAULTS.get(section["title"])
        if default is None:
            continue
        for item in section.get("catalog_items") or []:
            name = re.sub(r"\s+", " ", item.get("title") or "").strip()
            portion = amount(item, "packing_weights_number")
            if portion and portion > MAX_PORTION:
                continue
            values = [amount(item, key) for key in ("energy_amount", "fiber_amount", "fat_amount", "carbohydrate_amount")]
            if not portion or None in values:
                items.append({"name": name})
                continue
            factor = portion / 100
            kcal, protein, fat, carbs = (round(value * factor, 1) for value in values)
            description = item.get("description") or ""
            allergens = ", ".join(ALLERGENS.findall(description))
            items.append({
                "name": name,
                "portion": round(portion),
                "price": item.get("price"),
                "kcal": kcal,
                "protein": protein,
                "fat": fat,
                "carbs": carbs,
                "category": food_category(name, default),
                "tags": tags_of(name, description, allergens) or [""],
            })
    write_menu(
        "stolle",
        "Штолле",
        items,
        SOURCE_URL,
        date.fromtimestamp(path.stat().st_mtime).isoformat(),
        "Каталог сайта msk.stolle.ru (данные страницы, раздел каталога): energy_amount, fiber_amount (на сайте "
        "подписано «Белки»), fat_amount, carbohydrate_amount — пищевая ценность на 100 г, packing_weights — вес "
        "порции; значения пересчитаны на порцию. Состав и аллергены — из описания. Взяты только порционные разделы "
        "(первые и вторые блюда, гарниры, салаты, готовые блюда, десерты, печенье, напитки); пироги целиком, "
        "варенье, полуфабрикаты и комбо пропущены.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
