import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://zotmanpizza.ru/menu"
MAX_PIZZA_GRAMS = 600
MAX_DRINK_ML = 1000
SECTIONS = {
    "Римская пицца": "main",
    "Бруклинская пицца": "main",
    "Салаты": "salad",
    "Супы": "main",
    "Закуски": "side",
    "Сэндвичи и завтраки": "main",
    "Напитки": "drink",
    "Соусы": "sauce",
    "Десерты": "dessert",
}
WRAPPERS = ("Reactive", "ShallowReactive", "Ref", "ShallowRef", "EmptyRef")


def payload(page):
    match = re.search(r'<script[^>]*id="__NUXT_DATA__"[^>]*>(.*?)</script>', page, re.S)
    return json.loads(match.group(1))


def resolve(data, index, seen=frozenset()):
    if not isinstance(index, int) or index in seen:
        return index
    value, seen = data[index], seen | {index}
    if isinstance(value, dict):
        return {key: resolve(data, item, seen) for key, item in value.items()}
    if isinstance(value, list):
        if value and value[0] in WRAPPERS:
            return resolve(data, value[1], seen) if len(value) > 1 else None
        return [resolve(data, item, seen) for item in value]
    return value


def amount(value):
    try:
        return float(str(value).replace(",", "."))
    except ValueError:
        return None


def macros(product):
    kcal, protein, fat, carbs = (amount(product.get(key)) if product.get(key) is not None else None
                                 for key in ("calories", "proteins", "fats", "carbs"))
    if kcal is not None and carbs is not None and protein is None and fat is None and abs(kcal - 4 * carbs) <= 2:
        protein, fat = 0.0, 0.0
    return kcal, protein, fat, carbs


def main(path):
    path = Path(path)
    data = payload(path.read_text(encoding="utf-8"))
    sections = {}
    for index, value in enumerate(data):
        if isinstance(value, dict) and "slug" in value and "parentId" in value:
            section = resolve(data, index)
            if isinstance(section.get("name"), str):
                sections[section["id"]] = section["name"]
    items = []
    for index, value in enumerate(data):
        if not (isinstance(value, dict) and "calories" in value and "proteins" in value):
            continue
        product = resolve(data, index)
        section = sections.get(product.get("categoryId"))
        if section not in SECTIONS:
            continue
        name = re.sub(r"\s*\[[A-Z]+\]\s*", " ", product.get("name") or "").strip()
        portion = amount(product.get("weight"))
        if section.endswith("пицца") and portion and portion > MAX_PIZZA_GRAMS:
            continue
        if section == "Напитки" and portion and portion >= MAX_DRINK_ML:
            continue
        values = macros(product)
        if not portion or None in values:
            items.append({"name": name})
            continue
        factor = portion / 100
        kcal, protein, fat, carbs = (round(value * factor, 1) for value in values)
        description = re.sub(r"<[^>]+>", " ", product.get("description") or "")
        items.append({
            "name": name,
            "portion": portion,
            "price": product.get("price"),
            "kcal": kcal,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "category": food_category(name, SECTIONS[section]),
            "tags": tags_of(name, description) or [""],
        })
    write_menu(
        "zotman-pizza",
        "Zotman Pizza",
        items,
        SOURCE_URL,
        date.fromtimestamp(path.stat().st_mtime).isoformat(),
        "Меню сайта zotmanpizza.ru для Москвы (данные страницы Nuxt): calories, proteins, fats, carbs — на 100 г, "
        "как в описании блюд «На 100г К/Б/Ж/У», weight — вес порции; значения пересчитаны на порцию. У напитков "
        "без белков и жиров они считаются нулём, если калории сходятся с углеводами. Отметки исключений — по "
        "составу из описания. Пропущены комбо-наборы, компоненты конструктора, акционные разделы, доставка и напитки по литру.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
