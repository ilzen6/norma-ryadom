import argparse
import glob
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SHOTS = ROOT / "docs/screenshots"
NAME = "Норма рядом"

APP_SCREENS = {
    "01": "Онбординг — норма", "02": "Онбординг — предпочтения", "03": "Онбординг — геолокация и район",
    "04": "Главный экран", "05": "Подбор рядом", "06": "Набор", "07": "Замена блюда", "08": "Набор после замены",
    "09": "Дневник", "10": "Карта", "11": "Заведение — меню", "12": "Заведение — наборы",
    "13": "Фото меню отправлено", "14": "Профиль", "15": "Профиль — настройки",
}
MAP_SCREENS = [
    ("app-16-map-list-full", "1 Список заведений на весь экран"),
    ("app-dark-16-map-list-full", "2 Список заведений — тёмная тема"),
    ("app-17-district-picker", "3 Выбор района"),
    ("app-18-map-moscow-oblast", "4 Москва и область"),
    ("app-19-map-russia", "5 Карта России"),
]
ADMIN_SCREENS = {"01": "Обзор", "02": "Ошибки CSV", "03": "Сеть и меню", "04": "Модерация фото", "05": "Жалобы"}
DOCS = ["decisions", "architecture", "requirements-matrix", "testing", "menus", "demo", "install-phone"]

PRACTICAL_FIXES = {
    3: [(">Рисунок 3. <", ">Рисунок 4. <", 2)],
    6: [
        ("PersonViewModel.ktl<", "PersonViewModel.kt<", 1),
        (">PersonEditScren<", ">PersonEditScreen<", 1),
        ("Для закрепления навыках ", "Для закрепления навыков ", 1),
    ],
    7: [(f">Листинг {n} – Реализация <", f">Листинг {n + 1} – Реализация <", 1) for n in range(59, 52, -1) if n != 56]
    + [
        (">Листинг 56 – реализация <", ">Листинг 57 – Реализация <", 1),
        (">Листинг 52 – Реализация <", ">Листинг 53 – Реализация <", 2),
        (">@JsonProperty<", ">@Json<", 1),
    ],
}


def replace_nth(xml, old, new, nth):
    index = -1
    for _ in range(nth):
        index = xml.find(old, index + 1)
        if index < 0:
            return xml, False
    return xml[:index] + new + xml[index + len(old):], True


def fix_practical(source, target, number):
    fixes = PRACTICAL_FIXES.get(number)
    if not fixes:
        shutil.copyfile(source, target)
        return []
    with zipfile.ZipFile(source) as original:
        xml = original.read("word/document.xml").decode("utf-8")
        missing = []
        for old, new, nth in fixes:
            xml, done = replace_nth(xml, old, new, nth)
            if not done:
                missing.append(old.strip("<>"))
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as fixed:
            for item in original.infolist():
                data = xml.encode("utf-8") if item.filename == "word/document.xml" else original.read(item.filename)
                fixed.writestr(item, data)
    return missing


def practical_number(path):
    found = re.findall(r"(?<!\d)([2-8])(?!\d)", path.stem)
    return int(found[-1]) if found else None


def build(out_dir, practicals_dir):
    folder = out_dir / NAME
    if folder.exists():
        shutil.rmtree(folder)
    shots = folder / "2. Скриншоты"
    for sub in ["1. Описание проекта", "3. Практические работы", "4. Документация из репозитория"]:
        (folder / sub).mkdir(parents=True)
    for sub in ["Приложение — светлая тема", "Приложение — тёмная тема", "Карта и выбор района", "Админка"]:
        (shots / sub).mkdir(parents=True)
    shutil.copyfile(HERE / "readme.md", folder / "ПРОЧТИ МЕНЯ.md")
    description = folder / "1. Описание проекта"
    shutil.copyfile(ROOT / "docs/project-description.docx", description / f"Описание проекта «{NAME}».docx")
    shutil.copyfile(ROOT / "docs/project-description.md", description / f"Описание проекта «{NAME}».md")
    shutil.copytree(ROOT / "docs/description-images", description / "description-images")
    for number, title in APP_SCREENS.items():
        shutil.copyfile(glob.glob(f"{SHOTS}/app-{number}-*.png")[0], shots / "Приложение — светлая тема" / f"{number} {title}.png")
        shutil.copyfile(glob.glob(f"{SHOTS}/app-dark-{number}-*.png")[0], shots / "Приложение — тёмная тема" / f"{number} {title}.png")
    for source, title in MAP_SCREENS:
        shutil.copyfile(SHOTS / f"{source}.png", shots / "Карта и выбор района" / f"{title}.png")
    for number, title in ADMIN_SCREENS.items():
        shutil.copyfile(glob.glob(f"{SHOTS}/admin-{number}-*.png")[0], shots / "Админка" / f"{number} {title}.png")
    docs = folder / "4. Документация из репозитория"
    for name in DOCS:
        shutil.copyfile(ROOT / f"docs/{name}.md", docs / f"{name}.md")
    shutil.copyfile(ROOT / "README.md", docs / "README.md")
    practicals = folder / "3. Практические работы"
    shutil.copyfile(HERE / "practicals-notes.md", practicals / "Замечания по практическим.md")
    if practicals_dir:
        for source in sorted(Path(practicals_dir).glob("*.docx")):
            number = practical_number(source)
            if number is None:
                print("пропущен, нет номера работы:", source.name)
                continue
            missing = fix_practical(source, practicals / f"Практическая работа {number}.docx", number)
            print(f"работа {number}:", "исправления не найдены: " + ", ".join(missing) if missing else "готово")
    archive = shutil.make_archive(str(out_dir / f"{NAME} — архив для команды"), "zip", root_dir=out_dir, base_dir=NAME)
    print("архив:", archive)


def main():
    parser = argparse.ArgumentParser(description="Собирает архив для команды: описание, скриншоты, документацию и практические")
    parser.add_argument("--out", default=str(Path.home() / "Downloads"))
    parser.add_argument("--practicals", help="папка с исходными .docx практических 2–8")
    args = parser.parse_args()
    build(Path(args.out).expanduser(), args.practicals)


if __name__ == "__main__":
    main()
