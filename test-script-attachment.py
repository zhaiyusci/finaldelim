import re, unicodedata
from pathlib import Path
import pdfplumber
with pdfplumber.open('build/script-attachment-test.pdf') as pdf:
    cases={}
    for p in pdf.pages:
        cs=[dict(c,text=unicodedata.normalize('NFKC',c['text'])) for c in p.chars if c['text']!=' ']
        text=''.join(c['text'] for c in cs)
        heads=list(re.finditer(r'Case([A-I]):',text))
        for i,m in enumerate(heads):
            end=heads[i+1].start() if i+1<len(heads) else len(cs)
            cases[m[1]]=cs[m.end():end]
def anchor(cs):
    return next(c for c in cs if c['text']=='a')
def pos(cs,t):
    c=next(c for c in cs if c['text']==t);a=anchor(cs)
    return c['x0']-a['x0'],c['top']-a['top']
def body(cs):
    return [c for c in cs if c['text'] in ('a','1','2','3','4','x')]
def equal_body(a,b):
    aa,bb=anchor(a),anchor(b)
    a,b=body(a),body(b)
    assert len(a)==len(b)
    for c,d in zip(a,b):
        assert c['text']==d['text']
        for key in ('x0','top'):
            assert abs(c[key]-aa[key]-d[key]+bb[key])<.012
for x,y in [('A','B'),('C','D')]:
    a,b=cases[x],cases[y]
    equal_body(a,b)
    assert pos(b,'U')[1]-pos(a,'U')[1]>1, (x,'upper',pos(a,'U'),pos(b,'U'))
    assert pos(a,'D')[1]-pos(b,'D')[1]>1, (x,'lower',pos(a,'D'),pos(b,'D'))
for x,y in [('D','E'),('F','G'),('H','I')]:
    a,b=cases[x],cases[y]
    for t in ('U','D'):
        assert abs(pos(a,t)[1]-pos(b,t)[1])<.012,(x,y,t,pos(a,t),pos(b,t))
for c in cases['E']:
    if c['text'] in ('a','x','U','D','1','2','3','4'):
        assert c['non_stroking_color'] in (0,(0,),(0,0,0),None),c
assert r'\newlabel{scripts:last}{{2}' in Path('build/script-attachment-test.aux').read_text()
print('PASS: scripts track final fences; matrix geometry unchanged; middle/niji; invisible and native attachment retained; per-row numbering')
