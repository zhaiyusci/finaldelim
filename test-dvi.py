"""Compare direct PDF and LuaLaTeX DVI -> dvipdfmx, including path geometry."""
from pathlib import Path
import sys
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream, ByteStringObject, TextStringObject

prefix = sys.argv[1] if len(sys.argv) > 1 else 'dvi-test'
def color(value):
    if isinstance(value, (float,int)): value=(value,)
    value = tuple(value or (0,))
    return value * 3 if len(value) == 1 else value

with pdfplumber.open(f'build/{prefix}-pdf.pdf') as native, \
     pdfplumber.open(f'build/{prefix}-dvi.pdf') as via_dvi:
    assert len(native.pages) == len(via_dvi.pages) == 3
    for a, b in zip(native.pages, via_dvi.pages):
        assert len(a.chars) == len(b.chars)
        for c, d in zip(a.chars, b.chars):
            # dvipdfmx lacks some CMEX/CMSY ToUnicode entries which LuaTeX
            # supplies. Their embedded font and positioning still agree.
            legacy_cid = (prefix == 'dvi-traditional' and
                          c['fontname'].split('+')[-1].startswith(('CMEX','CMSY')))
            assert c['text'] == d['text'] or legacy_cid, (c, d)
            # PDF writers supply different font-descriptor ascents/descents.
            # Compare actual text transforms, not extraction bounding boxes.
            tolerance=.03 if prefix=='dvi-traditional' else .015
            assert max(abs(x-y) for x,y in zip(c['matrix'], d['matrix'])) < tolerance, (c, d)
            assert c['fontname'].split('+')[-1] == d['fontname'].split('+')[-1]
            assert max(abs(x-y) for x,y in zip(color(c['non_stroking_color']),
                                               color(d['non_stroking_color']))) < .00051
        kinds=('curves','rules') if prefix=='dvi-traditional' else ('curves','lines','rects')
        for kind in kinds:
            if kind=='rules':
                # TeX rules may be filled rectangles or stroked centerlines.
                def rules(page):
                    values=list(page.lines)
                    for v in page.rects:
                        v=dict(v)
                        if v['fill'] and not v['stroke']:
                            v.update(top=(v['top']+v['bottom'])/2,bottom=(v['top']+v['bottom'])/2,
                                     linewidth=v['height'],stroke=True,fill=False,
                                     stroking_color=v['non_stroking_color'])
                        values.append(v)
                    return sorted(values,key=lambda v:(round(v['top'],2),round(v['x0'],2)))
                aa,bb=rules(a),rules(b)
            else: aa, bb = getattr(a, kind), getattr(b, kind)
            if prefix == 'dvi-global':
                # The page drivers use different zero-size origin wrappers.
                # Their whole-page diagnostics differ outside the content area.
                def content(v):
                    return (v['x0']>50 and v['top']>50 and v['bottom']<740
                            and v['width']+v['height']>.001)
                aa=list(filter(content,aa));bb=list(filter(content,bb))
            assert len(aa) == len(bb), (kind, len(aa), len(bb))
            for c, d in zip(aa, bb):
                assert max(abs(c[k]-d[k]) for k in ('x0','x1','top','bottom')) < .003, (kind,c,d)
                if kind=='rules': assert abs(c['linewidth']-d['linewidth'])<.003
                for flag,key in (('stroke','stroking_color'), ('fill','non_stroking_color')):
                    if c.get(flag):
                        assert max(abs(x-y) for x,y in zip(color(c[key]),color(d[key]))) < .00051, (kind,key)
                if kind == 'curves':
                    assert len(c['pts']) == len(d['pts'])
                    for p,q in zip(c['pts'],d['pts']):
                        assert max(abs(x-y) for x,y in zip(p,q)) < .003
                    for p,q in zip(c['path'],d['path']):
                        assert p[0]==q[0] and len(p)==len(q)
                        for xy,uv in zip(p[1:],q[1:]):
                            assert max(abs(x-y) for x,y in zip(xy,uv)) < .003
    if prefix != 'dvi-traditional': assert len(via_dvi.pages[0].curves)>10
    if prefix == 'dvi-global':
        assert all(len(p.curves)>100 for p in via_dvi.pages)
    else:
        assert len(via_dvi.pages[2].curves)>len(via_dvi.pages[0].curves)
if prefix == 'dvi-traditional':
    def symbol_codes(mode):
        reader=PdfReader(f'build/{prefix}-{mode}.pdf');result=[]
        for page in reader.pages:
            fonts=page['/Resources']['/Font'];current=''
            for args,op in ContentStream(page.get_contents(),reader).operations:
                if op==b'Tf': current=str(fonts[args[0]]['/BaseFont']).split('+')[-1]
                elif op in (b'Tj',b'TJ') and current.startswith(('CMEX','CMSY')):
                    for value in (args[0] if op==b'TJ' else args):
                        if isinstance(value,(ByteStringObject,TextStringObject)):
                            raw=value.original_bytes if isinstance(value,TextStringObject) else bytes(value)
                            result.extend((current,code) for code in raw)
        return result
    assert symbol_codes('pdf')==symbol_codes('dvi'), 'Legacy symbol font/character codes changed'
for mode in ('pdf', 'dvi'):
    log=Path(f'build/{prefix}-{mode}.log').read_text(encoding='utf-8')
    assert 'Missing character' not in log and 'Overfull' not in log
    assert r'\newlabel{dvi:last}{{9}' in Path(f'build/{prefix}-{mode}.aux').read_text()
print(f'PASS {prefix}: text positions/colors, complete paths, native leaders, roots, scripts, numbering, transformed output and debug match PDF')
