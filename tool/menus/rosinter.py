import html
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

CHAINS = {
    "il-patio": ("IL Патио", "https://ilpatio.ru/"),
    "tgi-fridays": ("TGI Fridays", "https://tgifridays.ru/"),
}
SKIPPED_SECTIONS = ("nabory-na-kompaniyu", "obedy", "kombo", "nabory", "sety", "bar", "alkogol")
SKIPPED_WORDS = re.compile(r"^(сет|набор|комбо)\b", re.IGNORECASE)
MAX_PORTION = 600
SECTION_DEFAULTS = {
    "deserty": "dessert",
    "garniry-i-sousy": "side",
    "garniry": "side",
    "sousy": "sauce",
    "napitki": "drink",
    "salaty": "salad",
    "zakuski": "side",
}
SECTION_HINTS = {"pitstsa": "пицца", "pasta": "паста", "burgery": "бургер"}
TITLE = re.compile(r'<h1 class="product__title">(.*?)</h1>', re.S)
FEATURES = re.compile(
    r'<div class="product__features" id="sku-(\d+)-features"[^>]*>\s*<div class="product__sku_weight">\s*'
    r'(\d+(?:[.,]\d+)?)\s*(?:г|мл)\s*</div>\s*<div class="product__sku_energy">(.*?)</div>',
    re.S,
)
ENERGY = re.compile(r"кКал:\s*(\d+(?:[.,]\d+)?).*?Б:\s*(\d+(?:[.,]\d+)?).*?Ж:\s*(\d+(?:[.,]\d+)?).*?У:\s*(\d+(?:[.,]\d+)?)", re.S)
PRICE = re.compile(r'id="sku-(\d+)" class="product__price"[^>]*>\s*Цена:\s*<strong>\s*([\d\s]+)')
SIZE = re.compile(r'<li[^>]*data-sku-id="(\d+)">\s*<a href="#sku-\d+">(.*?)</a>', re.S)
DESCRIPTION = re.compile(r'<div class="product__description" id="product-(\d+)-description"[^>]*>(.*?)</div>', re.S)


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def number(text):
    return float(text.replace(",", ".").replace(" ", ""))


def category_of(title, section):
    if section == "salaty-i-zakuski":
        return "salad" if title.lower().startswith("салат") else "side"
    return food_category(title, SECTION_DEFAULTS.get(section, "main"))


def dishes(page, section):
    title = re.sub(r"\s*\[[A-Z]+\]", "", plain((TITLE.search(page) or [None, ""])[1])).strip()
    if not title or SKIPPED_WORDS.search(title):
        return
    prices = {sku: value for sku, value in PRICE.findall(page)}
    sizes = {sku: plain(label) for sku, label in SIZE.findall(page)}
    descriptions = {sku: plain(text) for sku, text in DESCRIPTION.findall(page)}
    variants = FEATURES.findall(page)
    for sku, weight, energy in variants:
        name = f"{title} {sizes[sku]}" if len(variants) > 1 and sku in sizes else title
        values = ENERGY.search(energy)
        portion = number(weight)
        if portion > MAX_PORTION:
            continue
        if not values:
            yield {"name": name}
            continue
        kcal, protein, fat, carbs = (number(value) for value in values.groups())
        yield {
            "name": name,
            "portion": portion,
            "price": (prices.get(sku) or "").strip() or None,
            "kcal": kcal,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "category": category_of(title, section),
            "tags": tags_of(f"{title} {SECTION_HINTS.get(section, '')}", descriptions.get(sku, "")) or [""],
        }


def main(slug, folder):
    chain, source = CHAINS[slug]
    folder = Path(folder)
    sections = {}
    for line in (folder / "links.tsv").read_text(encoding="utf-8").splitlines():
        link, category = line.split("\t")
        sections[link.strip("/").split("/")[-1]] = category.strip("/").split("/")[-1]
    items = []
    for path in sorted(folder.glob("pages/*.html")):
        section = sections.get(path.stem, "")
        if section in SKIPPED_SECTIONS:
            continue
        items.extend(dishes(path.read_text(encoding="utf-8"), section))
    write_menu(
        slug,
        chain,
        items,
        source,
        date.fromtimestamp(min(path.stat().st_mtime for path in folder.glob("pages/*.html"))).isoformat(),
        f"Карточки блюд сайта {source} (Росинтер, Москва): у каждого варианта блюда — вес, «кКал», «Б», «Ж», «У» на "
        "порцию и цена. Варианты размера (например, пицца 28 и 40 см) — отдельные позиции; в каталог берутся порции "
        "до 600 г. Отметки исключений — по описанию, названию и разделу (пицца, паста, бургеры). Пропущены наборы на компанию, обеды и комбо.",
    )


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
