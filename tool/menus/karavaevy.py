import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import food_category, tags_of, write_menu

SOURCE_URL = "https://www.karavaevi.ru/menu/"
SKIPPED_GROUPS = ("Комбо Простоквашино", "Кофе в упаковке", "Фуршетное меню", "Торты", "Хлеб")
GROUP_DEFAULTS = {
    "Салаты": "salad",
    "Гарниры": "side",
    "Выпечка": "side",
    "Десерты": "dessert",
    "Снеки и сладости": "dessert",
    "Печенье": "dessert",
    "Горячие напитки": "drink",
}


def composition_of(details, position_id):
    path = details / f"{position_id}.json"
    if not path.exists():
        return ""
    data = json.loads(path.read_text(encoding="utf-8")).get("data") or {}
    return re.sub(r"\s+", " ", data.get("additionalInfo") or "").strip()


def main(folder):
    folder = Path(folder)
    listing = folder / "menu-list-vernadskogo80.json"
    menu = json.loads(listing.read_text(encoding="utf-8"))["data"]["menu"]
    details = folder / "details"
    items = []
    for group in menu:
        if group["name"] in SKIPPED_GROUPS:
            continue
        for position in group["positions"]:
            name = re.sub(r"\s+", " ", position["name"]).strip()
            weight = position.get("weight")
            values = [position.get(key) for key in ("energyAmount", "proteinsAmount", "fatAmount", "carbohydratesAmount")]
            if not weight or None in values or not values[0]:
                items.append({"name": name})
                continue
            factor = weight / 100
            kcal, protein, fat, carbs = (round(value * factor, 1) for value in values)
            items.append({
                "name": name,
                "portion": weight,
                "price": position.get("cost"),
                "kcal": kcal,
                "protein": protein,
                "fat": fat,
                "carbs": carbs,
                "category": food_category(name, GROUP_DEFAULTS.get(group["name"], "main")),
                "tags": tags_of(name, composition_of(details, position["id"])) or [""],
            })
    write_menu(
        "kulinarnaa-lavka-brat-ev-karavaevyh",
        "Кулинарная лавка братьев Караваевых",
        items,
        SOURCE_URL,
        date.fromtimestamp(listing.stat().st_mtime).isoformat(),
        "Меню сайта karavaevi.ru (то же API, что у приложения сети), кафе на пр. Вернадского, 80: energyAmount, "
        "proteinsAmount, fatAmount, carbohydratesAmount — пищевая ценность на 100 г, weight — вес порции; значения "
        "пересчитаны на порцию. Состав — из карточки позиции (additionalInfo). Пропущены комбо, кофе в упаковке, "
        "фуршетное меню, торты целиком и хлеб, а также позиции без КБЖУ.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
