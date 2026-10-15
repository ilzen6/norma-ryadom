import html
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://chaihona.ru/catalog"
SKIPPED_SECTIONS = ("fursetnye", "banketnye-bluda-zakaz-za-24-casa", "torty", "nabory", "sety", "kombo")
SKIPPED_WORDS = re.compile(r"^(сет|набор|комбо)\b", re.IGNORECASE)
MAX_PORTION = 600
SECTION_DEFAULTS = {
    "salaty": "salad",
    "zakuski": "side",
    "garniry": "side",
    "sousy": "sauce",
    "deserty": "dessert",
    "goracie-zakuski": "side",
    "napitki": "drink",
    "soki": "drink",
    "napitki-sobstvennogo-prigotovlenia": "drink",
    "vypecka": "side",
}
NAME = re.compile(r'<h1 itemProp="name"[^>]*>(.*?)</h1>', re.S)
SECTION = re.compile(r'itemProp="item" href="/catalog/([a-z0-9-]+)"')
DESCRIPTION = re.compile(r'<p class="[^"]*" itemProp="description">(.*?)</p>', re.S)
WEIGHT = re.compile(r"((?:\d+(?:[.,]\d+)?\s*/\s*)*\d+(?:[.,]\d+)?)\s*(гр|г|мл)\.?\s*$")
PRICE = re.compile(r'itemProp="price" content="(\d+(?:\.\d+)?)"')
NUMBER = r"(\d+(?:[.,]\d+)?)"
PER_100 = re.compile(
    rf'на 100гр</div>.*?>{NUMBER}</div><div class="text-sm lowercase">ккал'
    rf'.*?>{NUMBER}(?:<!-- -->|\s)*гр</div><div class="text-sm lowercase">белки'
    rf'.*?>{NUMBER}(?:<!-- -->|\s)*гр</div>\s*<div class="text-sm lowercase">жиры'
    rf'.*?>{NUMBER}(?:<!-- -->|\s)*гр</div><div class="text-sm lowercase">углеводы',
    re.S,
)


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<!-- -->|<[^>]+>", " ", raw or ""))).strip()


def number(text):
    return float(text.replace(",", "."))


def dish(page):
    name = plain((NAME.search(page) or [None, ""])[1])
    section = (SECTION.search(page) or [None, ""])[1]
    if not name or section in SKIPPED_SECTIONS or SKIPPED_WORDS.search(name):
        return None
    description = plain((DESCRIPTION.search(page) or [None, ""])[1])
    weight, values = WEIGHT.search(description), PER_100.search(page)
    if not weight or not values:
        return {"name": name}
    if "банкет" in description.lower():
        return None
    portion = sum(number(part) for part in weight.group(1).split("/"))
    if portion > MAX_PORTION:
        return None
    factor = portion / 100
    kcal, protein, fat, carbs = (round(number(value) * factor, 1) for value in values.groups())
    price = PRICE.search(page)
    return {
        "name": name,
        "portion": portion,
        "price": price.group(1) if price else None,
        "kcal": kcal,
        "protein": protein,
        "fat": fat,
        "carbs": carbs,
        "category": food_category(name, SECTION_DEFAULTS.get(section, "main")),
        "tags": tags_of(name, description) or [""],
    }


def main(folder):
    files = sorted(Path(folder).glob("pages/*.html"))
    items = [found for found in (dish(path.read_text(encoding="utf-8")) for path in files) if found]
    write_menu(
        "vasilchuki-chaihona-1",
        "Vasilchuki Chaihona №1",
        items,
        SOURCE_URL,
        date.fromtimestamp(min(path.stat().st_mtime for path in files)).isoformat(),
        "Страницы блюд меню доставки chaihona.ru (Москва): блок «на 100гр» — калорийность, белки, жиры, углеводы, "
        "вес порции — в конце описания (сумма компонентов вида «170/150/55 гр»), цена — из разметки товара; значения пересчитаны на порцию. Отметки "
        "исключений — по описанию состава. Пропущены фуршетные и банкетные блюда (в том числе с пометкой «банкет за 24 часа»), торты, сеты, порции и кувшины напитков больше 600 г.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
