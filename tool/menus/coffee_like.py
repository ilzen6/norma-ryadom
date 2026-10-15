import html
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import tags_of, write_menu

SOURCE_URL = "https://coffee-like.com/menu/drinks"
TITLE = re.compile(r'<div class="drink-card__title">(.*?)</div>', re.S)
COMPOSITION = re.compile(r'<li class="list__item">\s*-?\s*(.*?)</li>', re.S)
TAB = re.compile(r'<a href="#(tab\d+)"><span>(.*?)</span></a>', re.S)
VALUES = re.compile(r'<span class="name">(.*?)</span><span class="data">(.*?)</span>', re.S)
FIELDS = {"Ккал": "kcal", "Белки, г": "protein", "Жиры, г": "fat", "Углеводы, г": "carbs"}
MILLILITRES = re.compile(r"(\d+)\s*мл")


def text(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw))).strip()


def tab_block(page, tab):
    start = page.find(f'id="{tab}"')
    end = page.find('class="tabs-content"', start + 1)
    return page[start : end if end > 0 else None]


def drinks(page):
    title = TITLE.search(page)
    if not title:
        return []
    name = text(title.group(1))
    composition = ", ".join(text(item) for item in COMPOSITION.findall(page))
    result = []
    for tab, size in TAB.findall(page):
        size = text(size)
        values = {FIELDS[text(key)]: text(value) for key, value in VALUES.findall(tab_block(page, tab)) if text(key) in FIELDS}
        volume = MILLILITRES.search(size)
        result.append({
            "name": f"{name}, {size}",
            "portion": volume.group(1) if volume else None,
            "category": "drink",
            "ingredients": composition,
            **values,
        })
    return result


def main(folder):
    pages = sorted(Path(folder).glob("drinks/*.html"))
    items = []
    for page in pages:
        for drink in drinks(page.read_text(encoding="utf-8")):
            drink["tags"] = tags_of(drink["name"], drink.pop("ingredients")) or [""]
            items.append(drink)
    day = date.fromtimestamp(min(page.stat().st_mtime for page in pages)).isoformat()
    write_menu(
        "coffee-like",
        "Coffee Like",
        items,
        SOURCE_URL,
        day,
        "Страницы напитков на coffee-like.com/menu/drinks (меню одно для всей сети): «Энергетическая и пищевая "
        "ценность» — на порцию для каждого размера S/M/L/XL. Объём в мл сеть указывает не у всех напитков, вес "
        "порции не указан. Еды и цен на сайте нет. Отметки исключений — по списку «Состав напитка».",
    )


if __name__ == "__main__":
    main(sys.argv[1])
