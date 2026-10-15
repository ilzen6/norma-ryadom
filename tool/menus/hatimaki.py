import html
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://hatimaki.ru/catalog/"
SKIPPED_WORDS = re.compile(r"^(сет|набор|комбо)\b", re.IGNORECASE)
MAX_PORTION = 600
SECTION_DEFAULTS = {
    "deserty": "dessert",
    "napitki": "drink",
    "salaty": "salad",
}
SECTION_HINTS = {"pizza": "пицца", "rolly": "ролл", "sushi": "ролл", "wok": "лапша"}
NAME = re.compile(r'<h1 class="title-h2">(.*?)</h1>', re.S)
NUMBER = r"(\d+(?:[.,]\d+)?)"
VALUES = {
    key: re.compile(rf'<div class="amount sizes-100">\s*{label}\s*{NUMBER}\s*</div>\s*<div class="amount sizes-all">\s*{label}\s*{NUMBER}')
    for key, label in (("protein", "Б"), ("fat", "Ж"), ("carbs", "У"), ("kcal", "кК"))
}
PRICE = re.compile(r'<div class="dish__price"\s+id="bx_\d+_\d+_price">\s*(\d[\d\s]*)')
DESCRIPTION = re.compile(r'itemprop="description">(.*?)</div>', re.S)


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def number(text):
    return float(text.replace(",", ".").replace(" ", ""))


def dish(page, section):
    name = plain((NAME.search(page) or [None, ""])[1])
    if not name or SKIPPED_WORDS.search(name):
        return None
    found = {key: pattern.search(page) for key, pattern in VALUES.items()}
    if None in found.values():
        return {"name": name}
    per_100 = {key: number(match.group(1)) for key, match in found.items()}
    total = {key: number(match.group(2)) for key, match in found.items()}
    if not per_100["kcal"]:
        return {"name": name}
    portion = round(100 * total["kcal"] / per_100["kcal"])
    if portion > MAX_PORTION:
        return None
    price = PRICE.search(page)
    composition = plain((DESCRIPTION.search(page) or [None, ""])[1])
    return {
        "name": name,
        "portion": portion,
        "price": price.group(1).replace(" ", "") if price else None,
        **total,
        "category": food_category(name, SECTION_DEFAULTS.get(section, "main")),
        "tags": tags_of(f"{name} {SECTION_HINTS.get(section, '')}", composition) or [""],
    }


def main(folder):
    files = sorted(Path(folder).glob("pages/*.html"))
    items = []
    for path in files:
        section = path.stem.split("_")[1]
        found = dish(path.read_text(encoding="utf-8"), section)
        if found:
            items.append(found)
    write_menu(
        "hatimaki",
        "Hatimaki",
        items,
        SOURCE_URL,
        date.fromtimestamp(min(path.stat().st_mtime for path in files)).isoformat(),
        "Карточки блюд сайта hatimaki.ru: «Б, Ж, У, кК» на 100 г и «Всего» на порцию; берутся значения «Всего», вес "
        "порции — отношение калорий порции к калориям на 100 г. Отметки исключений — по составу, названию и "
        "разделу. Пропущены сеты, ланчи, наборы и порции больше 600 г (пиццы целиком).",
    )


if __name__ == "__main__":
    main(sys.argv[1])
