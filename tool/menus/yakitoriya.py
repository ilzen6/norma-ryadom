import html
import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://yakitoriya.ru/menu-dostavki/"
SKIPPED_SECTIONS = ("sety", "alfa-menyu", "sp-tubus", "bento-lanch")
SKIPPED_WORDS = re.compile(r"^(сет|набор|комбо|тубус)\b", re.IGNORECASE)
MAX_PIZZA_GRAMS = 600
SECTION_DEFAULTS = {
    "napitki": "drink",
    "deserty": "dessert",
    "salaty": "salad",
    "sousy": "sauce",
}
PRODUCT = re.compile(r'data-id="([^"]+)"\s+class="[^"]*catalog__item\b[^"]*"\s+data-product="([^"]*)"')
INFO = re.compile(r'<div class="catalog__item-info" data-id="([^"]+)">')
NAME = re.compile(r'<p class="catalog__item-info__h2">(.*?)</p>', re.S)
PRICE = re.compile(r'catalog__price-info[^"]*">\s*(\d+)')
DESCRIPTION = re.compile(r'<div class="catalog__desc-text">\s*<p>(.*?)</p>', re.S)
COMPOSITION = re.compile(r'<div class="catalog__composition-detail">(.*?)</div>', re.S)
NUMBER = r"(\d+(?:[.,]\d+)?)"
KCAL = re.compile(rf'nutrition__item">\s*{NUMBER}\s*kcal', re.IGNORECASE)
WEIGHT = re.compile(rf'nutrition__item">\s*{NUMBER}\s*(гр|г|мл)\.?\s*<', re.IGNORECASE)
MACROS = {
    key: re.compile(rf'nutrition__item">\s*{label}:\s*{NUMBER}', re.IGNORECASE)
    for key, label in (("protein", "Белки"), ("fat", "Жиры"), ("carbs", "Углеводы"))
}


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def number(match):
    return float(match.group(1).replace(",", ".")) if match else None


def blocks(page):
    sections = {}
    for slug, raw in PRODUCT.findall(page):
        product = json.loads(html.unescape(raw))
        sections.setdefault(slug, (product.get("section") or {}).get("url", ""))
    starts = list(INFO.finditer(page))
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(page)
        yield sections.get(match.group(1), ""), page[match.start() : end]


def dish(section, block):
    name = plain((NAME.search(block) or [None, ""])[1])
    if not name or SKIPPED_WORDS.search(name):
        return None
    kcal, weight = KCAL.search(block), WEIGHT.search(block)
    macros = {key: number(pattern.search(block)) for key, pattern in MACROS.items()}
    if not kcal or not weight or None in macros.values():
        return {"name": name}
    portion = number(weight)
    if section.endswith("pitstsa") and portion > MAX_PIZZA_GRAMS:
        return None
    price = PRICE.search(block)
    composition = " ".join(
        plain((pattern.search(block) or [None, ""])[1]) for pattern in (DESCRIPTION, COMPOSITION)
    ).replace("Состав:", " ")
    slug = section.rstrip("/").rsplit("/", 1)[-1]
    return {
        "name": name,
        "portion": portion,
        "price": price.group(1) if price else None,
        "kcal": number(kcal),
        **macros,
        "category": food_category(name, SECTION_DEFAULTS.get(slug, "main")),
        "tags": tags_of(name, composition) or [""],
    }


def main(folder):
    files = sorted(Path(folder).glob("cat_*.html"))
    seen, items = set(), []
    for path in files:
        if any(section in path.stem for section in SKIPPED_SECTIONS):
            continue
        for section, block in blocks(path.read_text(encoding="utf-8")):
            found = dish(section, block)
            if found and found["name"] not in seen:
                seen.add(found["name"])
                items.append(found)
    write_menu(
        "akitoria",
        "Якитория",
        items,
        SOURCE_URL,
        date.fromtimestamp(min(path.stat().st_mtime for path in files)).isoformat(),
        "Страницы разделов меню доставки yakitoriya.ru (Москва): в карточке каждого блюда — калорийность, вес и "
        "белки, жиры, углеводы на порцию, цена и состав. Отметки исключений — по составу; фразы «может содержать "
        "следы» не учитываются. Пропущены сеты, наборы, тубусы, бенто-ланчи и пиццы тяжелее 600 г.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
