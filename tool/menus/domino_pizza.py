import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, load_api_json, plausible, tags_of, write_menu

SOURCE_URL = "https://dominopizza.ru/gql"
MAX_PERSONAL_PIZZA_CM = 25
SKIPPED_CATEGORIES = ("Комбо",)
PIZZA_CATEGORIES = ("Пиццы", "Римская пицца")
DRINK_CATEGORIES = ("Напитки", "Кофе")
CATEGORY_DEFAULTS = {"Закуски": "side", "Десерты": "dessert", "Соусы": "sauce", **dict.fromkeys(DRINK_CATEGORIES, "drink")}
PIZZA_SUFFIX = re.compile(r"\s+\d+\s*см\b.*$", re.IGNORECASE)
DIAMETER = re.compile(r"(\d+)\s*см", re.IGNORECASE)


def clean(text):
    return re.sub(r"\s+", " ", text or "").strip()


def diet_values(diet, drink):
    values = [diet.get(key) for key in ("calories", "protein", "fat", "carbs")]
    if drink and values[0] is not None and values[3] is not None:
        filled = [value or 0 for value in values]
        if plausible(*filled):
            return filled
    return values


def variants(dish, category):
    group = dish.get("group")
    if not group or not group.get("dishes"):
        return [(clean(dish["name"]), dish.get("weight") or dish.get("volume"), dish.get("diet") or {}, dish["price"] / 100)]
    levels = group["levels"]
    base = clean(dish["name"])
    if category in PIZZA_CATEGORIES:
        base = PIZZA_SUFFIX.sub("", base)
    else:
        for label in (clean(item).rstrip(".") for level in levels for item in level["items"]):
            base = re.sub(rf",?\s*{re.escape(label)}$", "", base, flags=re.IGNORECASE)
    result = []
    for variant in group["dishes"]:
        labels = {
            clean(level["name"] or ""): clean(level["items"][index]).rstrip(".")
            for level, index in zip(levels, variant["levels"])
        }
        size = variant["dish"].get("weight") or variant["dish"].get("volume")
        if category in PIZZA_CATEGORIES:
            found = DIAMETER.search(labels.get("Диаметр", ""))
            if not found or int(found.group(1)) > MAX_PERSONAL_PIZZA_CM:
                continue
            title = f"{base}, {found.group(1)} см, {labels.get('Тесто', '').lower()} тесто".replace(",  тесто", "")
        else:
            title = ", ".join([base, *labels.values()])
        result.append((title, size, variant["dish"].get("diet") or {}, variant["price"]))
    return result


def main(path):
    menu, api_url, day = load_api_json(path, "/gql")
    items = []
    for category in menu["data"]["region"]["categories"]:
        name = category["name"]
        if name in SKIPPED_CATEGORIES:
            continue
        drink = name in DRINK_CATEGORIES
        for dish in category.get("dishes") or []:
            if dish.get("categoryUrl") == "kombo" or clean(dish["name"]).lower().startswith("комбо"):
                continue
            composition = " ".join(clean(f"{item['name']} {item.get('description') or ''}") for item in dish.get("ingredients") or [])
            composition = " ".join([composition, clean(dish.get("consist"))])
            for title, size, diet, price in variants(dish, name):
                kcal, protein, fat, carbs = diet_values(diet, drink)
                entry = {"name": title, "portion": size, "price": price}
                if size and None not in (kcal, protein, fat, carbs):
                    factor = size / 100
                    entry.update(
                        kcal=round(kcal * factor, 1),
                        protein=round(protein * factor, 1),
                        fat=round(fat * factor, 1),
                        carbs=round(carbs * factor, 1),
                        category="main" if name in PIZZA_CATEGORIES else food_category(title, CATEGORY_DEFAULTS.get(name, "main")),
                        tags=tags_of(title, composition) or [""],
                    )
                items.append(entry)
    write_menu(
        "domino-pizza",
        "Domino Pizza",
        items,
        api_url or SOURCE_URL,
        day,
        "Меню сайта dominopizza.ru для Москвы (GraphQL getMenu, domain=msk, dishesFor=all): diet — пищевая ценность "
        "на 100 г (напитки — на 100 мл), weight/volume — порция; значения пересчитаны на порцию. Варианты размера и "
        "теста — из group.dishes; пиццы — только 20 см (порция на одного). У напитков пустые белки и жиры считаются "
        "нулём, только если калории сходятся с углеводами. Состав — названия ингредиентов; отдельного списка "
        "аллергенов сеть не публикует. Пропущены комбо.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
