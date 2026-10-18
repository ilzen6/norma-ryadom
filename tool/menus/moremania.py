import html
import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://moremania.info/menu"
SKIPPED_PARTS = ("Завтрак-конструктор",)
MAX_PORTION = 600
PART_DEFAULTS = {
    "Салаты": "salad",
    "Гарниры": "side",
    "Фритюр": "side",
    "Фреш/Смузи/Морсы": "drink",
    "Лимонады": "drink",
    "Кофе": "drink",
    "Чайная карта": "drink",
}
PART_HINTS = {"Суши": "ролл", "Роллы": "ролл", "Сашими": "рыба", "Паста": "паста", "Бургеры": "бургер", "Мидии": "мидии",
              "Пельмени/Вареники": "пельмени"}
NUTRITION = re.compile(
    r"ККАЛ\s*([\d.,]+)\s*\|?\s*Б\s*([\d.,]+)\s*\|?\s*Ж\s*([\d.,]+)\s*\|?\s*У\s*([\d.,]+)\s*\|?\s*(\d+(?:[.,]\d+)?)\s*(?:гр|г|мл)",
    re.IGNORECASE,
)
COMPOSITION = re.compile(r"Состав:\s*(.*?)(?:\|ККАЛ|$)", re.IGNORECASE)


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def number(text):
    return float(text.replace(",", "."))


def main(path):
    path = Path(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    parts = {str(part["uid"]): part["title"] for part in data.get("parts") or []}
    items = []
    for product in data.get("products") or []:
        sections = [parts.get(str(uid), "") for uid in product.get("partuids") or []]
        if any(section in SKIPPED_PARTS for section in sections):
            continue
        name = plain(product.get("title"))
        text = plain(f'{product.get("text") or ""} {product.get("descr") or ""}')
        found = NUTRITION.search(text)
        if not found:
            items.append({"name": name})
            continue
        kcal, protein, fat, carbs, portion = (number(value) for value in found.groups())
        if portion > MAX_PORTION:
            continue
        factor = portion / 100
        section = sections[0] if sections else ""
        composition = (COMPOSITION.search(text) or [None, ""])[1]
        items.append({
            "name": name,
            "portion": portion,
            "price": product.get("price"),
            "kcal": round(kcal * factor, 1),
            "protein": round(protein * factor, 1),
            "fat": round(fat * factor, 1),
            "carbs": round(carbs * factor, 1),
            "category": food_category(name, PART_DEFAULTS.get(section, "main")),
            "tags": tags_of(f"{name} {PART_HINTS.get(section, '')}", composition) or [""],
        })
    write_menu(
        "moremania",
        "Моремания",
        items,
        SOURCE_URL,
        date.fromtimestamp(path.stat().st_mtime).isoformat(),
        "Меню сайта moremania.info (Tilda Store, getproductslist): в описании блюда «ККАЛ | Б | Ж | У» и вес порции. "
        "Подписи «на 100 г» нет, но значения на 100 г видны по данным: поке весом 375 г с 134 ккал на всю порцию "
        "невозможно, один рис даёт больше; значения пересчитаны на вес порции. Отметки исключений — по составу из "
        "описания. Цены — базовые цены сайта, в центральных ресторанах часть позиций дороже. Пропущены "
        "завтрак-конструктор и порции больше 600 г.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
