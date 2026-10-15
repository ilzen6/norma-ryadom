import html
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://www.mealty.ru/"
WRAPPER = re.compile(r'<div class="category-wrapper[^"]*"[^>]*data-category-name="([^"]+)"')
CARD = re.compile(r'data-product_id="(\d+)"')
FIELD = re.compile(r'<div class="meal-card__([a-z_-]+)">(.*?)</div>', re.S)
CATEGORY_DEFAULTS = {
    "salad": "salad",
    "dessert": "dessert",
    "drink": "drink",
    "bread": "side",
    "snack": "side",
    "snaсk": "side",
}


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def number(text):
    return float(text.replace(",", ".").replace(" ", ""))


def cards(page):
    sections = [(match.start(), match.group(1)) for match in WRAPPER.finditer(page)]
    starts = [match for match in CARD.finditer(page)]
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(page)
        section = next((name for position, name in reversed(sections) if position < match.start()), "")
        fields = {key: plain(value) for key, value in FIELD.findall(page[match.start() : end])}
        yield match.group(1), section, fields


def main(path):
    path = Path(path)
    seen, items = set(), []
    for product_id, section, fields in cards(path.read_text(encoding="utf-8")):
        if product_id in seen or "proteins" not in fields:
            continue
        seen.add(product_id)
        name = " ".join(part for part in (fields.get("name"), fields.get("name-note")) if part)
        try:
            portion = number(fields["weight"])
            factor = portion / 100
            values = [number(fields[key]) * factor for key in ("calories", "proteins", "fats", "carbohydrates")]
        except (KeyError, ValueError):
            items.append({"name": name})
            continue
        kcal, protein, fat, carbs = (round(value, 1) for value in values)
        items.append({
            "name": name,
            "portion": portion,
            "price": fields.get("price"),
            "kcal": kcal,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "category": food_category(name, CATEGORY_DEFAULTS.get(section, "main")),
            "tags": tags_of(name, fields.get("products", "")) or [""],
        })
    write_menu(
        "milti",
        "Милти",
        items,
        SOURCE_URL,
        date.fromtimestamp(path.stat().st_mtime).isoformat(),
        "Меню сайта mealty.ru (Милти) для Москвы: белки, жиры, углеводы и калорийность в карточке — на 100 г, вес "
        "порции — «Вес, г» или «Объём, мл»; значения пересчитаны на порцию. Отметки исключений — по составу из "
        "карточки. Сайт сети — mealty.ru; ассортимент точек и доставки один.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
