import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://www.tokyo-city.ru/msk"
SKIPPED_CATEGORIES = ("Наборы", "Праздничные боксы")
MAX_PIZZA_GRAMS = 600
MAX_PERSONAL_PIZZA_CM = 25
DIAMETER = re.compile(r"(\d+)\s*см", re.IGNORECASE)
CATEGORY_DEFAULTS = {
    "Салаты": "salad",
    "Закуски и гарниры": "side",
    "Напитки": "drink",
    "Десерты": "dessert",
    "Соусы и приборы": "sauce",
}


def portion(food):
    try:
        weight = float(str(food.get("weight") or "").replace(",", "."))
    except ValueError:
        return None
    unit = (food.get("units") or "").strip().lower()
    if unit == "л":
        return weight * 1000
    return weight if unit in ("г", "мл") else None


def main(path):
    path = Path(path)
    foods = json.loads(path.read_text(encoding="utf-8"))
    items = []
    for food in foods:
        section = food.get("main_category") or ""
        if section in SKIPPED_CATEGORIES:
            continue
        grams = portion(food)
        name = re.sub(r"\s+", " ", food.get("name") or "").strip()
        diameter = DIAMETER.search(name)
        if section == "Пицца" and (
            (grams and grams > MAX_PIZZA_GRAMS) or (diameter and int(diameter.group(1)) > MAX_PERSONAL_PIZZA_CM)
        ):
            continue
        composition = re.sub(r"\s+", " ", food.get("composition") or "")
        items.append({
            "name": name,
            "portion": grams,
            "price": food.get("price"),
            "kcal": food.get("calories"),
            "protein": food.get("proteins"),
            "fat": food.get("fats"),
            "carbs": food.get("carbohydrates"),
            "category": food_category(name, CATEGORY_DEFAULTS.get(section, "main")),
            "tags": tags_of(name, composition) or [""],
        })
    write_menu(
        "tokio-siti",
        "Токио-Сити",
        items,
        SOURCE_URL,
        date.fromtimestamp(path.stat().st_mtime).isoformat(),
        "Карточки блюд сайта tokyo-city.ru для Москвы (данные Next.js, pageProps.food): calories/proteins/fats/"
        "carbohydrates — пищевая ценность на порцию («На порцию (N г)»), вес — weight/units. Отметки исключений — по "
        "составу; отдельного списка аллергенов сеть не публикует. Пропущены наборы, праздничные боксы и пиццы "
        "больше 25 см или тяжелее 600 г (не порция на одного).",
    )


if __name__ == "__main__":
    main(sys.argv[1])
