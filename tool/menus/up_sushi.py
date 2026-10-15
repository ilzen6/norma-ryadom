import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, load_api_json, tags_of, write_menu

SOURCE_URL = "https://upsushi.ru/app-api/catalog?company=1&type_delivery=delivery&city=22&brand_id=1"
SKIPPED_CATEGORIES = ("Сеты", "Комбо")
CATEGORY_DEFAULTS = {"Закуски": "side", "Салаты": "salad", "Напитки": "drink", "Десерты": "dessert", "Соусы": "sauce"}
PORTION = re.compile(r"([\d+\s.,]+?)\s*(г|мл)\b", re.IGNORECASE)


def portion(weight):
    found = PORTION.search(weight or "")
    if not found:
        return None
    return sum(float(part.replace(",", ".")) for part in re.findall(r"\d+(?:[.,]\d+)?", found.group(1)))


def main(path):
    catalog, api_url, day = load_api_json(path, "/app-api/catalog")
    titles = {category["id"]: category["title"] for category in catalog["categories"]}
    items = []
    for product in catalog["products"]:
        sections = [titles.get(category_id, "") for category_id in product.get("categories_ids") or []]
        if any(section in SKIPPED_CATEGORIES for section in sections):
            continue
        section = next((section for section in sections if section != "Новинки"), "Новинки")
        name = re.sub(r"\s+", " ", product.get("name") or "").strip()
        info = product.get("info") or {}
        items.append({
            "name": name,
            "portion": portion(info.get("weight")),
            "price": product.get("price"),
            "kcal": info.get("calories"),
            "protein": info.get("proteins"),
            "fat": info.get("fats"),
            "carbs": info.get("carbohydrates"),
            "category": food_category(name, CATEGORY_DEFAULTS.get(section, "main")),
            "tags": tags_of(name, product.get("consist") or "") or [""],
        })
    write_menu(
        "up-sushi",
        "Up Sushi",
        items,
        api_url or SOURCE_URL,
        day,
        "Каталог сайта upsushi.ru для Москвы (city=22): calories/proteins/fats/carbohydrates в info — пищевая ценность "
        "на порцию, вес порции — из info.weight. Отметки исключений — по составу (consist); отдельного списка "
        "аллергенов сеть не публикует. Пропущены сеты и комбо.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
