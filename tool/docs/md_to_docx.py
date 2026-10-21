import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/project-description.docx"
TEXT_WIDTH = 9354
TIMES = '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman" w:eastAsia="Times New Roman"/>'
CONSOLAS = '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas" w:eastAsia="Consolas"/>'
BODY_PPR = '<w:pPr><w:ind w:firstLine="709"/><w:jc w:val="both"/></w:pPr>'
CELL_PPR = ('<w:pPr><w:spacing w:line="240" w:lineRule="auto" w:before="0" w:after="0"/><w:ind w:firstLine="0"/>'
            '<w:jc w:val="left"/></w:pPr>')
TABLE_PR = ('<w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:type="auto" w:w="0"/><w:jc w:val="center"/>'
            '<w:tblLayout w:type="fixed"/><w:tblLook w:firstColumn="1" w:firstRow="1" w:lastColumn="0" w:lastRow="0" '
            'w:noHBand="0" w:noVBand="1" w:val="04A0"/></w:tblPr>')
LIST = re.compile(r"^\s*([-*]|\d+\.)\s+(.*)$")


def escape(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def runs(text, size, bold=False):
    out = []
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", text)
    for part in re.split(r"(`[^`]+`|\*\*[^*]+\*\*)", text):
        if not part:
            continue
        if part.startswith("`"):
            font, value, weight, part_size = CONSOLAS, part[1:-1], False, size - 4
        elif part.startswith("**"):
            font, value, weight, part_size = TIMES, part[2:-2], True, size
        else:
            font, value, weight, part_size = TIMES, part, bold, size
        mark = "<w:b/>" if weight else '<w:b w:val="0"/>'
        out.append(f'<w:r><w:rPr>{font}{mark}<w:sz w:val="{part_size}"/></w:rPr>'
                   f'<w:t xml:space="preserve">{escape(value)}</w:t></w:r>')
    return "".join(out)


def paragraph(text, ppr=BODY_PPR, size=28, bold=False):
    return f"<w:p>{ppr}{runs(text, size, bold)}</w:p>"


def title(text):
    ppr = '<w:pPr><w:spacing w:after="240"/><w:jc w:val="center"/></w:pPr>'
    return paragraph(text, ppr, 36, True)


def heading(text, level):
    style, size = ("Heading1", 32) if level == 2 else ("Heading2", 28)
    return paragraph(text, f'<w:pPr><w:pStyle w:val="{style}"/></w:pPr>', size, True)


def widths(rows):
    count = max(len(row) for row in rows)
    lengths = [max(min(len(row[i]) if i < len(row) else 0, 60) for row in rows) + 8 for i in range(count)]
    total = sum(lengths)
    return [max(1100, round(TEXT_WIDTH * length / total)) for length in lengths]


def table(rows):
    columns = widths(rows)
    grid = "".join(f'<w:gridCol w:w="{width}"/>' for width in columns)
    out = []
    for index, row in enumerate(rows):
        header = index == 0
        trpr = '<w:trPr><w:tblHeader w:val="true"/><w:cantSplit/></w:trPr>' if header else "<w:trPr><w:cantSplit/></w:trPr>"
        cells = []
        for column, width in enumerate(columns):
            value = row[column] if column < len(row) else ""
            shade = '<w:shd w:val="clear" w:color="auto" w:fill="E7E6E6"/>' if header else ""
            cells.append(f'<w:tc><w:tcPr><w:tcW w:type="dxa" w:w="{width}"/>{shade}</w:tcPr>'
                         f"{paragraph(value, CELL_PPR, 24, header)}</w:tc>")
        out.append(f"<w:tr>{trpr}{''.join(cells)}</w:tr>")
    return f"<w:tbl>{TABLE_PR}<w:tblGrid>{grid}</w:tblGrid>{''.join(out)}</w:tbl>" + paragraph("")


def cells(line):
    return [cell.strip() for cell in re.split(r"(?<!\\)\|", line.strip().strip("|"))]


def body(markdown):
    out, lines, index, titled = [], markdown.splitlines(), 0, False
    while index < len(lines):
        line = lines[index]
        if line.startswith("```"):
            index += 1
            while index < len(lines) and not lines[index].startswith("```"):
                out.append(f'<w:p>{CELL_PPR}<w:r><w:rPr>{CONSOLAS}<w:sz w:val="22"/></w:rPr>'
                           f'<w:t xml:space="preserve">{escape(lines[index])}</w:t></w:r></w:p>')
                index += 1
        elif line.startswith("# ") and not titled:
            out.append(title(line[2:].strip()))
            titled = True
        elif re.match(r"^#{2,3} ", line):
            level = len(line) - len(line.lstrip("#"))
            out.append(heading(line.lstrip("#").strip(), level))
        elif line.startswith("|"):
            rows = []
            while index < len(lines) and lines[index].startswith("|"):
                if not re.match(r"^\|[-| :]+\|$", lines[index].strip()):
                    rows.append(cells(lines[index]))
                index += 1
            out.append(table(rows))
            continue
        elif LIST.match(line):
            number = 0
            while index < len(lines) and LIST.match(lines[index]):
                marker, text = LIST.match(lines[index]).groups()
                number += 1
                prefix = f"{number}) " if marker[0].isdigit() else "– "
                out.append(paragraph(prefix + text))
                index += 1
            continue
        elif line.strip():
            out.append(paragraph(line.strip()))
        index += 1
    return "".join(out)


def main(source, target, template=TEMPLATE):
    with zipfile.ZipFile(template) as original:
        document = original.read("word/document.xml").decode("utf-8")
        head = document[: document.index("<w:body>") + len("<w:body>")]
        section = document[document.rindex("<w:sectPr"):]
        content = head + body(Path(source).read_text(encoding="utf-8")) + section
        relations = original.read("word/_rels/document.xml.rels").decode("utf-8")
        relations = re.sub(r'<Relationship [^>]*relationships/image"[^>]*/>', "", relations)
        package = original.read("_rels/.rels").decode("utf-8")
        package = re.sub(r'<Relationship [^>]*Target="docProps/thumbnail\.jpeg"[^>]*/>', "", package)
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as result:
            for item in original.infolist():
                if item.filename.startswith("word/media/") or item.filename == "docProps/thumbnail.jpeg":
                    continue
                data = {
                    "word/document.xml": content.encode("utf-8"),
                    "word/_rels/document.xml.rels": relations.encode("utf-8"),
                    "_rels/.rels": package.encode("utf-8"),
                }.get(item.filename) or original.read(item.filename)
                result.writestr(item, data)
    print(target)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
