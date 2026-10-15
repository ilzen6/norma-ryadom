import html
import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://www.xleb.ru/catalog"
NUMBER = r"(\d+(?:[.,]\d+)?)"
NUTRITION = re.compile(
    rf"На 100 гр?:\s*Энерг\. ценность:\s*{NUMBER}\s*Белки:\s*{NUMBER}\s*Жиры:\s*{NUMBER}\s*Углеводы:\s*{NUMBER}",
    re.IGNORECASE,
)
WEIGHT = re.compile(r"(\d+(?:[.,]\d+)?)\s*(г|мл)\s*/\s*от\s*(\d+)\s*руб", re.IGNORECASE)
COMPOSITION = re.compile(r"Состав\s*:\s*(.*?)(?:Производится на предприятии|На 100 гр|$)", re.S | re.IGNORECASE)
SKIPPED_PARTS = ("Хлеб", "Торты", "Кофе")
PART_DEFAULTS = {
    "Холодные напитки": "drink",
    "Горячие напитки": "drink",
    "Слойка и выпечка": "side",
    "Пироги": "side",
    "Пирожные": "dessert",
    "Печенье": "dessert",
}


def plain(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))).strip()


def number(text):
    return float(text.replace(",", "."))


def main(folder):
    files = sorted(Path(folder).glob("store.tildaapi.com_getproductslist_slice*.json"))
    parts, products = {}, {}
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        parts.update({str(part["uid"]): part["title"] for part in data.get("parts") or []})
        products.update({product["uid"]: product for product in data.get("products") or []})
    items = []
    for product in products.values():
        sections = [parts.get(str(uid), "") for uid in json.loads(product.get("partuids") or "[]")]
        if any(section in SKIPPED_PARTS for section in sections):
            continue
        name = plain(product.get("title"))
        text = plain(product.get("text"))
        nutrition, weight = NUTRITION.search(text), WEIGHT.search(text)
        if not nutrition or not weight:
            items.append({"name": name})
            continue
        kcal, protein, fat, carbs = (number(value) for value in nutrition.groups())
        portion = number(weight.group(1))
        factor = portion / 100
        default = next((PART_DEFAULTS[section] for section in sections if section in PART_DEFAULTS), "main")
        composition = (COMPOSITION.search(text) or [None, ""])[1]
        items.append({
            "name": name,
            "portion": portion,
            "price": weight.group(3),
            "kcal": round(kcal * factor, 1),
            "protein": round(protein * factor, 1),
            "fat": round(fat * factor, 1),
            "carbs": round(carbs * factor, 1),
            "category": food_category(name, default),
            "tags": tags_of(name, composition) or [""],
        })
    write_menu(
        "hlebnik",
        "Хлебник",
        items,
        SOURCE_URL,
        date.fromtimestamp(min(path.stat().st_mtime for path in files)).isoformat(),
        "Каталог сайта сети xleb.ru (Tilda Store, единый для всех пекарен): «На 100 гр: Энерг. ценность, Белки, Жиры, "
        "Углеводы», вес и цена «от N руб.» из карточки; значения пересчитаны на порцию. Цены в пекарнях могут "
        "отличаться по регионам. Отметки исключений — по составу; фраза «производится на предприятии, где "
        "используются аллергены» не учитывается. Пропущены хлеб, торты целиком и кофе в зёрнах.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
