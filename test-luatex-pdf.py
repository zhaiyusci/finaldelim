"""Independent checks of the public LuaTeX backend's final PDF output."""
import re
from pathlib import Path
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream

render_pdf = Path('build/lualatex-luatex_render_test.pdf')
if not render_pdf.exists():
    render_pdf = Path('build/luatex_render_test.pdf')
with pdfplumber.open(render_pdf) as doc:
    chars = [dict(c, text=ch) for p in doc.pages for c in p.chars
             for ch in c['text'] if ch != ' ']
text = ''.join(c['text'] for c in chars)
heads = list(re.finditer(r'Plain:|Rainbow:|Debug:|EndComparisons:', text))
assert len(heads) == 4
parts = [chars[a.end():b.start()] for a, b in zip(heads, heads[1:])]
for i, part in enumerate(parts[1:], 1):
    reference = parts[0]
    assert ''.join(c['text'] for c in part) == ''.join(c['text'] for c in reference)
    dx, dy = part[0]['x0']-reference[0]['x0'], part[0]['top']-reference[0]['top']
    worst = 0
    for a, b in zip(part, reference):
        assert a['fontname'] == b['fontname']
        for key in ('x0', 'x1', 'top', 'bottom', 'size'):
            offset = dx if key in ('x0', 'x1') else dy if key in ('top', 'bottom') else 0
            worst = max(worst, abs(a[key]-b[key]-offset))
    # PDF text advances are rounded differently when debug literals split runs.
    # TeX-level dimensions are checked exactly in luatex_flat_test.tex.
    assert worst < .012, (i, worst)
    print('PASS: rainbow/debug PDF geometry, variant', i, 'max deviation', round(worst, 6), 'pt')

def colored(c):
    value = c['non_stroking_color']
    return value not in (0, 0.0, (0,), (0.0,), (0, 0, 0), (0, 0, 0, 1))

painted = [c for c in parts[1] if colored(c)]
assert painted and all(c['text'] in '()[]\ufe02\ufe03' for c in painted), [c['text'] for c in painted]
assert len({str(c['non_stroking_color']) for c in painted}) == 2, 'Nesting palette lost'
assert any(c['text'] == '(' and not colored(c) for c in parts[1]), 'Ordinary delimiter was colored'
for c in parts[1]:
    if c['text'] in 'abcfgituv2':
        assert not colored(c), ('Color leaked into body/script', c['text'])
print('PASS: only native explicit delimiters colored; body, scripts and ordinary delimiters unchanged')

reader = PdfReader(render_pdf)
for page in reader.pages:
    assert not any(op in (b'W', b'W*') for args, op in ContentStream(page.get_contents(), reader).operations)
print('PASS: no PDF clipping')

with pdfplumber.open('build/lualatex-demo.pdf') as doc:
    chars = doc.pages[0].chars
parts, start = [], 0
for number in '123':
    for i in range(start, len(chars)-2):
        if ''.join(c['text'] for c in chars[i:i+3]) == '('+number+')' and chars[i]['x0'] > 450:
            parts.append(chars[start:i]); start = i+3; break
assert len(parts) == 3
for index, actual in enumerate(parts[:2], 1):
    native = parts[2]
    assert len(actual) == len(native)
    assert ''.join(c['text'] for c in actual) == ''.join(c['text'] for c in native)
    dx, dy = actual[0]['x0']-native[0]['x0'], actual[0]['top']-native[0]['top']
    worst = max(abs(a[key]-b[key]-(dx if key in ('x0','x1') else dy if key in ('top','bottom') else 0))
                for a, b in zip(actual, native) for key in ('x0','x1','top','bottom','size'))
    assert worst < .012, (index, worst)
    print('PASS: current user demo, formula', index, 'including native row spacing; max deviation', round(worst, 6), 'pt')

pages_pdf = Path('build/lualatex-luatex_pagebreak_test.pdf')
if not pages_pdf.exists():
    pages_pdf = Path('build/flat-pagebreak-test.pdf')
with pdfplumber.open(pages_pdf) as doc:
    assert len(doc.pages) > 1, 'Expected a page break'
    chars = [c for p in doc.pages for c in p.chars]
    xs = [c for c in chars if c['text'] == 'x']
    assert len(xs) == 25, 'Page breaking duplicated or lost formula contents'
    assert not any(colored(c) for c in xs), 'Rainbow leaked across a page break'
aux = pages_pdf.with_suffix('.aux').read_text()
for n in range(1, 26):
    assert ('\\newlabel{page:' + str(n) + '}{{' + str(n) + '}') in aux
print('PASS: 25 numbered rows across pages, no duplicate glyphs or color leakage')
