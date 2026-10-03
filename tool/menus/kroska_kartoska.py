import html
import re
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import declared, tags_of, write_menu

SOURCE_URL = "https://www.kartoshka.com/menu/"
SOURCE_DATE = "2026-10-03"
SECTIONS = {
    "gril-chiz": "main",
    "kroshka-kartoshka": "main",
    "napolniteli": "side",
    "salaty": "salad",
    "supy-i-goriachie-bliuda": "main",
    "zakuski": "side",
    "sendvichi-i-rolly": "main",
    "deserty-i-napitki": "dessert",
    "sezonnoe-meniu": None,
}
DRINK_WORDS = ["морс", "чай", "кофе", "сок", "квас", "пиво", "пивной", "напиток", "кола", "bonaaqua", "добрый"]
SIDE_WORDS = ["мэш"]
ALLERGEN_EXTRA = {"soy": ["сои", "соя", "соев"], "seafood": ["ракообразн", "моллюск"], "fish": ["рыб"]}
NOTES = (
    "Официальное меню kartoshka.com/menu: КБЖУ указано на 100 г, пересчитано на порцию по весу с сайта. "
    "Для напитков вес указан в мл, принят равным граммам. Цен на сайте нет. "
    "Пропущены позиции без КБЖУ (большинство напитков) и наполнитель «Красная рыбка» с двумя вариантами КБЖУ. "
    "Наполнители отнесены к гарнирам (side), супы и сэндвичи — к основным блюдам."
)


def load(argv):
    if len(argv) > 1:
        return Path(argv[1]).read_text(encoding="utf-8")
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8")


def text_of(fragment):
    plain = re.sub(r"<[^>]+>", " ", fragment)
    return re.sub(r"\s+", " ", html.unescape(plain)).strip()


def decimal(text):
    match = re.search(r"\d+(?:[.,]\d+)?", text or "")
    return float(match.group(0).replace(",", ".")) if match else None


def nice_name(raw):
    name = text_of(raw)
    name = re.sub(r'"([^"]+)"', r"«\1»", name)
    return re.sub(r"\s+", " ", name).strip()


def category(section, name):
    lowered = name.lower()
    if any(word in lowered for word in DRINK_WORDS):
        return "drink"
    if any(word in lowered for word in SIDE_WORDS):
        return "side"
    if lowered.startswith("наполнитель"):
        return "side"
    if lowered.startswith("суп") or lowered == "борщ" or lowered.startswith("гриль чиз"):
        return "main"
    if lowered.startswith("пирожное") or lowered.startswith("чизкейк"):
        return "dessert"
    return SECTIONS.get(section) or "main"


def without_traces(text):
    text = re.sub(r"(может содержать следы|может содержать)[^,;)]*", "", text or "", flags=re.I)
    text = re.sub(r"(яйц\w*|меланж\w*|белк\w*)\s+курин\w*", r"\1", text, flags=re.I)
    return re.sub(r"курин\w*\s+(яиц|яйц)", r"\1", text, flags=re.I)


def declared_allergens(text):
    return re.split(r"продукт производится|производится на предприятии", text or "", flags=re.I)[0]


def tags(name, ingredients, allergens):
    allergens = declared_allergens(allergens)
    found = set(tags_of(name, without_traces(ingredients) or name, allergens))
    lowered = declared(allergens)
    for tag, words in ALLERGEN_EXTRA.items():
        if any(word in lowered for word in words):
            found.add(tag)
    return sorted(found)


def parse_product(section, body):
    name_match = re.search(r'class="product__name">(.*?)</h3>', body, re.S)
    info_match = re.search(r'class="product__info">(.*)', body, re.S)
    if not name_match or not info_match:
        return None
    name = nice_name(name_match.group(1))
    info = info_match.group(1)
    if "product__protein" not in info:
        return {"name": name, "missing": True}
    texts = [text_of(value) for value in re.findall(r'<p class="product__text">(.*?)</p>', info, re.S)]
    weight_texts = [value for value in texts if re.fullmatch(r"\d+(?:[.,]\d+)?\s*(г|мл)\.?", value)]
    kcal_texts = [value for value in texts if value not in weight_texts]
    nutrients = {
        key: text_of(value)
        for key, value in re.findall(r'class="product__(protein|fats|carbs)">(.*?)</li>', info, re.S)
    }
    joined = " ".join(list(nutrients.values()) + kcal_texts)
    if not weight_texts or not kcal_texts or "*" in joined:
        return {"name": name, "missing": True}
    portion = decimal(weight_texts[0])
    per100 = {
        "kcal": decimal(kcal_texts[-1]),
        "protein": decimal(nutrients.get("protein", "").split("-", 1)[-1]),
        "fat": decimal(nutrients.get("fats", "").split("-", 1)[-1]),
        "carbs": decimal(nutrients.get("carbs", "").split("-", 1)[-1]),
    }
    if any(value is None for value in per100.values()) or not portion:
        return {"name": name, "missing": True}
    description = re.search(r'class="product__description">\s*<p class="product__text">(.*?)</p>', body, re.S)
    composition = text_of(description.group(1)) if description else ""
    composition = re.sub(r"^Состав:\s*", "", composition)
    ingredients, _, allergens = composition.partition("Аллергены:")
    item = {
        "name": name,
        "portion": portion,
        "category": category(section, name),
        "ingredients": ingredients.strip(),
        "allergens": allergens.strip(),
    }
    for key, value in per100.items():
        item[key] = round(value * portion / 100, 1)
    item["tags"] = tags(name, item["ingredients"], item["allergens"])
    return item


def products(page):
    marks = [(match.start(), match.group(1)) for match in re.finditer(r'data-product="([^"]+)"', page)]
    found = []
    for index, (start, section) in enumerate(marks):
        if section not in SECTIONS:
            continue
        end = marks[index + 1][0] if index + 1 < len(marks) else len(page)
        chunk = page[start:end]
        for body in re.split(r'class="product__body">', chunk)[1:]:
            found.append((section, body.split('class="product__item', 1)[0]))
    order = list(SECTIONS)
    found.sort(key=lambda pair: order.index(pair[0]))
    return found


def main():
    page = load(sys.argv)
    items, seen, missing = [], set(), []
    for section, body in products(page):
        item = parse_product(section, body)
        if not item:
            continue
        key = item["name"].lower()
        if key in seen:
            continue
        seen.add(key)
        if item.get("missing"):
            missing.append(item["name"])
            continue
        items.append(item)
    notes = NOTES + " Без КБЖУ: " + ", ".join(missing) + "."
    write_menu("kroska-kartoska", "Крошка Картошка", items, SOURCE_URL, SOURCE_DATE, notes)


if __name__ == "__main__":
    main()
