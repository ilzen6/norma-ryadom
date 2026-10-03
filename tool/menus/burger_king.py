import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import write_menu

SOURCE = "https://s3.burgerkingrus.ru/default/0001/76/63751da2ff388af43630c54add8491b8f2df7568.pdf"
NUMBER = r"(\d+(?:[.,]\d+)?)"
ROW = re.compile(NUMBER + r"\s*(г|мл|шт\.?)\s+" + r"\s+".join([NUMBER] * 10))
NAME_WIDTH = 16
COMPOSITION = slice(16, 48)
NOISE = ("Наименование", "фирменного", "блюда")


def main():
    text = subprocess.run(["pdftotext", "-layout", sys.argv[1], "-"], capture_output=True, text=True, check=True).stdout
    lines = text.split("\n")
    starts = [index for index, line in enumerate(lines) if ROW.search(line)]
    items = []
    for position, start in enumerate(starts):
        end = starts[position + 1] if position + 1 < len(starts) else min(len(lines), start + 80)
        name_parts = []
        if not lines[start][:NAME_WIDTH].strip():
            above = [line[:NAME_WIDTH].strip() for line in lines[max(0, start - 3):start]]
            name_parts = [part for part in above if part and not any(word in part for word in NOISE)]
        for line in lines[start:min(end, start + 6)]:
            part = line[:NAME_WIDTH].strip()
            if not part or any(word in part for word in NOISE):
                break
            name_parts.append(part)
        composition = " ".join(line[COMPOSITION].strip() for line in lines[start:end])
        values = ROW.search(lines[start]).groups()
        unit = values[1]
        items.append({
            "name": " ".join(name_parts),
            "portion": values[0] if unit in ("г", "мл") else None,
            "kcal": values[2],
            "protein": values[6],
            "fat": values[8],
            "carbs": values[10],
            "ingredients": composition,
        })
    write_menu("burger-king", "Бургер Кинг", items, SOURCE, "2024-08-13",
               "Сведения об основных потребительских свойствах, приложение 1 к прейскуранту; значения на порцию")


main()
