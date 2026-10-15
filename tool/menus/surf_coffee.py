import html
import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import tags_of, write_menu

SOURCE_URL = "https://surfmenu.ru/"
NUMBER = r"(\d+(?:[.,]\d+)?)"
MACROS = re.compile(rf"Белки\s*{NUMBER}.*?Жиры\s*{NUMBER}.*?Углеводы\s*{NUMBER}", re.S | re.IGNORECASE)
ENERGY = re.compile(rf"Энергетическая ценность[^:]*:\s*{NUMBER}\s*ккал", re.IGNORECASE)
COMPOSITION = re.compile(r"Состав:\s*(.*?)(?:Аллергены:|$)", re.S | re.IGNORECASE)
ALLERGENS = re.compile(r"Аллергены:\s*(.*)$", re.S | re.IGNORECASE)
VOLUME = re.compile(r"(\d+)\s*мл", re.IGNORECASE)
MILK_DRINKS = re.compile(r"латте|капучино|раф|флэт|флет|какао|молоч|милкшейк", re.IGNORECASE)


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def number(text):
    return float(text.replace(",", "."))


def editions(product):
    raw = product.get("editions") or []
    found = []
    for edition in raw if isinstance(raw, list) else []:
        volume = VOLUME.search(" ".join(str(value) for value in edition.values()))
        if volume:
            found.append((int(volume.group(1)), edition.get("price")))
    if not found:
        volume = VOLUME.search(product.get("title") or "")
        if volume:
            found.append((int(volume.group(1)), product.get("price")))
    return sorted(set(found))


def items_of(product):
    name = plain(product.get("title"))
    text = plain(product.get("text"))
    macros, energy = MACROS.search(text), ENERGY.search(text)
    if not macros or not energy:
        return [{"name": name}]
    protein, fat, carbs = (number(value) for value in macros.groups())
    kcal = number(energy.group(1))
    composition = (COMPOSITION.search(text) or [None, ""])[1]
    allergens = (ALLERGENS.search(text) or [None, ""])[1]
    tags = set(tags_of(name, composition, allergens))
    if MILK_DRINKS.search(name) and "альтернатив" not in name.lower():
        tags.add("milk")
    result = []
    for volume, price in editions(product):
        factor = volume / 100
        result.append({
            "name": f"{VOLUME.sub('', name).strip(' ,')}, {volume} мл",
            "portion": volume,
            "price": price,
            "kcal": round(kcal * factor, 1),
            "protein": round(protein * factor, 1),
            "fat": round(fat * factor, 1),
            "carbs": round(carbs * factor, 1),
            "category": "drink",
            "tags": sorted(tags) or [""],
        })
    return result or [{"name": name}]


def main(folder):
    files = sorted(Path(folder).glob("tilda-store-*.json"))
    items = []
    for path in files:
        for product in json.loads(path.read_text(encoding="utf-8")).get("products") or []:
            items.extend(items_of(product))
    day = date.fromtimestamp(min(path.stat().st_mtime for path in files)).isoformat()
    write_menu(
        "surf-coffee",
        "Surf Coffee",
        items,
        SOURCE_URL,
        day,
        "Официальное онлайн-меню сети surfmenu.ru (Tilda Store, разделы напитков): «КБЖУ на 100 гр.» и «Энергетическая "
        "ценность на 100 г» из карточки, объёмы и цены — из вариантов товара; значения пересчитаны на объём порции "
        "(100 мл приняты за 100 г). Еды в онлайн-меню нет. Отметки исключений — по составу и аллергенам карточки, "
        "молочные напитки — с отметкой «молоко».",
    )


if __name__ == "__main__":
    main(sys.argv[1])
