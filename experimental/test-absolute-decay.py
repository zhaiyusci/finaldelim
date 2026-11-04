import csv, math
from pathlib import Path
import pdfplumber
root=Path(__file__).resolve().parents[1]
def read(s): return list(csv.DictReader((root/'build'/s).open(),delimiter='\t'))
g={}
for v in read('absolute-decay-geometry.tsv'):
 g.setdefault(v['case'],[]).append({k:float(x) for k,x in v.items() if k!='case'})
rows=read('absolute-decay.tsv'); assert len(rows)==360 and len(g)==15
for row in rows:
 ts=g[row['case']]; W,L,H=[ts[0][k] for k in ('W','L','H')]
 q=int(row['q']); lam=float(row['lambda_pt'])
 if q==0: values=[H,H,H]
 else:
  pieces=[]; end=0
  for v in ts:
   pieces.extend([(end,v['x'],L),(v['x'],v['finish'],v['r'])]); end=v['finish']
  pieces.append((end,W,L)); ss=[0.,0.]; ns=[0.,0.]
  for a,b,r in pieces:
   for j in range(2000):
    x=a+(b-a)*(j+.5)/2000
    for s,d in enumerate((x,W-x)):
     weight=math.exp(-d/lam)*(b-a)/2000
     ss[s]+=weight*(r/H)**q; ns[s]+=weight
  l,r=[H*(s/n)**(1/q) for s,n in zip(ss,ns)]
  values=[l,r,((l**3+r**3)/2)**(1/3)]
 for k,v in zip(('left','right','radius'),values): assert abs(float(row[k])-v)<.0005,(row,k,v)
 if row['case']=='square': assert all(abs(float(row[k])-10)<.001 for k in ('left','right','radius'))
for case in g:
 for alpha in ('10','20','40','80'):
  series=[float(r['radius']) for r in rows if r['case']==case and float(r['lambda_pt'])==float(alpha)]
  assert series==sorted(series)
with pdfplumber.open(root/'build/absolute-decay.pdf') as pdf:
 assert len(pdf.pages)==15
 for page in pdf.pages:
  text=page.extract_text()
  assert 'Native reference' in text and 'lowest term radius' in text
  assert len([c for c in page.chars if c.get('non_stroking_color')==(0,0,1)])>0
  assert all(c['x0']>=0 and c['x1']<=page.width and c['top']>=0 and c['bottom']<=page.height for c in page.chars)
assert 'Overfull' not in (root/'build/absolute-decay.log').read_text()
print('PASS: 360 numeric comparisons, single-square control, q monotonicity, 15 pages; compilation checks source-once, subdivision and mirror invariance.')
for row in rows:
 if row['case'] in ('hml6','lhl6') and row['q']=='8': print(row)
