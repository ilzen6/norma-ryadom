import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "app/assets/brand"
BRAND = (0x1B, 0x6A, 0x46, 255)
WHITE = (255, 255, 255, 255)
SCALE = 4
STROKE = 1.7


def bezier(start, first, second, end, steps=48):
    points = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        x = u ** 3 * start[0] + 3 * u * u * t * first[0] + 3 * u * t * t * second[0] + t ** 3 * end[0]
        y = u ** 3 * start[1] + 3 * u * u * t * first[1] + 3 * u * t * t * second[1] + t ** 3 * end[1]
        points.append((x, y))
    return points


def arc(center, radius, start_degrees, end_degrees, steps=72):
    import math

    return [
        (
            center[0] + radius * math.cos(math.radians(start_degrees + (end_degrees - start_degrees) * index / steps)),
            center[1] + radius * math.sin(math.radians(start_degrees + (end_degrees - start_degrees) * index / steps)),
        )
        for index in range(steps + 1)
    ]


def pin_outline():
    left = bezier((12, 21), (12, 21), (6, 15.8), (6, 11))
    top = arc((12, 11), 6, 180, 360)
    right = bezier((18, 11), (18, 15.8), (12, 21), (12, 21))
    return left + top[1:] + right[1:]


FORK = [((10, 8), (10, 11.5)), ((12, 8), (12, 14)), ((14, 8), (14, 11.5)), ((10, 11.5), (14, 11.5))]


def draw_mark(draw, origin, size, color):
    unit = size / 24

    def at(point):
        return origin[0] + point[0] * unit, origin[1] + point[1] * unit

    width = max(1, round(STROKE * unit))
    radius = width / 2
    outline = [at(point) for point in pin_outline()]
    draw.line(outline + [outline[0]], fill=color, width=width)
    for start, end in FORK:
        draw.line([at(start), at(end)], fill=color, width=width)
    for point in outline + [at(point) for segment in FORK for point in segment]:
        draw.ellipse([point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius], fill=color)


def render(size, background, mark_share, color=WHITE, corner=0.0):
    big = size * SCALE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if background is not None:
        draw.rounded_rectangle([0, 0, big - 1, big - 1], radius=round(big * corner), fill=background)
    mark = big * mark_share
    draw_mark(draw, ((big - mark) / 2, (big - mark) / 2), mark, color)
    return image.resize((size, size), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    render(1024, BRAND, 0.58).save(OUT / "icon.png")
    render(1024, None, 0.58).save(OUT / "icon-foreground.png")
    render(1024, BRAND, 0.58, corner=0.26).save(OUT / "icon-rounded.png")
    render(512, BRAND, 0.58).save(OUT / "icon-512.png")
    render(768, None, 0.50).save(OUT / "splash.png")
    print("готово:", ", ".join(sorted(path.name for path in OUT.glob("*.png"))), file=sys.stderr)


if __name__ == "__main__":
    main()
