"""Independent PDF checks for the experimental physical-partition backend."""
from pathlib import Path
import re
import pdfplumber


def geometry(reference, actual, context, tolerance=.003):
    assert len(reference) == len(actual), (context, len(reference), len(actual))
    assert ''.join(c['text'] for c in reference) == ''.join(c['text'] for c in actual), context
    dx = actual[0]['x0'] - reference[0]['x0']
    dy = actual[0]['top'] - reference[0]['top']
    worst = 0
    for a, b in zip(actual, reference):
        for key in ('x0', 'x1', 'top', 'bottom', 'size'):
            shift = dx if key in ('x0', 'x1') else dy if key in ('top', 'bottom') else 0
            worst = max(worst, abs(a[key] - b[key] - shift))
    assert worst < tolerance, (context, worst)
    return worst


for filename in ('flat-core-test', 'flat-core-unicode'):
    with pdfplumber.open(Path('build') / (filename + '.pdf')) as pdf:
        chars = [dict(c, text=letter) for page in pdf.pages for c in page.chars
                 for letter in c['text'] if letter != ' ']
    text = ''.join(c['text'] for c in chars)
    headings = list(re.finditer(r'Native:|Rejoined:|Split:', text))
    assert len(headings) == 30, (filename, len(headings))
    for case in range(10):
        a, b, c = headings[3*case:3*case+3]
        reference = chars[a.end():b.start()]
        rejoined = chars[b.end():c.start()]
        geometry(reference, rejoined, (filename, case, 'rejoined'))
        end = headings[3*case+3].start() if case < 9 else text.index('EndComparisons:')
        pieces = chars[c.end():end]
        assert ''.join(x['text'] for x in reference) == ''.join(x['text'] for x in pieces), (filename, case, 'duplicated/missing PDF content')
    print(filename, 'PASS: native/rejoined PDF geometry; actual split glyph content')

with pdfplumber.open('build/flat-demo.pdf') as pdf:
    chars = pdf.pages[0].chars
parts = []
start = 0
for number in '123':
    for i in range(start, len(chars)-2):
        if ''.join(c['text'] for c in chars[i:i+3]) == '('+number+')' and chars[i]['x0'] > 450:
            parts.append(chars[start:i]); start = i+3; break
assert len(parts) == 3


def rows(chars):
    cuts = [0, next(i for i, c in enumerate(chars) if c['text'] == '='),
            next(i for i, c in enumerate(chars) if c['text'] == '\u00d7'), len(chars)]
    return [chars[a:b] for a, b in zip(cuts, cuts[1:])]


native = rows(parts[2])
for index, part in enumerate(parts[:2], 1):
    assert len(part) == len(parts[2]), ('demo contains extra/missing glyphs', index)
    for row_number, (reference, actual) in enumerate(zip(native, rows(part)), 1):
        worst = geometry(reference, actual, ('user demo', index, row_number), tolerance=.006)
        print('demo', index, 'row', row_number, 'PASS; max PDF deviation', round(worst, 6), 'pt')
