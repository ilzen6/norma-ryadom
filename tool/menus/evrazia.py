import html
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://evrasia.spb.ru/calorie/"
SKIPPED_SECTIONS = ("Наборы", "Хлеб")
MAX_PORTION = 600
SECTION_DEFAULTS = {
    "Гарниры": "side",
    "Десерты": "dessert",
    "Закуски": "side",
    "Салаты": "salad",
}
SECTION = re.compile(r'<span class="section_name">([^<]+)</span>')
ROW = re.compile(r'<tr data-id="\d+"[^>]*>(.*?)</tr>', re.S)
CELL = re.compile(r"<td[^>]*>(.*?)</td>", re.S)
PRODUCT = re.compile(
    r'<meta itemprop="name" content="([^"]*)" />.*?<meta itemprop="description" content="([^"]*)" />'
    r'.*?<meta itemprop="price" content="(\d+(?:\.\d+)?)">',
    re.S,
)


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def amount(text):
    try:
        return float(text.replace(",", "."))
    except ValueError:
        return None


def key(name):
    name = re.sub(r",\s*состав\b|\bдм\b|\bnew\b|детское меню", " ", name.lower().replace("ё", "е"))
    return re.sub(r"\s+", " ", name).strip(" ,")


def products(folder):
    found = {}
    for page in sorted(folder.glob("menu_*.html")):
        for name, description, price in PRODUCT.findall(page.read_text(encoding="utf-8")):
            found.setdefault(key(html.unescape(name)), (html.unescape(description), price))
    return found


def main(path):
    path = Path(path)
    menu = products(path.parent)
    parts = SECTION.split(path.read_text(encoding="utf-8"))
    items, seen = [], set()
    for index in range(1, len(parts), 2):
        section, body = parts[index].strip(), parts[index + 1]
        if section in SKIPPED_SECTIONS or section.startswith("Ланч"):
            continue
        for row in ROW.findall(body):
            cells = [plain(cell) for cell in CELL.findall(row)]
            if len(cells) < 6:
                continue
            name, _, portion, protein, fat, carbs, kcal = (cells + [""])[:7]
            portion = amount(portion)
            if name in seen or (portion and portion > MAX_PORTION):
                continue
            seen.add(name)
            composition, price = menu.get(key(name), ("", None))
            items.append({
                "name": name,
                "portion": portion,
                "price": price,
                "kcal": amount(kcal),
                "protein": amount(protein),
                "fat": amount(fat),
                "carbs": amount(carbs),
                "category": food_category(name, SECTION_DEFAULTS.get(section, "main")),
                "tags": tags_of(name, composition) or [""],
            })
    write_menu(
        "evrazia",
        "Евразия",
        items,
        SOURCE_URL,
        date.fromtimestamp(path.stat().st_mtime).isoformat(),
        "Таблица «Калорийность» сайта сети evrasia.spb.ru (Санкт-Петербург): порция в граммах, белки, жиры, "
        "углеводы и ккал на порцию по разделам меню. Состав и цена — из страниц меню сайта (разметка schema.org), "
        "сопоставлены по названию; отметки исключений — по составу и названию. Пропущены наборы, хлеб, ланчи дня и порции больше 600 г.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
