import csv
import json
import re
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "server/src/main/resources/demo/real"
META = Path(__file__).parent
HEADER = ["name", "category", "portion_g", "kcal", "protein_g", "fat_g", "carbs_g", "price_rub", "tags"]

CATEGORY_WORDS = [
    ("sauce", ["соус", "кетчуп", "майонез", "горчица", "дип ", "дип-", "топпинг", "сироп"]),
    ("dessert", ["мороженое", "сандэ", "санде", "айс твист", "рожок", "маффин", "чизкейк", "пирожок", "брауни"]),
    ("drink", ["кола", "cola", "пепси", "pepsi", "спрайт", "sprite", "фанта", "fanta", "сок", "чай", "кофе", "капучино",
               "латте", "американо", "эспрессо", "раф", "какао", "лимонад", "морс", "компот", "напиток", "вода",
               "коктейль", "шейк", "смузи", "флэт", "мокко", "кисель", "квас", "молоко", "фраппе", "матча",
               "энергетик", "тоник", "бамбл", "глинтвейн"]),
    ("dessert", ["мороженое", "пирожок", "пирожное", "торт", "чизкейк", "донат", "пончик", "маффин", "рожок", "сандэ",
                 "санде", "вафл", "десерт", "пай ", "брауни", "эклер", "печенье", "трубочка", "блинчик с вареньем",
                 "блин с вареньем", "блин со сгущ", "сырник", "штрудель", "тирамису", "панкейк", "макарон", "круассан",
                 "синнабон", "булочка с корицей", "мусс", "пудинг", "джем", "варенье"]),
    ("salad", ["салат", "цезарь"]),
    ("side", ["картофель", "фри", "кольца", "гарнир", "пюре", "рис ", "рис,", "овощи", "хлеб", "лаваш", "булочка",
              "кукуруза", "соленья", "огурц", "по-деревенски", "айдахо", "пельмени-закуска"]),
]

MEAT_WORDS = {
    "chicken": ["куриц", "курин", "чикен", "chicken", "наггетс", "стрипс", "крыл", "цыпл", "окорочк", "бедро", "филе кур",
                "твистер", "шефбургер", "байтс", "индейк"],
    "beef": ["говяд", "говяж", "воппер", "ангус", "биф", "beef", "телят", "стейк"],
    "pork": ["свин", "бекон", "ветчин", "карбонар", "пепперони", "буженин", "карбонад", "колбас", "сосиск", "хот-дог", "хот дог", "pork",
             "сарделька", "салями"],
    "fish": ["рыб", "фиш", "fish", "лосос", "семг", "сёмг", "тунец", "тунц", "форел", "треск", "минтай", "угор", "анчоус"],
    "seafood": ["креветк", "шримп", "кальмар", "мидии", "краб", "морепрод", "осьминог", "гребеш"],
}
ALLERGEN_WORDS = {
    "milk": ["молок", "молоч", "сливк", "сливоч", "сыр", "творог", "сметан", "йогурт", "кефир", "масло сливоч", "лактоз"],
    "gluten": ["пшенич", "мука", "глютен", "клейковин", "рожь", "ржан", "ячмен", "овсян", "булочк", "лаваш", "панировк",
               "сухари", "тортилья", "тесто"],
    "egg": ["яйц", "яичн", "желток", "белок яич", "меланж"],
    "nuts": ["орех", "миндал", "фундук", "кешью", "фисташ", "арахис", "пекан"],
    "soy": ["соев", "соя", "сои", "тофу", "эдамам"],
}
GENERIC_BEEF_DISHES = ["гамбургер", "чизбургер", "бургер"]
NAME_ALLERGENS = {
    "milk": ["сыр", "творог", "сливоч", "сливк", "молоч", "сметан", "йогурт", "латте", "капучино", "раф ", "пломбир",
             "мороженое", "карбонар", "киш", "чизкейк"],
    "gluten": ["блин", "вафл", "сэндвич", "сендвич", "бургер", "паста", "круассан", "булочк", "пицц", "хлеб", "тост",
               "маффин", "сырник", "торт", "пирог", "пирож", "киш", "ролл", "лаваш", "бриош", "панини", "багет", "кекс",
               "печень", "пончик", "донат", "в тесте", "штрудель", "тарталет", "эклер", "наггетс", "панировк", "лапш",
               "пельмен", "вареник", "чиабат", "фокачч", "брауни", "синнабон", "тортиль", "шаурм", "буррито", "гренк"],
    "egg": ["омлет", "яйц", "яичн", "скрэмбл", "глазунь", "бенедикт", "карбонар", "киш"],
}


def clean_name(raw):
    name = re.sub(r"\s+", " ", raw).strip()
    name = re.sub(r"(\w)-\s+(\w)", r"\1-\2", name)
    name = name.strip(" .,;")
    letters = [char for char in name if char.isalpha()]
    if letters and sum(char.isupper() for char in letters) / len(letters) > 0.7:
        name = name[:1].upper() + name[1:].lower()
    return name


def declared(text):
    text = (text or "").lower()
    text = re.sub(r"яйц\w*\s+кур\w*|кур\w*\s+яйц\w*|яичн\w*", " яйцо ", text)
    for marker in ("может содержать следы", "может содержать", "следы", "производится на предприятии",
                   "изготовлено на предприятии", "на производстве также"):
        index = text.find(marker)
        if index >= 0:
            text = text[:index]
    return text


def category_of(name, default="main"):
    lowered = f" {name.lower()} "
    for category, words in CATEGORY_WORDS:
        if any(word in lowered for word in words):
            return category
    return default


def tags_of(name, ingredients="", allergens=""):
    lowered = name.lower()
    composition = declared(ingredients)
    tags = set()
    for tag, words in MEAT_WORDS.items():
        if any(word in lowered or word in composition for word in words):
            tags.add(tag)
    if not tags & {"chicken", "pork", "fish", "seafood"} and any(word in lowered for word in GENERIC_BEEF_DISHES):
        tags.add("beef")
    for tag, words in NAME_ALLERGENS.items():
        if any(word in f"{lowered} " for word in words):
            tags.add(tag)
    allergen_text = declared(allergens)
    if any(word in allergen_text for word in ("ракообраз", "моллюск")):
        tags.add("seafood")
    if "рыб" in allergen_text:
        tags.add("fish")
    sources = composition + " " + allergen_text
    for tag, words in ALLERGEN_WORDS.items():
        if any(word in sources for word in words):
            tags.add(tag)
    if tags & {"pork", "beef", "chicken"}:
        tags.add("meat")
    return sorted(tags)


def number(value):
    if value is None:
        return None
    text = str(value).replace(" ", "").replace(" ", "").replace(",", ".").strip()
    try:
        return float(text)
    except ValueError:
        return None


def plausible(kcal, protein, fat, carbs):
    estimate = 4 * protein + 9 * fat + 4 * carbs
    return abs(estimate - kcal) <= max(40, 0.25 * max(kcal, estimate))


def fmt(value):
    if value is None:
        return ""
    rounded = round(value, 1)
    return str(int(rounded)) if rounded == int(rounded) else str(rounded)


def write_menu(slug, chain, items, source_url, source_date=None, notes=""):
    rows, skipped, names = [], [], set()
    for item in items:
        name = clean_name(item["name"])
        values = [number(item.get(key)) for key in ("kcal", "protein", "fat", "carbs")]
        if not name or any(value is None for value in values):
            skipped.append({"name": name, "reason": "нет полного КБЖУ"})
            continue
        kcal, protein, fat, carbs = values
        if not plausible(kcal, protein, fat, carbs):
            skipped.append({"name": name, "reason": f"калории не сходятся с БЖУ: {kcal} против {4 * protein + 9 * fat + 4 * carbs:.0f}"})
            continue
        key = name.lower()
        if key in names:
            continue
        names.add(key)
        rows.append({
            "name": name,
            "category": item.get("category") or category_of(name),
            "portion_g": fmt(number(item.get("portion"))),
            "kcal": fmt(kcal),
            "protein_g": fmt(protein),
            "fat_g": fmt(fat),
            "carbs_g": fmt(carbs),
            "price_rub": fmt(number(item.get("price"))),
            "tags": ",".join(item.get("tags") or tags_of(name, item.get("ingredients", ""), item.get("allergens", ""))),
        })
    OUT.mkdir(parents=True, exist_ok=True)
    with open(OUT / f"{slug}-menu.csv", "w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=HEADER, delimiter=";", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    meta = {
        "chain": chain,
        "source_url": source_url,
        "source_date": source_date,
        "fetched": date.today().isoformat(),
        "items": len(rows),
        "skipped": skipped,
        "notes": notes,
    }
    (META / f"{slug}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(chain, "items", len(rows), "skipped", len(skipped))
    return rows
