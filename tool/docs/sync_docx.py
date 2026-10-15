import difflib
import html
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

REPORT = []


def norm(text):
    text = html.unescape(text)
    text = re.sub(r'^(\d+\)|–)\s+', '', text.strip())
    return re.sub(r'\s+', ' ', text).strip().lower()


def plain_md(raw):
    text = re.sub(r'`([^`]*)`', r'\1', raw)
    text = re.sub(r'\*\*([^*]*)\*\*', r'\1', text)
    text = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', text)
    return text.replace('\\|', '|').strip()


def md_units(md):
    units, tables, in_code, current = [], [], False, None
    for line in md.split('\n'):
        if line.startswith('```'):
            in_code = not in_code
            current = None
            continue
        if in_code:
            if line.strip():
                units.append({'kind': 'code', 'raw': line, 'text': line.strip()})
            continue
        if line.startswith('|'):
            if re.match(r'^\|[-| :]+\|$', line.strip()):
                continue
            cells = [c.strip() for c in re.split(r'(?<!\\)\|', line.strip().strip('|'))]
            if current is None:
                current = {'rows': []}
                tables.append(current)
            current['rows'].append(cells)
            for col, cell in enumerate(cells):
                units.append({'kind': 'cell', 'raw': cell, 'text': plain_md(cell), 'table': len(tables) - 1})
            continue
        current = None
        if not line.strip() or line.lstrip().startswith(('<p', '!', '<img')):
            continue
        match = re.match(r'^(#+)\s*(.*)$', line)
        if match:
            units.append({'kind': 'h', 'raw': match.group(2), 'text': plain_md(match.group(2))})
            continue
        match = re.match(r'^\s*([-*]|\d+\.)\s+(.*)$', line)
        if match:
            units.append({'kind': 'li', 'raw': match.group(2), 'text': plain_md(match.group(2)),
                          'ordered': match.group(1)[0].isdigit()})
            continue
        units.append({'kind': 'p', 'raw': line.strip(), 'text': plain_md(line)})
    return [u for u in units if u['text']], tables


def texts_of(xml):
    return ''.join(html.unescape(t) for t in re.findall(r'<w:t(?: [^>]*)?>([^<]*)</w:t>', xml))




def sync(markdown, source):
    body_open = source.index('<w:body>') + len('<w:body>')
    body_close = source.rindex('<w:sectPr')
    head, body, tail = source[:body_open], source[body_open:body_close], source[body_close:]
    ELEMENT = re.compile(r'<w:tbl>.*?</w:tbl>|<w:p\b[^>]*/>|<w:p\b.*?</w:p>', re.S)
    elements = [m.group(0) for m in ELEMENT.finditer(body)]
    assert ''.join(elements) == body, 'unexpected body content'

    docx_units = []
    for index, element in enumerate(elements):
        if element.startswith('<w:tbl>'):
            rows = re.findall(r'<w:tr\b.*?</w:tr>', element, re.S)
            is_code = len(rows) == 1 and rows[0].count('<w:tc>') == 1 and 'Consolas' in element
            if is_code:
                for line_no, para in enumerate(re.findall(r'<w:p\b.*?</w:p>', element, re.S)):
                    text = texts_of(para)
                    if text.strip():
                        docx_units.append({'el': index, 'kind': 'code', 'text': text, 'line': line_no})
            else:
                for r, row in enumerate(rows):
                    for c, cell in enumerate(re.findall(r'<w:tc>.*?</w:tc>', row, re.S)):
                        text = texts_of(cell)
                        if text.strip():
                            docx_units.append({'el': index, 'kind': 'cell', 'text': text, 'row': r, 'col': c})
        else:
            text = texts_of(element)
            if text.strip():
                is_toc = '<w:tab/>' in element and re.search(r'\d+$', text.strip())
                docx_units.append({'el': index, 'kind': 'toc' if is_toc else 'p', 'text': text})


    def key(unit):
        text = norm(unit['text'])
        if unit.get('kind') == 'toc':
            text = re.sub(r'\d+$', '', text).strip()
        return text


    units, md_tables = md_units(markdown)
    a = [key(u) for u in docx_units]
    b = [norm(u['text']) for u in units]
    matcher = difflib.SequenceMatcher(None, a, b, autojunk=False)
    opcodes = matcher.get_opcodes()

    table_votes = {}
    for tag, i1, i2, j1, j2 in opcodes:
        pairs = zip(range(i1, i2), range(j1, j2)) if tag in ('equal', 'replace') else []
        for i, j in pairs:
            if docx_units[i]['kind'] == 'cell' and units[j]['kind'] == 'cell':
                votes = table_votes.setdefault(docx_units[i]['el'], {})
                votes[units[j]['table']] = votes.get(units[j]['table'], 0) + 1
    table_map = {el: max(v, key=v.get) for el, v in table_votes.items()}

    RPR_BODY = ('<w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman" '
                'w:eastAsia="Times New Roman"/><w:b w:val="0"/><w:sz w:val="28"/></w:rPr>')


    def esc(text):
        return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


    def first_rpr(xml, consolas):
        for rpr in re.findall(r'<w:rPr>.*?</w:rPr>', xml, re.S):
            if ('Consolas' in rpr) == consolas:
                return rpr
        return None


    def code_rpr_from(base):
        size = int((re.search(r'<w:sz w:val="(\d+)"/>', base) or [0, 28])[1])
        rpr = re.sub(r'w:(ascii|hAnsi|cs|eastAsia)="[^"]*"', lambda m: f'w:{m.group(1)}="Consolas"', base)
        return re.sub(r'<w:b/>', '<w:b w:val="0"/>', re.sub(r'<w:sz w:val="\d+"/>', f'<w:sz w:val="{max(20, size - 4)}"/>', rpr))


    def bold_rpr_from(base):
        rpr = re.sub(r'<w:b w:val="0"/>', '<w:b/>', base)
        return rpr if '<w:b/>' in rpr else rpr.replace('</w:rPr>', '<w:b/></w:rPr>')


    def runs(raw, base, code=None, prefix=''):
        code = code or code_rpr_from(base)
        out = []
        if prefix:
            out.append(f'<w:r>{base}<w:t xml:space="preserve">{esc(prefix)}</w:t></w:r>')
        raw = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', raw).replace('\\|', '|')
        for part in re.split(r'(`[^`]*`|\*\*[^*]+\*\*)', raw):
            if not part:
                continue
            if part.startswith('`'):
                rpr, text = code, part[1:-1]
            elif part.startswith('**'):
                rpr, text = bold_rpr_from(base), part[2:-2]
            else:
                rpr, text = base, part
            out.append(f'<w:r>{rpr}<w:t xml:space="preserve">{esc(text)}</w:t></w:r>')
        return ''.join(out)


    def ppr_of(para):
        match = re.search(r'<w:pPr>.*?</w:pPr>', para, re.S)
        return match.group(0) if match else ''


    def rewrite_para(para, raw, keep_prefix=True):
        text = texts_of(para)
        prefix = ''
        match = re.match(r'^(\d+\)|–)\s+', text)
        if keep_prefix and match:
            prefix = match.group(0)
        base = first_rpr(para, False) or RPR_BODY
        code = first_rpr(para, True)
        start = re.match(r'<w:p\b[^>]*>', para).group(0)
        return f'{start}{ppr_of(para)}{runs(raw, base, code, prefix)}</w:p>'


    def rebuild_table(xml, rows):
        grid = [int(w) for w in re.findall(r'<w:gridCol w:w="(\d+)"/>', xml)]
        total = sum(grid)
        count = max(len(r) for r in rows)
        if count == len(grid):
            widths = grid
        elif count < len(grid):
            part = grid[:count]
            widths = [round(w * total / sum(part)) for w in part]
        else:
            widths = [total // count] * count
        trs = re.findall(r'<w:tr\b.*?</w:tr>', xml, re.S)
        header_tpl, data_tpl = trs[0], trs[1] if len(trs) > 1 else trs[0]
        built = []
        for r, cells in enumerate(rows):
            tpl = header_tpl if r == 0 else data_tpl
            tr_start = re.match(r'<w:tr\b[^>]*>', tpl).group(0)
            trpr = (re.search(r'<w:trPr>.*?</w:trPr>', tpl, re.S) or [''])[0]
            tcs = re.findall(r'<w:tc>.*?</w:tc>', tpl, re.S)
            out = []
            for c in range(count):
                tc = tcs[min(c, len(tcs) - 1)]
                tcpr = re.sub(r'<w:tcW w:type="dxa" w:w="\d+"/>', f'<w:tcW w:type="dxa" w:w="{widths[c]}"/>',
                              re.search(r'<w:tcPr>.*?</w:tcPr>', tc, re.S).group(0))
                para = re.search(r'<w:p\b.*?</w:p>', tc, re.S).group(0)
                base = first_rpr(para, False) or RPR_BODY
                code = first_rpr(para, True)
                raw = cells[c] if c < len(cells) else ''
                out.append(f'<w:tc>{tcpr}<w:p>{ppr_of(para)}{runs(raw, base, code)}</w:p></w:tc>')
            built.append(f'{tr_start}{trpr}{"".join(out)}</w:tr>')
        tblpr = re.search(r'<w:tblPr>.*?</w:tblPr>', xml, re.S).group(0)
        grid_xml = '<w:tblGrid>' + ''.join(f'<w:gridCol w:w="{w}"/>' for w in widths) + '</w:tblGrid>'
        return f'<w:tbl>{tblpr}{grid_xml}{"".join(built)}</w:tbl>'


    def table_text(xml):
        return [[norm(texts_of(tc)) for tc in re.findall(r'<w:tc>.*?</w:tc>', tr, re.S)]
                for tr in re.findall(r'<w:tr\b.*?</w:tr>', xml, re.S)]


    new_elements = list(elements)
    for el, md_index in table_map.items():
        rows = md_tables[md_index]['rows']
        wanted = [[norm(plain_md(c)) for c in row] for row in rows]
        if table_text(elements[el]) != wanted:
            new_elements[el] = rebuild_table(elements[el], rows)
            REPORT.append(f'таблица {el}: пересобрана ({len(rows)} строк)')

    inserts_after = {}
    removed = set()


    def pair_up(i1, i2, j1, j2):
        left, right = list(range(i1, i2)), list(range(j1, j2))
        pairs, used = [], set()
        for i in left:
            best, score = None, 0.0
            for j in right:
                if j in used:
                    continue
                ratio = difflib.SequenceMatcher(None, a[i], b[j]).ratio()
                if ratio > score:
                    best, score = j, ratio
            if best is not None and score > 0.5 and (not pairs or best > pairs[-1][1]):
                pairs.append((i, best))
                used.add(best)
        return pairs


    last_para_el = {}
    for tag, i1, i2, j1, j2 in opcodes:
        if tag == 'equal':
            for i, j in zip(range(i1, i2), range(j1, j2)):
                last_para_el[units[j]['kind']] = docx_units[i]['el']
            continue
        pairs = list(zip(range(i1, i2), range(j1, j2))) if (i2 - i1) == (j2 - j1) else pair_up(i1, i2, j1, j2)
        paired_i = {i for i, _ in pairs}
        paired_j = {j for _, j in pairs}
        for i, j in pairs:
            unit, md = docx_units[i], units[j]
            if unit['kind'] in ('p', 'toc') and md['kind'] in ('p', 'li', 'h') and unit['kind'] != 'toc':
                new_elements[unit['el']] = rewrite_para(elements[unit['el']], md['raw'])
                REPORT.append(f'абзац {unit["el"]}: {md["text"][:70]}')
            elif unit['kind'] == 'code' and md['kind'] == 'code':
                pass
            last_para_el[md['kind']] = unit['el']
        for i in range(i1, i2):
            unit = docx_units[i]
            if i not in paired_i and unit['kind'] == 'p':
                if unit['el'] not in table_map:
                    removed.add(unit['el'])
                    REPORT.append(f'удалён абзац {unit["el"]}: {unit["text"][:70]}')
        anchor = docx_units[i1 - 1]['el'] if i1 > 0 else 0
        for j in range(j1, j2):
            md = units[j]
            if j in paired_j or md['kind'] not in ('p', 'li'):
                continue
            prev = None
            for i in range(i1 - 1, -1, -1):
                if docx_units[i]['kind'] == 'p':
                    prev = elements[docx_units[i]['el']]
                    break
            template = elements[last_para_el.get(md['kind'], last_para_el.get('p', anchor))]
            if template.startswith('<w:tbl>'):
                template = prev
            prefix = '– ' if md['kind'] == 'li' and not md.get('ordered') else ''
            para = f'<w:p>{ppr_of(template)}{runs(md["raw"], first_rpr(template, False) or RPR_BODY, None, prefix)}</w:p>'
            inserts_after.setdefault(anchor, []).append(para)
            REPORT.append(f'вставлен абзац после {anchor}: {md["text"][:70]}')

    out = []
    for index, element in enumerate(new_elements):
        if index not in removed:
            out.append(element)
        out.extend(inserts_after.get(index, []))
    return head + ''.join(out) + tail


def main(markdown_path, docx_path):
    docx_path = Path(docx_path)
    with zipfile.ZipFile(docx_path) as archive:
        names = archive.namelist()
        parts = {name: archive.read(name) for name in names}
    document = sync(Path(markdown_path).read_text(encoding="utf-8"), parts["word/document.xml"].decode("utf-8"))
    parts["word/document.xml"] = document.encode("utf-8")
    with tempfile.NamedTemporaryFile(suffix=".docx", delete=False) as target:
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
            for name in names:
                archive.writestr(name, parts[name])
    shutil.move(target.name, docx_path)
    print("\n".join(REPORT) or "без изменений")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
