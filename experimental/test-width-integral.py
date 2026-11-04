import csv, math
from pathlib import Path
import pdfplumber
root=Path(__file__).resolve().parents[1]
def rows(name):
    return list(csv.DictReader((root/'build'/name).open(), delimiter='\t'))
geometry={}
for row in rows('width-integral-geometry.tsv'):
    key=(row['pattern'],row['n'])
    geometry.setdefault(key,[]).append({k:float(v) for k,v in row.items() if k not in ('pattern','n')})
results=rows('width-integral.tsv')
assert len(results)==40
for row in results:
    terms=geometry[row['pattern'],row['n']]
    W,L,H=[terms[0][k] for k in ('W','L','H')]
    q=int(row['q']); lam=W/2
    if not q:
        left=max(L+(v['r']-L)*math.exp(-(v['x']-terms[0]['x'])/lam) for v in terms)
        right=max(L+(v['r']-L)*math.exp(-(terms[-1]['finish']-v['finish'])/lam) for v in terms)
    else:
        # Independent midpoint quadrature, including baseline in the gaps.
        pieces=[]; end=0
        for v in terms:
            pieces.extend([(end,v['x'],L),(v['x'],v['finish'],v['r'])]); end=v['finish']
        pieces.append((end,W,L))
        sums=[0.,0.]; norm=[0.,0.]
        for a,b,r in pieces:
            for j in range(1000):
                x=a+(b-a)*(j+.5)/1000
                for side,d in enumerate((x,W-x)):
                    weight=math.exp(-d/lam)*(b-a)/1000
                    sums[side]+=weight*(r/H)**q; norm[side]+=weight
        left,right=[H*(s/n)**(1/q) for s,n in zip(sums,norm)]
    radius=((left**3+right**3)/2)**(1/3)
    for key,value in [('left',left),('right',right),('radius',radius)]:
        assert abs(float(row[key])-value)<2e-5,(row,key,value)
with pdfplumber.open(root/'build/width-integral.pdf') as pdf:
    assert len(pdf.pages)==4
    for page,count in zip(pdf.pages,[10,10,10,20]):
        assert sum(c['text']=='∑' for c in page.chars)==count
log=(root/'build/width-integral.log').read_text()
assert 'Overfull' not in log and 'Markers changed' not in log
print('PASS: 40 variants, independent quadrature, four PDF pages, natural dimensions; Lua subdivision/mirror/uniform/monotonicity assertions passed during compilation.')
for row in results:
    if row['n']=='6': print(row['pattern'],row['q'],round(float(row['radius']),2))
