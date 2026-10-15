import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import category_of, load_api_json, tags_of, write_menu

SITE = "https://dodopizza.ru/moscow"
MENU_API = "/api/v5/menu/delivery/countries/643/localities/"
SKIPPED_SECTIONS = ("Комбо", "Мерч")
PIZZA_SECTIONS = ("Пиццы", "Римские пиццы")
VOLUME = re.compile(r"(\d+(?:[.,]\d+)?)\s*л")
PIECES = re.compile(r"(\d+)\s*шт")
DIAMETER = re.compile(r"(\d+)\s*см")
MAX_PERSONAL_PIZZA_CM = 25


def sections(menu):
    result = {}
    for section in menu["structure"]:
        for entry in section.get("items") or []:
            ref = (entry.get("menuItem") or {}).get("$ref")
            if ref:
                result.setdefault(int(ref.rsplit("/", 1)[1]), section["title"])
    return result


def dough(product):
    for group in product.get("ingredientGroups") or []:
        if group.get("isBasis"):
            return group["name"].lower()
    return ""


def millilitres(product):
    found = VOLUME.search(product.get("size") or "")
    return round(float(found.group(1).replace(",", ".")) * 1000) if found else None


def diameter(product):
    found = DIAMETER.search(product.get("size") or "")
    return int(found.group(1)) if found else None


def pizza_variants(name, variants):
    doughs = {dough for _, dough, _ in variants}
    result = []
    for size, dough, product in sorted(variants, key=lambda variant: (variant[0] or 0, variant[1])):
        if size is None or size > MAX_PERSONAL_PIZZA_CM:
            continue
        title = f"{name}, {size} см" if len(doughs) == 1 else f"{name}, {size} см, {dough} тесто"
        result.append((title, product))
    return result


def label(name, product, drink, siblings):
    if drink:
        volume = millilitres(product)
        return f"{name}, {volume} мл" if volume else name
    if len(siblings) > 1:
        pieces = PIECES.search(product.get("size") or "")
        if pieces:
            return f"{name}, {pieces.group(1)} шт"
        return f"{name}, {product['foodValue']['weight']:g} г"
    return name


def category(section, traits, name):
    if traits.get("drink") or section in ("Кофе и чай", "Напитки"):
        return "drink"
    if traits.get("sauce") or section == "Соусы":
        return "sauce"
    if traits.get("dessert") or section == "Десерты":
        return "dessert"
    return category_of(name, "main")


def row(name, product, section, portion):
    food = product["foodValue"]
    factor = portion / 100
    composition = product.get("compositionDescription") or ""
    allergens = (product.get("allergyAdvice") or {}).get("contains") or ""
    return {
        "name": name,
        "kcal": round(food["calories"] * factor, 1),
        "protein": round(food["proteins"] * factor, 1),
        "fat": round(food["fats"] * factor, 1),
        "carbs": round(food["carbohydrates"] * factor, 1),
        "portion": portion,
        "price": product.get("price"),
        "category": category(section, product.get("traits") or {}, name),
        "tags": tags_of(name, composition, allergens) or [""],
    }


def main(path):
    menu, api_url, day = load_api_json(path, MENU_API)
    owners = sections(menu)
    items = []
    for index, item in sorted(enumerate(menu["items"]), key=lambda pair: pair[0]):
        section = owners.get(index)
        if item.get("type") != "Product" or section is None or section in SKIPPED_SECTIONS:
            continue
        products = [variation["product"] for variation in item.get("variations") or []]
        products = [product for product in products if (product.get("foodValue") or {}).get("calories")]
        name = re.sub(r"\s+", " ", item["name"]).strip()
        if section in PIZZA_SECTIONS:
            variants = [(diameter(product), dough(product), product) for product in products]
            for title, product in pizza_variants(name, variants):
                items.append(row(title, product, section, product["foodValue"]["weight"]))
            continue
        for product in products:
            drink = (product.get("traits") or {}).get("drink") or section in ("Кофе и чай", "Напитки")
            portion = product["foodValue"].get("weight") or (millilitres(product) if drink else None)
            if not portion:
                continue
            items.append(row(label(name, product, drink, products), product, section, portion))
    write_menu(
        "dodo-picca",
        "Додо Пицца",
        items,
        api_url or SITE,
        day,
        "Меню доставки Додо Пиццы для Москвы (dodopizza.ru/moscow), ответ API v5/menu: foodValue — КБЖУ на 100 г, "
        "weight — вес порции; значения пересчитаны на порцию. Состав — compositionDescription, аллергены — "
        "allergyAdvice.contains; общая приписка «могут содержаться следы…» не учитывается. Пропущены комбо, мерч, "
        "позиции без КБЖУ (соки и вода партнёров, приборы). Пиццы — только размеры до 25 см (порция на одного), с указанием теста. Напитки — каждый объём отдельной позицией.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
