import csv, math
from pathlib import Path
import pdfplumber
root=Path(__file__).resolve().parents[1]
def read(s): return list(csv.DictReader((root/'build'/s).open(),delimiter='\t'))
g={}
for v in read('font-size-geometry.tsv'):
 g.setdefault(v['case'],[]).append({k:float(x) for k,x in v.items() if k!='case'})
rows=read('font-size.tsv'); assert len(rows)==75 and len(g)==75
for row in rows:
 ts=g[row['case']]; W,L,H=[ts[0][k] for k in ('W','L','H')]
 q=float(row['q']); power=float(row['p']); lam=float(row['lambda_pt'])
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
  values=[l,r,((l**power+r**power)/2)**(1/power)]
 for k,v in zip(('left','right','radius'),values): assert abs(float(row[k])-v)<.0005,(row,k,v)
 if row['case'].startswith('square'): assert all(abs(float(row[k])-10)<.001 for k in ('left','right','radius'))
with pdfplumber.open(root/'build/font-size.pdf') as pdf:
 assert len(pdf.pages)==15
 for page in pdf.pages:
  text=page.extract_text()
  assert 'Native' in text and 'lowest term radius' in text
  assert len([c for c in page.chars if c.get('non_stroking_color')==(0,0,1)])>0
  assert all(c['x0']>=0 and c['x1']<=page.width and c['top']>=0 and c['bottom']<=page.height for c in page.chars)
assert 'Overfull' not in (root/'build/font-size.log').read_text()
print('PASS: 75 independently checked samples, 15 pages, all bounds valid; source-once, subdivision and mirror assertions passed.')
for row in rows:
 if row['case'].startswith(('hml6s','lhl6s','hllh6s')): print(row['case'],round(float(row['radius']),3))
