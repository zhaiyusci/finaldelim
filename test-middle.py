"""Native PDF geometry and independently integrated middle-position profiles."""
import json, math, re
from pathlib import Path
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream

def chars(path):
 with pdfplumber.open(path) as pdf:
  return [dict(c,text=t) for p in pdf.pages for c in p.chars for t in c['text'] if t!=' ']
def same(a,b):
 assert ''.join(c['text'] for c in a)==''.join(c['text'] for c in b)
 dx,dy=b[0]['x0']-a[0]['x0'],b[0]['top']-a[0]['top']
 for x,y in zip(a,b):
  assert x['fontname']==y['fontname']
  for k in ('x0','x1','top','bottom','size'):
   shift=dx if k in ('x0','x1') else dy if k in ('top','bottom') else 0
   assert abs(y[k]-x[k]-shift)<.012,(x['text'],k,y[k]-x[k]-shift)
for name in ('middle-test','middle-traditional'):
 cs=chars('build/'+name+'.pdf');text=''.join(c['text'] for c in cs)
 heads=list(re.finditer('Native:|Maximum:|PlainStart:|RainbowStart:|EndChecks:',text))
 for i in range(0,16,2):
  a,b,c=heads[i:i+3]
  same(cs[a.end():b.start()],cs[b.end():c.start()])
 a,b,c=heads[-3:]
 plain,painted=cs[a.end():b.start()],cs[b.end():c.start()]
 same(plain,painted)
 colored=[c for c in painted if c['non_stroking_color'] not in (0,(0,),(0,0,0),None)]
 assert colored and len({str(c['non_stroking_color']) for c in colored})>=2
 for c in colored:
  assert c['text'] in '()[]|\u2223\u2225\u2016\u23a1\u23a2\u23a3\u23a4\u23a5\u23a6\ufe02\ufe03\u20d3\u20e6',c['text']
 reader=PdfReader('build/'+name+'.pdf')
 for page in reader.pages:
  assert not any(op in (b'W',b'W*') for _,op in ContentStream(page.get_contents(),reader).operations)
 print('PASS',name,': native/max glyph geometry; niji geometry, nesting and no body leakage; no clipping')
profiles=[json.loads(l) for l in Path('build/middle-profiles.jsonl').read_text().splitlines()]
selected={}
for t in profiles:
 if len(t['positions'])<3: continue
 selected[t['case']]=t
 terms=t['terms'];L=min(v[2] for v in terms);H=max(v[2] for v in terms)
 intervals=[];end=0
 for a,b,r in terms:
  if a>end: intervals.append((end,a,L))
  intervals.append((a,b,r));end=b
 if end<t['width']: intervals.append((end,t['width'],L))
 estimates=[]
 for at in t['positions']:
  num=den=0
  for a,b,r in intervals:
   # Independent midpoint quadrature, splitting at the cusp of abs(x-at).
   cuts=sorted(set((a,b,max(a,min(b,at)))))
   for lo,hi in zip(cuts,cuts[1:]):
    dx=(hi-lo)/800
    w=sum(math.exp(-abs(lo+(i+.5)*dx-at)/t['lambda']) for i in range(800))*dx
    num+=(r/H)**t['q']*w;den+=w
  estimates.append((num/den)**(1/t['q']))
 expected=H*max(estimates)
 assert abs(expected-t['radius'])/65536<.0001,(t['case'],expected,t['radius'])
assert set(selected)=={'far','near','many'}
assert len(selected['many']['positions'])==5
assert selected['near']['radius']>selected['far']['radius']
print('PASS: independent quadrature at every delimiter position; moving a middle near tall content increases the shared radius')
for k,v in selected.items(): print(k,round(v['radius']/65536,4),'pt;',len(v['positions']),'delimiter positions')
aux=Path('build/middle-test.aux').read_text()
assert r'\newlabel{eq:middle-one}{{1}' in aux
assert r'\newlabel{eq:middle-row}{{4}' in aux
print('PASS: equation and align labels, source-once TeX assertions')

log=Path('build/middle-endpoint-test.log').read_text()
metrics=re.findall(r'WEIGHTED middles \d+: fences=3 ([\d.]+)pt / ([\d.]+)pt',log)
assert len(metrics)==3 and metrics[0]==metrics[1]
assert float(metrics[2][0])>float(metrics[0][0])
print('PASS: endpoint policy ignores a tall unmarked row but includes a middle-bearing row')
