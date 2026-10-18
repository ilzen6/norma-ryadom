import html
import re
import subprocess
import sys
import tempfile
from pathlib import Path

STYLE = """
body { font-family: 'Times New Roman'; font-size: 14pt; line-height: 1.4; }
h1 { font-size: 20pt; text-align: center; }
h2 { font-size: 16pt; margin-top: 18pt; }
h3 { font-size: 14pt; }
p { text-align: justify; margin: 0 0 8pt 0; }
table { border-collapse: collapse; width: 100%; margin: 6pt 0 10pt 0; }
th, td { border: 1px solid #808080; padding: 3pt 5pt; font-size: 12pt; vertical-align: top; }
th { background: #e7e6e6; }
code { font-family: 'Consolas', 'Courier New'; font-size: 12pt; }
"""


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)


def cells(line):
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def convert(markdown):
    out, lines, index = [], markdown.splitlines(), 0
    while index < len(lines):
        line = lines[index]
        heading = re.match(r"^(#{1,3})\s+(.*)$", line)
        if heading:
            level = len(heading.group(1))
            out.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
        elif line.startswith("|"):
            rows = []
            while index < len(lines) and lines[index].startswith("|"):
                if not re.match(r"^\|[-| :]+\|$", lines[index].strip()):
                    rows.append(cells(lines[index]))
                index += 1
            head = "".join(f"<th>{inline(cell)}</th>" for cell in rows[0])
            body = "".join("<tr>" + "".join(f"<td>{inline(cell)}</td>" for cell in row) + "</tr>" for row in rows[1:])
            out.append(f"<table><tr>{head}</tr>{body}</table>")
            continue
        elif re.match(r"^\s*([-*]|\d+\.)\s+", line):
            ordered = bool(re.match(r"^\s*\d+\.", line))
            items = []
            while index < len(lines) and re.match(r"^\s*([-*]|\d+\.)\s+", lines[index]):
                items.append(re.sub(r"^\s*([-*]|\d+\.)\s+", "", lines[index]))
                index += 1
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{inline(item)}</li>" for item in items) + f"</{tag}>")
            continue
        elif line.strip():
            out.append(f"<p>{inline(line.strip())}</p>")
        index += 1
    return f'<html><head><meta charset="utf-8"><style>{STYLE}</style></head><body>{"".join(out)}</body></html>'


def main(source, target):
    page = convert(Path(source).read_text(encoding="utf-8"))
    with tempfile.NamedTemporaryFile("w", suffix=".html", encoding="utf-8", delete=False) as handle:
        handle.write(page)
    subprocess.run(["textutil", "-convert", "docx", "-output", target, handle.name], check=True)
    Path(handle.name).unlink()
    print(target)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
