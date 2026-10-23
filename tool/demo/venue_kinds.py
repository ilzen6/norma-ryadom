import re
from collections import Counter

NAME_KINDS = [
    ("shawarma", r"шаурм|шаверм|шавух|донер|doner|кебаб|kebab|шаварм"),
    ("pizza", r"пицц|pizz"),
    ("sushi", r"суши|sushi|ролл|роллы|якитор|японск|самура|сакура|токио"),
    ("asian", r"\bвок\b|wok|лапш|рамен|ramen|\bфо\b|\bpho\b|азия|\basia|паназ|китай|china|вьет|viet|корей|korea|тайск|\bthai"),
    ("georgian", r"хинкал|хачапур|грузин|георг|сакартвел|тбилис|мцхет|батуми|кахет|мимино|генацвал"),
    ("central-asian", r"чайхан|чайхон|плов|лагман|самарканд|узбек|бухар|тандыр|навруз|ташкент|чайхана|халяль|halal"),
    ("blini", r"блин|crepe|креп"),
    ("bakery", r"пекарн|булочн|хлеб|выпечк|пирог|пирож|пончик|пышечн|кондитер|bakery|bake|донат|donut|круасс|штрудел|bread"),
    ("coffee", r"кофе|coffee|кофейн|espresso|эспрессо|капучин|cappuc|\bcafe\b.*coffee|латте|\bбарист|чайная|чайный"),
    ("burger", r"бургер|burger|гриль|grill|хот.?дог|hot.?dog|чикен|chicken|фастфуд|fast.?food|наггет|крылышк|картошк"),
    ("canteen", r"столов|кулинар|буфет|обед|ланч|lunch|домашн|советск|пельмен|вареник|чебурек"),
    ("italian", r"итальян|italia|траттор|trattor|остери|osteria|паста|pasta|\bmama\b|мама рома"),
    ("bar", r"\bбар\b|\bbar\b|паб|\bpub\b|пив|beer|крафт|craft|таверн|tavern|рюмочн|бирхаус|пиво"),
]
CUISINE_KINDS = {
    "coffee": {"coffee_shop", "coffee", "tea", "bubble_tea", "ice_cream", "frozen_yogurt", "juice"},
    "pizza": {"pizza"},
    "sushi": {"sushi", "japanese", "poke"},
    "asian": {"asian", "chinese", "vietnamese", "korean", "thai", "ramen", "noodle", "noodles", "wok", "panasian", "pan_asian",
              "indian", "dumpling"},
    "burger": {"burger", "chicken", "hot_dog", "sandwich", "sausage", "potato", "american", "fast_food", "fries", "wings",
               "fried_chicken", "friture"},
    "shawarma": {"kebab", "shawarma", "turkish", "doner", "arab", "lebanese", "middle_eastern", "falafel", "syrian"},
    "georgian": {"georgian", "caucasian", "armenian", "azerbaijani", "khinkali"},
    "central-asian": {"uzbek", "central_asian", "tajik", "kazakh", "uyghur", "plov", "kyrgyz", "dungan"},
    "italian": {"italian", "pasta"},
    "blini": {"crepe", "pancake", "blini"},
    "bakery": {"cake", "pie", "donut", "pastry", "bakery", "dessert", "cupcake", "waffle", "pretzel", "bagel"},
    "canteen": {"russian", "soviet", "regional_russian", "dumplings", "pelmeni", "ukrainian", "belarusian", "homemade"},
    "bar": {"beer", "pub", "craft_beer", "bar"},
}
AMENITY_KINDS = {
    "cafe": "cafe",
    "restaurant": "cafe",
    "food_court": "cafe",
    "fast_food": "burger",
    "bar": "bar",
    "pub": "bar",
    "shop": "ready-food",
}


def normalized(text):
    return (text or "").lower().replace("ё", "е")


def name_kind(name):
    key = normalized(name)
    return next((kind for kind, pattern in NAME_KINDS if re.search(pattern, key)), None)


def cuisine_kind(cuisine):
    for token in normalized(cuisine).replace(",", ";").split(";"):
        token = token.strip()
        for kind, tokens in CUISINE_KINDS.items():
            if token in tokens:
                return kind
    return None


def kind_of(place):
    if place.get("amenity") == "shop":
        return "ready-food"
    return name_kind(place.get("name")) or cuisine_kind(place.get("cuisine")) or AMENITY_KINDS.get(place.get("amenity"), "cafe")


def majority_kind(chain_name, places):
    by_name = name_kind(chain_name)
    if by_name:
        return by_name
    counts = Counter(kind_of(place) for place in places)
    return min(counts, key=lambda kind: (-counts[kind], kind))
