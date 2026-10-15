import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import tags_of, write_menu

SOURCE_URL = "https://cinnabonrussia.com/Сведения о составе пищевой ценности меню кафе-пекарен Синнабон, июль 2026.pdf"
SOURCE_DATE = "2026-07-02"
NUMBER = r"(\d+(?:,\d+)?)"
NUTRITION = re.compile(
    r"(?:•\s*(?:([^•\d:.]{2,40}?)\s*:?\s*)?(?:(\d+)\s*мл\.?\s*)?)?Пищевая ценность 100 г продукта \(средние значения\):\s*"
    rf"Жиры:\s*{NUMBER}\s*Белки:\s*{NUMBER}\s*Углеводы:\s*{NUMBER}\s*"
    rf"Энергетическая\s+ценность\s*\(калорийность\),\s*кКал:?\s*{NUMBER}"
    r"(?:\s*Масса НЕТТО:\s*([\d/]+)\s*г)?"
)
SHARED_VOLUMES = re.compile(r"•\s*([\d/]+)\s*мл\.?\s*(?=•|$)")
SHARED_MASS = re.compile(r"•\s*([\d/]+)\s*гр?\.?\s*(?=•|$)")
SECTION_CATEGORIES = (("ВЫПЕЧКА", "dessert"), ("ДОБАВКИ", "sauce"), ("ПАНИНИ", "main"), ("", "drink"))


def number(text):
    return float(text.replace(",", "."))


def category(section):
    return next(value for key, value in SECTION_CATEGORIES if key in section)


def blocks(lines):
    section, name, body = "", None, []
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.isdigit():
            continue
        following = next((later.strip() for later in lines[index + 1 :] if later.strip()), "")
        if stripped.isupper() and not stripped.startswith("•") and len(stripped) > 3:
            if name:
                yield section, name, " ".join(body)
            section, name, body = stripped, None, []
        elif following.startswith("Состав:"):
            if name:
                yield section, name, " ".join(body)
            name, body = stripped, []
        elif stripped.startswith("Аллергены:"):
            break
        else:
            body.append(stripped)
    if name:
        yield section, name, " ".join(body)


def main(pdf):
    text = subprocess.run(["pdftotext", "-layout", pdf, "-"], capture_output=True, text=True, check=True).stdout
    items = []
    for section, name, body in blocks(text.splitlines()):
        composition = body.split("Пищевая ценность")[0].removeprefix("Состав:").strip()
        flat = re.sub(r"\s+", " ", body)
        shared = SHARED_VOLUMES.search(flat)
        shared_mass = SHARED_MASS.search(flat)
        found = list(NUTRITION.finditer(flat))
        for match in found:
            flavor, volume, fat, protein, carbs, kcal, mass = match.groups()
            if volume:
                portions, unit = [volume], "мл"
            elif mass:
                portions, unit = mass.split("/"), "г"
            elif shared:
                portions, unit = shared.group(1).split("/"), "мл"
            elif shared_mass:
                portions, unit = shared_mass.group(1).split("/"), "г"
            else:
                portions, unit = [None], ""
            base = f"{name}, {flavor.strip()}" if flavor else name
            several = len(portions) > 1 or (volume and len(found) > 1)
            for portion in portions:
                label = f"{base}, {portion} {unit}" if several and portion else base
                if not portion:
                    items.append({"name": label})
                    continue
                factor = float(portion) / 100
                items.append({
                    "name": label,
                    "portion": portion,
                    "kcal": round(number(kcal) * factor, 1),
                    "protein": round(number(protein) * factor, 1),
                    "fat": round(number(fat) * factor, 1),
                    "carbs": round(number(carbs) * factor, 1),
                    "category": category(section),
                    "tags": tags_of(label, composition) or [""],
                })
    write_menu(
        "cinnabon",
        "Cinnabon",
        items,
        SOURCE_URL,
        SOURCE_DATE,
        "«Сведения о составе и пищевой ценности меню кафе-пекарен Синнабон», июль 2026 (PDF на cinnabonrussia.com, "
        "раздел FAQ): пищевая ценность на 100 г, масса нетто выпечки и объём напитков 300/500 мл; значения "
        "пересчитаны на порцию. Отметки исключений — по составу каждой позиции; общая строка «могут содержать "
        "аллергены» не учитывается. Позиции без массы или объёма пропущены. Цен в документе нет.",
    )


if __name__ == "__main__":
    main(sys.argv[1])
