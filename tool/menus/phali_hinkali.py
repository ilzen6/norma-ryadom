import html
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://dostavka.phali-hinkali.ru/menu/calorie"
SKIPPED_SECTIONS = ("nabor", "gotovim-doma")
MAX_PORTION = 600
SKIPPED_WORDS = re.compile(r"^(сет|набор|комбо)\b", re.IGNORECASE)
SECTION_DEFAULTS = {
    "deserty": "dessert",
    "garniry-hleb": "side",
    "goracie-zakuski": "side",
    "gruzinskie-limonady": "drink",
    "salaty": "salad",
    "vypecka": "side",
}
ROW = re.compile(
    r'<tr>\s*<td class="name"><a href="/menu/item/(\d+)">(.*?)</a></td>' + r"\s*<td>([^<]*)</td>" * 5, re.S
)
CARD = re.compile(r'data-id="(\d+)" data-name="[^"]*" data-price="(\d+(?:\.\d+)?)"')


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def amount(text):
    try:
        return float(text.strip().replace(",", "."))
    except ValueError:
        return None


def main(folder):
    folder = Path(folder)
    table = folder / "calorie.html"
    sections = {}
    for path in sorted(folder.glob("cat_*.html")):
        for dish_id, _ in CARD.findall(path.read_text(encoding="utf-8")):
            sections.setdefault(dish_id, path.stem.removeprefix("cat_"))
    prices = dict(CARD.findall((folder / "all.html").read_text(encoding="utf-8")))
    items = []
    for dish_id, raw_name, portion, kcal, fat, protein, carbs in ROW.findall(table.read_text(encoding="utf-8")):
        name = plain(raw_name)
        section = sections.get(dish_id, "")
        if section in SKIPPED_SECTIONS or SKIPPED_WORDS.search(name):
            continue
        if (amount(portion) or 0) > MAX_PORTION:
            continue
        items.append({
            "name": name,
            "portion": amount(portion) or None,
            "price": prices.get(dish_id),
            "kcal": amount(kcal),
            "protein": amount(protein),
            "fat": amount(fat),
            "carbs": amount(carbs),
            "category": food_category(name, SECTION_DEFAULTS.get(section, "main")),
            "tags": tags_of(name) or [""],
        })
    write_menu(
        "phalihinkali",
        "ПхалиХинкали",
        items,
        SOURCE_URL,
        date.fromtimestamp(table.stat().st_mtime).isoformat(),
        "Таблица «Калорийность блюд» сайта доставки dostavka.phali-hinkali.ru: выход порции, ккал, жиры, белки, "
        "углеводы на порцию. Цены — со страницы «Все блюда», раздел — со страниц категорий. Состава в таблице нет, "
        "отметки исключений — по названию блюда. Пропущены наборы, полуфабрикаты «Готовим дома» и порции больше 600 г (блюда на компанию, соки по литру).",
    )


if __name__ == "__main__":
    main(sys.argv[1])
