import html
import re
import sys
import tarfile
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://prime-star.ru/menu/"
TITLE = re.compile(r'<h1 class="dish__title"[^>]*>(.*?)</h1>', re.S)
GRAMS = re.compile(r'<div class="dish__gram">\s*(\d+(?:[.,]\d+)?)\s*(?:г|мл)', re.S)
PRICE = re.compile(r'<div class="dish__price">\s*(\d+)', re.S)
PER_100 = re.compile(r'<div class="dish-part1 dish-part">(.*?)<div class="dish-part2', re.S)
VALUE = re.compile(r"<span>\s*([\d.,]+)\s*</span>\s*<br>\s*([а-яё]+)", re.S | re.IGNORECASE)
COMPOSITION = re.compile(r'<div class="dish__text[^"]*" itemprop="description">(.*?)</div>', re.S)
LABELS = (("ккал", "kcal"), ("бел", "protein"), ("жир", "fat"), ("угл", "carbs"), ("улев", "carbs"))
SECTION_DEFAULTS = (
    ("napitki", "drink"),
    ("deserty", "dessert"),
    ("salat", "salad"),
    ("garnir", "side"),
    ("vypechka", "side"),
    ("sous", "sauce"),
)


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def number(text):
    return float(text.replace(",", "."))


def dish(page, section):
    title, grams, block = TITLE.search(page), GRAMS.search(page), PER_100.search(page)
    if not title:
        return None
    name = plain(title.group(1))
    if not grams or not block:
        return {"name": name}
    values = {}
    for raw, label in VALUE.findall(block.group(1)):
        key = next((key for prefix, key in LABELS if label.lower().startswith(prefix)), None)
        if key:
            values[key] = number(raw)
    if len(values) < 4:
        return {"name": name}
    portion = number(grams.group(1))
    factor = portion / 100
    price = PRICE.search(page)
    composition = plain((COMPOSITION.search(page) or [None, ""])[1])
    default = next((value for key, value in SECTION_DEFAULTS if key in section), "main")
    return {
        "name": name,
        "portion": portion,
        "price": price.group(1) if price else None,
        **{key: round(value * factor, 1) for key, value in values.items()},
        "category": food_category(name, default),
        "tags": tags_of(name, composition) or [""],
    }


def main(archive):
    archive = Path(archive)
    items = []
    with tarfile.open(archive) as pages:
        for member in sorted(pages.getmembers(), key=lambda member: member.name):
            if not member.name.endswith(".html") or Path(member.name).name.startswith("._"):
                continue
            section = Path(member.name).stem.split("_")[1]
            found = dish(pages.extractfile(member).read().decode("utf-8"), section)
            if found:
                items.append(found)
    write_menu(
        "prime",
        "Prime",
        items,
        SOURCE_URL,
        date.fromtimestamp(archive.stat().st_mtime).isoformat(),
        "Карточки блюд сайта сети prime-star.ru (Москва): блок «На 100 грамм» — калорийность, белки, жиры, углеводы, "
        "вес и цена — из карточки; значения пересчитаны на порцию. Отметки исключений — по составу. Сайт "
        "предупреждает, что ассортимент зависит от дня доставки.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
