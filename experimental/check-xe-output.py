"""Check moved PDF content, including scripts, against untouched native math."""
import re
from pathlib import Path
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream

path = Path('build/xe-output-test.pdf')
with pdfplumber.open(path) as pdf:
    chars = [dict(c, text=ch) for p in pdf.pages for c in p.chars
             for ch in c['text'] if ch != ' ']
text = ''.join(c['text'] for c in chars)
headings = list(re.finditer(r'Native:|Split:|EndComparisons:', text))
assert len(headings) == 11
aux = Path('build/xe-output-test.aux').read_text()
steps = [float(n) * 72 / 72.27 for n in re.findall(r'\\msxeSetStep\{\d+\}\{([\d.]+)pt\}', aux)]
for case, (row_count, cell_count) in enumerate(((2, 2), (3, 3), (2, 2), (2, 2), (2, 2))):
    a, b, end = headings[2*case:2*case+3]
    native, moved = chars[a.end():b.start()], chars[b.end():end.start()]
    assert ''.join(c['text'] for c in native) == ''.join(c['text'] for c in moved), ('duplicated/missing glyphs', case)
    groups = []
    worst = 0
    for old, new in zip(native, moved):
        assert old['fontname'] == new['fontname']
        assert abs(old['size'] - new['size']) < .001
        delta = (new['x0'] - old['x0'], new['top'] - old['top'])
        for representative in groups:
            error = max(abs(x-y) for x, y in zip(delta, representative))
            if error < .012:
                worst = max(worst, error)
                break
        else:
            groups.append(delta)
    assert len(groups) == cell_count, ('glyphs do not move together with their cell', case, groups)
    baselines = sorted({round(y - groups[0][1], 2) for x, y in groups})
    assert len(baselines) == row_count, (case, baselines)
    for row, baseline in enumerate(baselines):
        assert abs(baseline - row * steps[case]) < .015, (case, baseline, steps[case])
    print('Case', case+1, 'PASS:', len(native), 'characters;', row_count,
          'rows; max within-cell displacement error', round(worst, 6), 'pt')

reader = PdfReader(path)
for page in reader.pages:
    ops = ContentStream(page.get_contents(), reader).operations
    assert not any(op in (b'W', b'W*') for args, op in ops), 'Unexpected PDF clipping'
    assert not page['/Resources'].get('/XObject'), 'Unexpected copied form/image content'
print('PASS: no clipping operators, no repeated form XObjects, no extra glyphs')

with pdfplumber.open('build/xe-output-demo.pdf') as pdf:
    chars = pdf.pages[0].chars
parts, start = [], 0
for number in '123':
    for i in range(start, len(chars)-2):
        if ''.join(c['text'] for c in chars[i:i+3]) == '('+number+')' and chars[i]['x0'] > 450:
            parts.append(chars[start:i]); start = i+3; break
assert len(parts) == 3
def rows(chars):
    cuts = [0, next(i for i, c in enumerate(chars) if c['text'] == '='),
            next(i for i, c in enumerate(chars) if c['text'] == '\u00d7'), len(chars)]
    return [chars[a:b] for a, b in zip(cuts, cuts[1:])]
for formula, part in enumerate(parts[:2], 1):
    assert len(part) == len(parts[2]), 'Extra/missing PDF characters in demo'
    for row, (native, moved) in enumerate(zip(rows(parts[2]), rows(part)), 1):
        assert ''.join(c['text'] for c in native) == ''.join(c['text'] for c in moved)
        dx, dy = moved[0]['x0'] - native[0]['x0'], moved[0]['top'] - native[0]['top']
        worst = 0
        for old, new in zip(native, moved):
            for key in ('x0', 'x1', 'top', 'bottom', 'size'):
                shift = dx if key in ('x0', 'x1') else dy if key in ('top', 'bottom') else 0
                worst = max(worst, abs(new[key] - old[key] - shift))
        assert worst < .012, (formula, row, worst)
        print('User demo', formula, 'row', row, 'PASS; max PDF deviation', round(worst, 6), 'pt')
