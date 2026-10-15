import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://tseh85.ru/catalog"
SKIPPED_GROUPS = ("Акции и комбо", "Хлеб", "Готовим дома", "Деликатесы", "Десерты/Наборы", "Торты/Предзаказ", "Торты/Новинки")
MAX_PORTION = 600
GROUP_DEFAULTS = {
    "Напитки": "drink",
    "Десерты": "dessert",
    "Торты": "dessert",
    "Выпечка/Сладкая": "dessert",
    "Выпечка/Сытная": "side",
    "Готовая еда/Салаты": "salad",
}
NEXT_DATA = re.compile(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', re.S)
NUTRIENTS = {"Энерг. ценность": "kcal", "Белки": "protein", "Жиры": "fat", "Углеводы": "carbs"}


def state(path):
    return json.loads(NEXT_DATA.search(path.read_text(encoding="utf-8")).group(1))["props"]["initialState"]["products"]


def groups(catalog):
    found = {}
    for group in catalog:
        for child in group.get("childs") or []:
            for product in child.get("products") or []:
                found.setdefault(product["iD"], f'{group["name"]}/{child["name"]}')
    return found


def default_of(group):
    return next((value for key, value in GROUP_DEFAULTS.items() if group.startswith(key)), "main")


def portion_of(product):
    for characteristic in product.get("characteristics") or []:
        if characteristic.get("name") == "Вес":
            text = characteristic["values"][0]["value"]
            match = re.match(r"\s*((?:\d+(?:[.,]\d+)?\s*/\s*)*\d+(?:[.,]\d+)?)\s*г", text)
            if match:
                return sum(float(part.replace(",", ".")) for part in match.group(1).split("/"))
    return None


def main(folder):
    folder = Path(folder)
    catalog = folder / "tseh85.ru_catalog.html"
    placement = groups(state(catalog)["catalogList"])
    items = []
    for path in sorted(folder.glob("products/*.html")):
        info = state(path)["infoMap"]
        for product in info.values():
            group = placement.get(product["iD"], "")
            if not group or product.get("type") == "SET" or group.startswith(SKIPPED_GROUPS):
                continue
            name = product["name"].strip()
            values = {NUTRIENTS[v["name"]]: v["value"] for v in product.get("nutritionValues") or [] if v["name"] in NUTRIENTS}
            portion = portion_of(product)
            if portion and portion > MAX_PORTION:
                continue
            if not portion or len(values) < 4:
                items.append({"name": name})
                continue
            factor = portion / 100
            prices = product.get("prices") or []
            items.append({
                "name": name,
                "portion": portion,
                "price": (prices[0]["price"] or None) if prices else None,
                **{key: round(value * factor, 1) for key, value in values.items()},
                "category": food_category(name, default_of(group)),
                "tags": tags_of(name, product.get("composition") or "", product.get("description") or "") or [""],
            })
    write_menu(
        "ceh85",
        "Цех85",
        items,
        SOURCE_URL,
        date.fromtimestamp(catalog.stat().st_mtime).isoformat(),
        "Карточки товаров сайта tseh85.ru (данные страницы Next.js, nutritionValues): белки, жиры, углеводы и "
        "энергетическая ценность на 100 г — это видно по напиткам разного объёма с одинаковыми значениями, вес — "
        "характеристика «Вес» (для «250/20 г» — сумма); значения пересчитаны на порцию. Отметки исключений — по "
        "составу и «Особенностям состава». Пропущены товары вне каталога, комбо, хлеб, полуфабрикаты, деликатесы, наборы и целые торты.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
