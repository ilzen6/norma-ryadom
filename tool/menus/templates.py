import csv
import json
import re
import statistics
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REAL = ROOT / "server/src/main/resources/demo/real"
OUT = ROOT / "server/src/main/resources/demo/templates"
DOC = ROOT / "docs/approximate-menus.md"
INDEX = Path(__file__).with_name("templates.json")
SOURCE_URL = "https://github.com/ilzen6/norma-ryadom/blob/main/docs/approximate-menus.md"
HEADER = ["name", "category", "portion_g", "kcal", "protein_g", "fat_g", "carbs_g", "price_rub", "tags", "kcal_low",
          "kcal_high"]
MIN_SPREAD = 0.15
TAG_SHARE = 0.5


def dish(name, category, include, exclude=None, portion=None, categories=None):
    return {"name": name, "category": category, "include": include, "exclude": exclude, "portion": portion,
            "categories": categories or {category}}


COFFEE = [
    dish("Капучино, около 300 мл", "drink", r"^капучино\b", r"айс|холодн|двойн|xl|тыкв|карамел|ванил|бельг|чуррос|тирамису|орех|кокос|банан|альтерн|миндал|овсян|растит|без лактоз|детск", (250, 400)),
    dish("Латте, около 400 мл", "drink", r"^латте\b", r"айс|холодн|тыкв|карамел|ванил|бельг|чуррос|орех|кокос|банан|альтерн|миндал|овсян|растит|без лактоз|матча|протеин|раф|пряный|медов|соленая|шоколад|мята|клубн|малин|вишн", (330, 450)),
    dish("Американо, около 300 мл", "drink", r"^американо\b", r"айс|холодн|тоник|молок|сливк|апельс", (250, 450)),
    dish("Чай чёрный или зелёный", "drink", r"^чай (черн|зелен)|^(черный|зеленый) чай", r"молок|латте|айс|холодн|ягод|облепих|имбир|фрукт|мят|бабл|смородин|манго|лимон|матча", (150, 600)),
    dish("Какао, около 300 мл", "drink", r"^какао\b", r"айс|холодн|альтерн|овсян|кокос|миндал|маршмел|тыкв|прян|карамел|солен|банан|ванил", (250, 400)),
    dish("Круассан классический", "dessert", r"^круассан классическ|^классический круассан|^круассан$|^круассан,|^круассан сливочн", None, (40, 120), {"dessert", "side", "main"}),
    dish("Круассан с ветчиной и сыром", "main", r"круассан.*ветчин", None, (80, 250), {"main", "dessert", "side"}),
    dish("Сэндвич с курицей", "main", r"^(сэндвич|сендвич|клаб).*(куриц|курин|цыпл)", r"сладк", (120, 300)),
    dish("Сырники со сметаной или вареньем", "dessert", r"сырник", r"детск|запеканк|пирожн|торт", (130, 280), {"dessert", "main"}),
    dish("Овсяная каша", "main", r"овсян.*каш|каша.*овсян", r"детск", (180, 350), {"main", "dessert", "side"}),
    dish("Чизкейк", "dessert", r"чизкейк", r"напит|латте|раф|коктейл|шейк|морож|фраппе", (80, 180)),
    dish("Маффин", "dessert", r"маффин|кекс", None, (60, 140)),
]

BAKERY = [
    dish("Круассан классический", "dessert", COFFEE[5]["include"], None, (40, 120), {"dessert", "side", "main"}),
    dish("Круассан с ветчиной и сыром", "main", r"круассан.*ветчин", None, (80, 250), {"main", "dessert", "side"}),
    dish("Булочка с корицей", "dessert", r"булочка с корицей|рулет с корицей|^классический ролл|^синнабон$|^ролл синнабон|^синнабон классическ", r"мини|напит|латте|раф|шейк|стикс", (70, 200), {"dessert", "side"}),
    dish("Пирожок с капустой", "side", r"(пирож|пирог).*капуст", None, (50, 200), {"side", "main", "dessert"}),
    dish("Пирог с курицей", "main", r"(пирог|пирож|слойк|курник).*(куриц|курин|цыпл)", r"торт", (60, 250), {"main", "side", "dessert"}),
    dish("Киш", "main", r"^киш\b", None, (100, 250), {"main", "side"}),
    dish("Слойка сладкая", "dessert", r"слойк|язычок|ушки", r"куриц|курин|ветчин|сыр|шпинат|грибы|капуст", (50, 150)),
    dish("Сэндвич с курицей", "main", COFFEE[7]["include"], r"сладк", (120, 300)),
    dish("Эклер", "dessert", r"эклер", None, (40, 120)),
    dish("Капучино, около 300 мл", "drink", COFFEE[0]["include"], COFFEE[0]["exclude"], (250, 400)),
    dish("Американо, около 300 мл", "drink", COFFEE[2]["include"], COFFEE[2]["exclude"], (250, 450)),
    dish("Чай чёрный или зелёный", "drink", COFFEE[3]["include"], COFFEE[3]["exclude"], (150, 600)),
]

PIZZA = [
    dish("Пицца Маргарита, небольшая", "main", r"маргарит", r"роллы|соус|напит|коктейл", (280, 450)),
    dish("Пицца Пепперони, небольшая", "main", r"^(пицца )?пепперони\b", r"ролл|сэндвич|панини|соус|чипс|закуск", (280, 450)),
    dish("Пицца Четыре сыра, небольшая", "main", r"(четыре|4) сыр", r"соус|паст|ролл", (250, 450)),
    dish("Пицца с ветчиной и грибами, небольшая", "main", r"(пицц|^ветчина).*(ветчин|грибы).*(гриб|ветчин)|^ветчина и грибы", r"соус|ролл|сэндвич|омлет", (280, 480)),
    dish("Салат Цезарь с курицей", "salad", r"цезар.*(куриц|курин|цыпл)|цезар(ь)?$", r"ролл|соус|пицц|сэндвич", (150, 350)),
    dish("Куриные крылья", "main", r"крыл", r"соус", (150, 400), {"main", "side"}),
    dish("Картофель фри", "side", r"(картофель )?фри\b", r"соус|сыр|кетчуп|бургер|комбо", (80, 200)),
    dish("Лимонад, около 400 мл", "drink", r"лимонад", r"айс|ролл", (300, 500)),
    dish("Морс, около 300 мл", "drink", r"морс", None, (200, 500)),
    dish("Чизкейк", "dessert", COFFEE[10]["include"], COFFEE[10]["exclude"], (80, 180)),
]

SUSHI = [
    dish("Ролл Филадельфия", "main", r"^филадельфия\b", r"тобико|темпур|запеч|мега|гранд|сет", (180, 280)),
    dish("Ролл Калифорния", "main", r"^калифорния\b", r"темпур|запеч|сет", (170, 280)),
    dish("Ролл с лососем", "main", r"^(ролл с лососем|сяке маки|маки с лососем|лосось маки|ролл лосось|сяке ролл)|^сяке\b", r"темпур|запеч", (80, 200)),
    dish("Ролл с огурцом", "main", r"(каппа|огур).*маки|маки.*огур|ролл с огурц", None, (80, 200)),
    dish("Суши с лососем, 2 шт.", "main", r"^(суши|нигири).*(лосос|сяке)|^сяке нигири|^сяке суши", r"запеч|ролл|сет|острый|гункан", (50, 120)),
    dish("Мисо-суп", "main", r"мисо", r"рамен|ролл", (200, 400), {"main", "side"}),
    dish("Суп Том ям", "main", r"том ям", r"ролл|паста|соус|лапша", (250, 450)),
    dish("Салат чука", "salad", r"чук", r"ролл|суш", (60, 200), {"salad", "side"}),
    dish("Лапша вок с курицей", "main", r"(лапш|удон|соба|вок|яки).*(куриц|курин|цыпл)", r"суп|рамен|салат|ролл", (250, 450)),
    dish("Чай чёрный или зелёный", "drink", COFFEE[3]["include"], COFFEE[3]["exclude"], (150, 600)),
]

ASIAN = [
    dish("Лапша вок с курицей", "main", SUSHI[8]["include"], SUSHI[8]["exclude"], (250, 450)),
    dish("Лапша удон с говядиной", "main", r"(лапш|удон|соба|вок|яки).*(говяд|говяж|биф)", r"суп|рамен|салат|ролл", (250, 450)),
    dish("Рис с курицей и овощами", "main", r"(рис|тяхан|плов).*(куриц|курин|цыпл)", r"ролл|суш|суп|салат|каша", (250, 450)),
    dish("Рамен", "main", r"рамен", r"салат|соус", (350, 650)),
    dish("Суп Том ям", "main", SUSHI[6]["include"], SUSHI[6]["exclude"], (250, 450)),
    dish("Мисо-суп", "main", SUSHI[5]["include"], SUSHI[5]["exclude"], (200, 400), {"main", "side"}),
    dish("Гёдза или дим-самы", "main", r"гедза|гёдза|гиоза|дим.?сам|баоцзы|бао\b", r"соус", (100, 300), {"main", "side"}),
    dish("Салат чука", "salad", SUSHI[7]["include"], SUSHI[7]["exclude"], (60, 200), {"salad", "side"}),
    dish("Ролл Филадельфия", "main", SUSHI[0]["include"], SUSHI[0]["exclude"], (180, 280)),
    dish("Чай чёрный или зелёный", "drink", COFFEE[3]["include"], COFFEE[3]["exclude"], (150, 600)),
]

BURGER = [
    dish("Чизбургер", "main", r"^чизбургер\b|^чизбургер$", r"пицц|ролл|двойн|дабл|острый|комбо|детск|мега|гранд|рваной", (100, 200)),
    dish("Бургер с говядиной", "main", r"^(гамбургер|бургер|воппер|биг|классический бургер|бургер классический)\b|бургер.*говяд", r"пицц|детск|комбо|двойн|дабл|джуниор|мини|куриц|рыб|креветк|веган|ролл", (150, 350)),
    dish("Бургер с курицей", "main", r"(бургер|чикенбургер|чикен бургер|шефбургер).*(куриц|курин|чикен|цыпл)|^чикенбургер|^чикен бургер|^шефбургер", r"пицц|детск|комбо|ролл", (120, 320)),
    dish("Ролл с курицей в лаваше", "main", r"(ролл|твистер|врап|wrap|буррито|шаурм).*(куриц|курин|чикен|цыпл)", r"суш|филадельф|калифорн|запеч|темпур|маки|пицц|пепперони|блин", (180, 350), {"main", "side"}),
    dish("Наггетсы, 6 шт.", "main", r"наггетс|байтс|стрипс", r"соус|детск|комбо|пицц", (80, 200), {"main", "side"}),
    dish("Картофель фри", "side", PIZZA[6]["include"], PIZZA[6]["exclude"], (80, 200)),
    dish("Картофель по-деревенски", "side", r"по-деревенски|по деревенски|айдахо", r"пицц|соус", (90, 220)),
    dish("Салат овощной", "salad", r"(салат).*(овощ|свеж|огур|помидор|томат)|^овощной", r"куриц|цезар|соус|креветк|лосос|тунец|говяд", (100, 300)),
    dish("Молочный коктейль, около 400 мл", "drink", r"(молочный )?коктейль|шейк", r"безалког|протеин|чай|кофе", (300, 500)),
    dish("Кола, около 500 мл", "drink", r"\bкола\b|cola|пепси", r"без сахара|zero|лайт|light|морож|сироп|смузи|колад|шоколад", (400, 600)),
    dish("Мороженое", "dessert", r"мороженое|сандэ|санде|^рожок|айс твист|^пломбир", r"коктейл|шейк|кофе|латте", (70, 200)),
]

SHAWARMA = [
    dish("Шаурма с курицей", "main", r"(шаурм|шаверм|донер|кебаб в лаваш|ролл).*(куриц|курин|цыпл)|^шаурма$", r"суш|филадельф|калифорн|запеч|темпур|маки|пицц|пепперони|блин|мини", (250, 450), {"main", "side"}),
    dish("Ролл с курицей в лаваше", "main", BURGER[3]["include"], BURGER[3]["exclude"], (180, 350), {"main", "side"}),
    dish("Люля-кебаб из говядины", "main", r"люля|кебаб", r"лаваш|соус|ролл|шаурм|пицц", (100, 300), {"main", "side"}),
    dish("Шашлык из курицы", "main", r"шашлык.*(куриц|курин|цыпл)|(куриц|курин|цыпл).*шашлык", None, (120, 300), {"main", "side"}),
    dish("Картофель фри", "side", PIZZA[6]["include"], PIZZA[6]["exclude"], (80, 200)),
    dish("Салат овощной", "salad", BURGER[7]["include"], BURGER[7]["exclude"], (100, 300)),
    dish("Лепёшка", "side", r"лепешк|лаваш$|^лаваш|пита\b", r"сыр|мяс|куриц|начин|зелен", (50, 200), {"side", "main"}),
    dish("Чай чёрный или зелёный", "drink", COFFEE[3]["include"], COFFEE[3]["exclude"], (150, 600)),
    dish("Кола, около 500 мл", "drink", BURGER[9]["include"], BURGER[9]["exclude"], (400, 600)),
]

GEORGIAN = [
    dish("Хинкали с говядиной и свининой, 4 шт.", "main", r"хинкали.*(говяд|свин|барани).*4", r"жарен|мини", (300, 450)),
    dish("Хинкали с сыром, 4 шт.", "main", r"хинкали.*сыр.*4|хинкали с сыром", r"жарен|мини|1 ?шт", (250, 450)),
    dish("Хачапури по-аджарски", "main", r"аджар", r"мини", (200, 450)),
    dish("Хачапури по-имеретински", "main", r"имерет|мегрел", r"мини", (200, 450), {"main", "side"}),
    dish("Шашлык из курицы", "main", SHAWARMA[3]["include"], SHAWARMA[3]["exclude"], (120, 300), {"main", "side"}),
    dish("Суп харчо", "main", r"харчо", None, (250, 450)),
    dish("Пхали ассорти", "side", r"пхали", r"хинкали", (100, 300), {"side", "salad", "main"}),
    dish("Салат из овощей с орехами", "salad", r"(салат).*(орех|грузин|по-грузин|овощ)", r"куриц|цезар|креветк|лосос|тунец|говяд", (150, 350)),
    dish("Лобио", "main", r"лобио", None, (150, 350), {"main", "side", "salad"}),
    dish("Морс, около 300 мл", "drink", PIZZA[8]["include"], None, (200, 500)),
    dish("Чай чёрный или зелёный", "drink", COFFEE[3]["include"], COFFEE[3]["exclude"], (150, 600)),
]

CENTRAL_ASIAN = [
    dish("Плов", "main", r"плов", r"ролл|салат", (200, 400)),
    dish("Лагман", "main", r"лагман", None, (300, 500)),
    dish("Шурпа", "main", r"шурп", None, (300, 500)),
    dish("Самса", "side", r"самс", None, (80, 250), {"side", "main", "dessert"}),
    dish("Шашлык из курицы", "main", SHAWARMA[3]["include"], SHAWARMA[3]["exclude"], (120, 300), {"main", "side"}),
    dish("Люля-кебаб из говядины", "main", SHAWARMA[2]["include"], SHAWARMA[2]["exclude"], (100, 300), {"main", "side"}),
    dish("Салат Ачичук из томатов", "salad", r"ачичук|шакароб|(салат).*(томат|помидор)", r"куриц|цезар|креветк|лосос|тунец|говяд|моцарел|буррат", (100, 300)),
    dish("Лепёшка", "side", SHAWARMA[6]["include"], SHAWARMA[6]["exclude"], (50, 200), {"side", "main"}),
    dish("Чай чёрный или зелёный", "drink", COFFEE[3]["include"], COFFEE[3]["exclude"], (150, 600)),
]

ITALIAN = [
    dish("Паста карбонара", "main", r"карбонар", r"пицц|ролл", (220, 400)),
    dish("Паста болоньезе", "main", r"болоньез", r"пицц|лазан|ролл", (220, 400)),
    dish("Паста с курицей и грибами", "main", r"(паста|феттучин|пенне|спагетти|тальятел).*(куриц|курин).*(гриб|сливоч)|(паста|феттучин|пенне).*(гриб).*(куриц)", r"пицц", (220, 400)),
    dish("Пицца Маргарита, небольшая", "main", PIZZA[0]["include"], PIZZA[0]["exclude"], (280, 450)),
    dish("Пицца Пепперони, небольшая", "main", PIZZA[1]["include"], PIZZA[1]["exclude"], (280, 450)),
    dish("Лазанья", "main", r"лазань", r"соус", (200, 400)),
    dish("Салат Цезарь с курицей", "salad", PIZZA[4]["include"], PIZZA[4]["exclude"], (150, 350)),
    dish("Минестроне или томатный суп", "main", r"минестроне|томатный суп|суп.*томат", None, (200, 400)),
    dish("Тирамису", "dessert", r"^(десерт )?тирамису", r"капучино|латте|раф|напит|эклер", (80, 200)),
    dish("Лимонад, около 400 мл", "drink", PIZZA[7]["include"], PIZZA[7]["exclude"], (300, 500)),
    dish("Капучино, около 300 мл", "drink", COFFEE[0]["include"], COFFEE[0]["exclude"], (250, 400)),
]

CANTEEN = [
    dish("Борщ со сметаной", "main", r"борщ", None, (250, 450)),
    dish("Суп куриный с лапшой", "main", r"(суп|бульон).*(куриц|курин|цыпл)|куриный суп|^лапша куриная", r"крем|сливоч|том ям|сыр", (250, 450)),
    dish("Котлета куриная", "main", r"котлет.*(куриц|курин|цыпл)|(куриц|курин).*котлет", r"бургер|сэндвич|пюре|гречк|рис|макарон|с гарнир", (70, 200)),
    dish("Котлета с картофельным пюре", "main", r"котлет.*пюре", r"рыб|морск|сельдер", (180, 400)),
    dish("Куриная грудка запечённая", "main", r"(грудк|филе).*(куриц|курин|цыпл)|(куриц|курин|цыпл).*(грудк|филе)", r"салат|сэндвич|бургер|ролл|суп|пюре|гречк|рис|паст|с гарнир|цезар|бутерброд|шаурм", (80, 200)),
    dish("Гречка с курицей или овощами", "main", r"^греч(к|а)\b|^гречка-", r"чай|греческ", (150, 400), {"main", "side"}),
    dish("Картофельное пюре", "side", r"пюре", r"суп|крем|котлет|куриц|говяд|десерт|фрукт|ягод|яблоч", (120, 250)),
    dish("Рис отварной", "side", r"^рис\b", r"молочн|каша|салат|куриц|говяд|с овощ", (120, 250)),
    dish("Салат Оливье", "salad", r"оливье|столичн", None, (100, 300)),
    dish("Винегрет", "salad", r"винегрет", None, (100, 300)),
    dish("Салат из свежих овощей", "salad", BURGER[7]["include"], BURGER[7]["exclude"], (100, 300)),
    dish("Сырники со сметаной", "dessert", COFFEE[8]["include"], COFFEE[8]["exclude"], (130, 280), {"dessert", "main"}),
    dish("Блины с творогом", "dessert", r"блин.*творог", None, (100, 300), {"dessert", "main"}),
    dish("Пельмени", "main", r"пельмен", r"жарен|суп|кет|лосос|рыб|креветк|краб", (180, 350)),
    dish("Морс, около 300 мл", "drink", PIZZA[8]["include"], None, (200, 500)),
    dish("Компот, около 300 мл", "drink", r"компот", None, (200, 500)),
]

BLINI = [
    dish("Блин с ветчиной и сыром", "main", r"блин.*ветчин", None, (80, 250), {"main", "dessert"}),
    dish("Блин с курицей и грибами", "main", r"блин.*(куриц|курин|цыпл)", None, (80, 250), {"main", "dessert"}),
    dish("Блин с творогом", "dessert", r"блин.*творог", None, (80, 300), {"dessert", "main"}),
    dish("Блин со сгущёнкой или вареньем", "dessert", r"блин.*(сгущ|варен|джем|ягод|мед|шокол|нутелл)", r"торт|пирожн", (60, 250), {"dessert", "main"}),
    dish("Блины со сметаной", "dessert", r"блин.*сметан", None, (100, 300), {"dessert", "main"}),
    dish("Борщ со сметаной", "main", CANTEEN[0]["include"], None, (250, 450)),
    dish("Салат Оливье", "salad", CANTEEN[8]["include"], None, (100, 300)),
    dish("Чай чёрный или зелёный", "drink", COFFEE[3]["include"], COFFEE[3]["exclude"], (150, 600)),
    dish("Морс, около 300 мл", "drink", PIZZA[8]["include"], None, (200, 500)),
]

CAFE = [
    dish("Салат Цезарь с курицей", "salad", PIZZA[4]["include"], PIZZA[4]["exclude"], (150, 350)),
    dish("Салат из свежих овощей", "salad", BURGER[7]["include"], BURGER[7]["exclude"], (100, 300)),
    dish("Борщ со сметаной", "main", CANTEEN[0]["include"], None, (250, 450)),
    dish("Суп куриный с лапшой", "main", CANTEEN[1]["include"], CANTEEN[1]["exclude"], (250, 450)),
    dish("Паста карбонара", "main", ITALIAN[0]["include"], ITALIAN[0]["exclude"], (220, 400)),
    dish("Паста с курицей и грибами", "main", ITALIAN[2]["include"], ITALIAN[2]["exclude"], (220, 400)),
    dish("Куриная грудка запечённая", "main", CANTEEN[4]["include"], CANTEEN[4]["exclude"], (80, 200)),
    dish("Котлета с картофельным пюре", "main", CANTEEN[3]["include"], CANTEEN[3]["exclude"], (180, 400)),
    dish("Картофельное пюре", "side", CANTEEN[6]["include"], CANTEEN[6]["exclude"], (120, 250)),
    dish("Картофель фри", "side", PIZZA[6]["include"], PIZZA[6]["exclude"], (80, 200)),
    dish("Рис отварной", "side", CANTEEN[7]["include"], CANTEEN[7]["exclude"], (120, 250)),
    dish("Сырники со сметаной", "dessert", COFFEE[8]["include"], COFFEE[8]["exclude"], (130, 280), {"dessert", "main"}),
    dish("Чизкейк", "dessert", COFFEE[10]["include"], COFFEE[10]["exclude"], (80, 180)),
    dish("Капучино, около 300 мл", "drink", COFFEE[0]["include"], COFFEE[0]["exclude"], (250, 400)),
    dish("Чай чёрный или зелёный", "drink", COFFEE[3]["include"], COFFEE[3]["exclude"], (150, 600)),
    dish("Морс, около 300 мл", "drink", PIZZA[8]["include"], None, (200, 500)),
]

BAR = [
    dish("Бургер с говядиной", "main", BURGER[1]["include"], BURGER[1]["exclude"], (150, 350)),
    dish("Куриные крылья", "main", PIZZA[5]["include"], PIZZA[5]["exclude"], (150, 400), {"main", "side"}),
    dish("Картофель фри", "side", PIZZA[6]["include"], PIZZA[6]["exclude"], (80, 200)),
    dish("Гренки чесночные", "side", r"гренк", r"салат|суп|цезар", (80, 250), {"side", "main"}),
    dish("Луковые кольца", "side", r"лук.*кольц|кольца", r"кальмар", (60, 200), {"side", "main"}),
    dish("Колбаски гриль", "main", r"колбаск|сосиск|купат", r"пицц|хот|ролл|в тесте", (100, 300), {"main", "side"}),
    dish("Салат Цезарь с курицей", "salad", PIZZA[4]["include"], PIZZA[4]["exclude"], (150, 350)),
    dish("Наггетсы, 6 шт.", "main", BURGER[4]["include"], BURGER[4]["exclude"], (80, 200), {"main", "side"}),
    dish("Лимонад, около 400 мл", "drink", PIZZA[7]["include"], PIZZA[7]["exclude"], (300, 500)),
    dish("Морс, около 300 мл", "drink", PIZZA[8]["include"], None, (200, 500)),
]

READY_FOOD = [
    dish("Сэндвич с курицей", "main", COFFEE[7]["include"], COFFEE[7]["exclude"], (120, 300)),
    dish("Салат Цезарь с курицей", "salad", PIZZA[4]["include"], PIZZA[4]["exclude"], (150, 350)),
    dish("Салат Оливье", "salad", CANTEEN[8]["include"], None, (100, 300)),
    dish("Куриная грудка запечённая", "main", CANTEEN[4]["include"], CANTEEN[4]["exclude"], (80, 200)),
    dish("Гречка с курицей или овощами", "main", CANTEEN[5]["include"], CANTEEN[5]["exclude"], (150, 400), {"main", "side"}),
    dish("Плов", "main", CENTRAL_ASIAN[0]["include"], CENTRAL_ASIAN[0]["exclude"], (200, 400)),
    dish("Сырники", "dessert", COFFEE[8]["include"], COFFEE[8]["exclude"], (130, 280), {"dessert", "main"}),
    dish("Овсяная каша", "main", COFFEE[9]["include"], COFFEE[9]["exclude"], (180, 350), {"main", "dessert", "side"}),
    dish("Блины с творогом", "dessert", CANTEEN[12]["include"], None, (100, 300), {"dessert", "main"}),
    dish("Морс, около 300 мл", "drink", PIZZA[8]["include"], None, (200, 500)),
]

OMELET = dish("Омлет", "main", r"^(классический )?омлет\b|^омлет$", r"куриц|курин|ветчин|бекон|лосос|индейк|сосиск|мяс|рыб|кревет", (90, 260))
CASSEROLE = dish("Творожная запеканка", "dessert", r"творожн.*запеканк|запеканка творожн|воздушная запеканка", r"мяс|куриц|рыб|картоф", (100, 260), {"main", "dessert"})
GREEK = dish("Греческий салат", "salad", r"^греческ(ий|ий салат)$|^салат греческ|^греческий салат", None, (150, 330))
CREAM_SOUP = dish("Крем-суп овощной или грибной", "main", r"крем-суп|суп-пюре", r"кревет|морепрод|лосос|рыб|куриц|курин|бекон|мяс|говяд", (220, 420), {"main", "side"})
YOGURT = dish("Йогурт с гранолой и ягодами", "dessert", r"йогурт.*(гранол|мюсли|ягод)|гранол", r"напит|смузи", (100, 300), {"main", "dessert"})
GRILLED_VEG = dish("Овощи гриль", "side", r"овощи (гриль|на гриле)|овощи-гриль|^гриль-овощи", None, (100, 300), {"side", "salad", "main"})
EDAMAME = dish("Эдамаме", "side", r"^эдамам", r"чили|соус", (80, 250), {"side", "main", "salad"})
AVOCADO_ROLL = dish("Ролл с авокадо", "main", r"(ролл|маки).*авокадо|авокадо.*(маки|ролл)", r"лосос|угор|краб|кревет|тунец|филадельф|калифорн|курин|куриц|рыб|сяке|унаги|тобико|масаго", (80, 260))
FALAFEL = dish("Фалафель", "main", r"фалафел", None, (100, 350), {"main", "side"})

COFFEE = COFFEE + [OMELET, YOGURT, CASSEROLE]
BAKERY = BAKERY + [OMELET, CASSEROLE, YOGURT]
CAFE = CAFE + [OMELET, GREEK, CREAM_SOUP, GRILLED_VEG, CASSEROLE, dish("Овсяная каша", "main", COFFEE[9]["include"], COFFEE[9]["exclude"], (180, 350), {"main", "dessert", "side"})]
CANTEEN = CANTEEN + [OMELET, CASSEROLE, CREAM_SOUP, dish("Овсяная каша", "main", COFFEE[9]["include"], COFFEE[9]["exclude"], (180, 350), {"main", "dessert", "side"})]
BLINI = BLINI + [OMELET, CASSEROLE]
READY_FOOD = READY_FOOD + [GREEK, CASSEROLE, YOGURT, OMELET]
ITALIAN = ITALIAN + [CREAM_SOUP, GRILLED_VEG]
GEORGIAN = GEORGIAN + [GRILLED_VEG]
CENTRAL_ASIAN = CENTRAL_ASIAN + [GRILLED_VEG]
SUSHI = SUSHI + [EDAMAME, AVOCADO_ROLL]
ASIAN = ASIAN + [EDAMAME, AVOCADO_ROLL]
SHAWARMA = SHAWARMA + [FALAFEL]
BAR = BAR + [GREEK, GRILLED_VEG]
PIZZA = PIZZA + [GREEK]
BURGER = BURGER + [GREEK]

TEMPLATES = [
    ("coffee", "Типичное меню кофейни", COFFEE),
    ("bakery", "Типичное меню пекарни", BAKERY),
    ("pizza", "Типичное меню пиццерии", PIZZA),
    ("sushi", "Типичное меню суши-бара", SUSHI),
    ("asian", "Типичное меню паназиатского кафе", ASIAN),
    ("burger", "Типичное меню бургерной и фастфуда", BURGER),
    ("shawarma", "Типичное меню шаурмичной", SHAWARMA),
    ("georgian", "Типичное меню грузинского кафе", GEORGIAN),
    ("central-asian", "Типичное меню чайханы", CENTRAL_ASIAN),
    ("italian", "Типичное меню итальянского ресторана", ITALIAN),
    ("canteen", "Типичное меню столовой", CANTEEN),
    ("blini", "Типичное меню блинной", BLINI),
    ("cafe", "Типичное меню кафе", CAFE),
    ("bar", "Типичное меню бара", BAR),
    ("ready-food", "Типичная готовая еда в магазине", READY_FOOD),
]


def normalized(text):
    return text.lower().replace("ё", "е")


def number(value):
    return float(value) if value else None


def official_dishes():
    names = {}
    for meta in sorted(Path(__file__).parent.glob("*.json")):
        text = meta.read_text(encoding="utf-8")
        match = re.search(r'"chain":\s*"([^"]+)"', text)
        if match:
            names[meta.stem] = match.group(1)
    rows = []
    for menu in sorted(REAL.glob("*-menu.csv")):
        slug = menu.name.removesuffix("-menu.csv")
        with open(menu, encoding="utf-8") as source:
            for row in csv.DictReader(source, delimiter=";"):
                rows.append({
                    "chain": names.get(slug, slug),
                    "name": row["name"],
                    "key": normalized(row["name"]),
                    "category": row["category"],
                    "portion": number(row["portion_g"]),
                    "nutrients": tuple(float(row[column]) for column in ("kcal", "protein_g", "fat_g", "carbs_g")),
                    "price": number(row["price_rub"]),
                    "tags": {tag for tag in row["tags"].split(",") if tag},
                })
    return rows


def candidates(spec, dishes):
    include = re.compile(spec["include"])
    exclude = re.compile(spec["exclude"]) if spec["exclude"] else None
    low, high = spec["portion"] or (0, float("inf"))
    found = [
        item for item in dishes
        if item["category"] in spec["categories"] and include.search(item["key"])
        and not (exclude and exclude.search(item["key"]))
        and (item["portion"] is None or low <= item["portion"] <= high)
        and item["nutrients"][0] > 0
    ]
    by_chain = Counter(item["chain"] for item in found)
    limit = max(3, len(found) // max(1, len(by_chain)))
    kept, seen = [], Counter()
    for item in sorted(found, key=lambda item: (item["chain"], item["name"])):
        if seen[item["chain"]] < limit:
            kept.append(item)
            seen[item["chain"]] += 1
    return kept


def medoid(found):
    medians = [statistics.median(item["nutrients"][index] for item in found) or 1.0 for index in range(4)]

    def spread(item):
        return sum(abs(item["nutrients"][index] - other["nutrients"][index]) / medians[index]
                   for other in found for index in range(4))

    return min(found, key=lambda item: (spread(item), item["chain"], item["name"]))


def quartiles(values):
    if len(values) < 4:
        return min(values), max(values)
    cuts = statistics.quantiles(values, n=4)
    return cuts[0], cuts[2]


def rounded(value):
    return f"{value:.1f}".rstrip("0").rstrip(".")


def template_dish(spec, found):
    chosen = medoid(found)
    kcal = chosen["nutrients"][0]
    low, high = quartiles([item["nutrients"][0] for item in found])
    low = min(low, kcal * (1 - MIN_SPREAD))
    high = max(high, kcal * (1 + MIN_SPREAD))
    prices = [item["price"] for item in found if item["price"]]
    tag_counts = Counter(tag for item in found for tag in item["tags"])
    tags = chosen["tags"] | {tag for tag, count in tag_counts.items() if count >= TAG_SHARE * len(found)}
    row = {
        "name": spec["name"],
        "category": spec["category"],
        "portion_g": rounded(chosen["portion"]) if chosen["portion"] else "",
        "kcal": rounded(kcal),
        "protein_g": rounded(chosen["nutrients"][1]),
        "fat_g": rounded(chosen["nutrients"][2]),
        "carbs_g": rounded(chosen["nutrients"][3]),
        "price_rub": str(round(statistics.median(prices) / 10) * 10) if prices else "",
        "tags": ",".join(sorted(tags)),
        "kcal_low": rounded(max(0.0, low)),
        "kcal_high": rounded(high),
    }
    sources = sorted({item["chain"] for item in found})
    return row, chosen, sources


def main():
    dishes = official_dishes()
    OUT.mkdir(parents=True, exist_ok=True)
    report = []
    problems = []
    for code, title, specs in TEMPLATES:
        rows = []
        report.append((code, title, []))
        for spec in specs:
            found = candidates(spec, dishes)
            if not found:
                problems.append(f"{code}: {spec['name']} — нет подходящих блюд")
                continue
            row, chosen, sources = template_dish(spec, found)
            rows.append(row)
            report[-1][2].append((row, chosen, sources, len(found)))
        with open(OUT / f"{code}-menu.csv", "w", encoding="utf-8", newline="") as output:
            writer = csv.DictWriter(output, fieldnames=HEADER, delimiter=";", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
    write_doc(report)
    INDEX.write_text(json.dumps([{"code": code, "name": title, "source_url": SOURCE_URL} for code, title, _ in TEMPLATES],
                                ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for code, title, entries in report:
        print(code, len(entries), file=sys.stderr)
        for row, chosen, sources, count in entries:
            print(f"  {row['name']}: {row['kcal']} ({row['kcal_low']}–{row['kcal_high']}) ← {chosen['chain']}: "
                  f"{chosen['name']} [{count} блюд, {len(sources)} сетей]", file=sys.stderr)
    for problem in problems:
        print("ПРОПУЩЕНО", problem, file=sys.stderr)


def write_doc(report):
    lines = [
        "# Типичные меню",
        "",
        "Для заведений без собственного меню приложение подбирает по типичному меню заведения такого вида: кофейни, "
        "пиццерии, столовой и т. д. Такие блюда помечены уровнем достоверности C («оценка») и показываются с диапазоном "
        "калорий.",
        "",
        "## Как получены значения",
        "",
        "- Вид заведения берётся из OpenStreetMap: `cuisine`, `amenity` и слова в названии (`tool/demo/build_real_venues.py`).",
        "  Для сети без официального меню вид выбирается по большинству её точек.",
        "- Для каждого типичного блюда собраны похожие позиции из официальных меню сетей (`tool/menus/templates.py`): по "
        "названию, категории и размеру порции, не больше равной доли от каждой сети.",
        "- КБЖУ, порция и теги — у медоиды: настоящего блюда, ближе всего к остальным по калориям, белкам, жирам и углеводам. "
        "Средние значения не используются, чтобы набор цифр всегда был согласованным.",
        "- Диапазон калорий — между первым и третьим квартилем похожих блюд, но не уже ±15 % от значения.",
        "- Тег добавляется, если он есть у медоиды или у половины похожих блюд: исключения по аллергенам и мясу работают с запасом.",
        "- Цена — медиана цен похожих блюд, округлённая до 10 ₽.",
        "",
        "Если в заведение загружено фото меню и модератор его одобрил, вместо типичного меню используется настоящее.",
        "",
        "Пересобрать: `python3 tool/menus/templates.py`.",
    ]
    for code, title, entries in report:
        lines += ["", f"## {title} (`{code}`)", "", "| Блюдо | ккал | Диапазон | Ближайшее официальное блюдо | Похожих блюд |",
                  "|---|---|---|---|---|"]
        for row, chosen, sources, count in entries:
            lines.append(f"| {row['name']} | {row['kcal']} | {row['kcal_low']}–{row['kcal_high']} | "
                         f"{chosen['chain']}: {chosen['name']} | {count} ({len(sources)} сет.) |")
    DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
