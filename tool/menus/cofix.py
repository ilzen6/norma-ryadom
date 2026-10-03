import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import tags_of, write_menu

SOURCE_URL = "https://msk.cofix.global/"
SOURCE_DATE = "2026-10-03"
SKIPPED_GROUPS = ("мерч", "cofix at home")
SWEET_GROUPS = ("десерт", "дeceрт", "сладк")
PLAIN_DRINKS = re.compile(r"американо|эспрессо|^чай ", re.IGNORECASE)
FORMAT_SUFFIX = re.compile(r"\s+[smlx]{1,2}$", re.IGNORECASE)
SIZES = {"S", "M", "L", "XL"}
SWEET_WORDS = ("штрудель", "тарталетка", "миндальный")
MILK_DRINKS = re.compile(r"капучино|латте|раф|флэт|флат|мокко|какао|пломбир|молоч|сливоч|шейк|на молоке|фраппе", re.IGNORECASE)
PLANT_MILK = re.compile(r"альтернатив|кокосов\w* молок|овсян\w* молок|миндальн\w* молок", re.IGNORECASE)


def load(scratch):
    html = (Path(scratch) / "cofix-msk.html").read_text(encoding="utf-8")
    raw = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html, re.S).group(1)
    return json.loads(raw)["props"]


def base_name(raw):
    name = re.sub(r"\s+", " ", raw).strip()
    name = FORMAT_SUFFIX.sub("", name)
    return name[:1].upper() + name[1:]


def category(name, group, drink):
    lowered = name.lower()
    if drink:
        return "drink"
    if "салат" in lowered or "поке" in lowered:
        return "salad"
    if sweet(group) or any(word in lowered for word in SWEET_WORDS):
        return "dessert"
    return "main"


def sweet(group):
    return any(word in group.lower() for word in SWEET_GROUPS)


def tags(name, group, ingredients, allergen_names, drink):
    result = set(tags_of(name, ingredients, allergen_names))
    if drink and MILK_DRINKS.search(name) and not PLANT_MILK.search(name):
        result.add("milk")
    if "мортаделл" in name.lower():
        result |= {"pork", "meat"}
    if sweet(group):
        result -= {"pork", "beef", "chicken", "meat"}
    return sorted(result)


def main(scratch):
    props = load(scratch)
    nomenclature = props["nomenclatureJSON"]
    products = {product["id"]: product for product in nomenclature["products"]}
    allergens = {allergen["id"]: allergen["name"] for allergen in nomenclature["allergens"]}
    groups = {}
    order = {}
    for position, group in enumerate(nomenclature["categories"]):
        for product_id in group["product_ids"]:
            groups.setdefault(product_id, group["name"])
            order.setdefault(product_id, position)
    candidates = []
    for menu_item in props["menuJSON"]["menu_items"]:
        if menu_item["item_type"] != "product" or not menu_item.get("price"):
            continue
        product = products[menu_item["product_id"]]
        group = groups.get(product["id"], "")
        if any(word in group.lower() for word in SKIPPED_GROUPS):
            continue
        weight = product.get("weight") or 0
        if weight <= 0 or not product.get("energy"):
            continue
        size = (menu_item.get("menu_item_group") or {}).get("name")
        drink = product["measure_unit_type"] == "MILLILITER" or size in SIZES
        if drink and "bakery" in product["name"].lower():
            continue
        name = base_name(product["name"])
        macros = [product.get(key) or 0 for key in ("protein", "fat", "carbs")]
        if "на альтернативе молоку" in name.lower():
            continue
        if not any(macros) and not PLAIN_DRINKS.search(name):
            continue
        candidates.append((order.get(product["id"], 99), name, weight, drink, product, group, menu_item))
    candidates.sort(key=lambda candidate: (candidate[0], candidate[1], candidate[2]))
    weights = defaultdict(set)
    for _, name, weight, drink, *_ in candidates:
        if not drink:
            weights[name.lower()].add(weight)
    items = []
    for _, name, weight, drink, product, group, menu_item in candidates:
        if drink:
            label = f"{name}, {weight:g} мл"
        elif len(weights[name.lower()]) > 1:
            label = f"{name}, {weight:g} г"
        else:
            label = name
        factor = weight / 100
        ingredients = " ".join(filter(None, [product.get("description"), product.get("additional_info")]))
        allergen_names = ", ".join(allergens.get(allergen_id, "") for allergen_id in product.get("allergen_ids") or [])
        item_tags = tags(name, group, ingredients, allergen_names, drink)
        items.append({
            "name": label,
            "kcal": round(product["energy"] * factor, 1),
            "protein": round(product["protein"] * factor, 1),
            "fat": round(product["fat"] * factor, 1),
            "carbs": round(product["carbs"] * factor, 1),
            "portion": weight,
            "price": menu_item["price"],
            "category": category(name, group, drink),
            "tags": item_tags or [""],
        })
    write_menu(
        "cofix",
        "Cofix",
        items,
        SOURCE_URL,
        SOURCE_DATE,
        "Официальный сайт заказа Cofix для Москвы (встроен в https://cofix.global/ru-ru/menu/moscow/), данные __NEXT_DATA__ "
        "(nomenclatureJSON, menuJSON). Сайт показывает КБЖУ «на 100 г»; значения пересчитаны на порцию по весу/объёму "
        "позиции. Цены — московские цены сайта заказа. Пропущены позиции без цены, без веса, без КБЖУ, мерч и зерно, "
        "а также варианты «на альтернативе молоку» и «Альтернативный» с нулевыми БЖУ (значения скопированы с молочных "
        "версий или заглушки). Для напитков каждый объём — отдельная позиция. Классические напитки формата Cofix Bakery "
        "(с пометкой Bakery в названии) пропущены как дубли напитков основного меню; блюда Bakery сохранены.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
