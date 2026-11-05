"""Independent quadrature and invariants for the folded measurement profile."""
import json, math
from pathlib import Path
profiles=[json.loads(x) for x in Path('build/folded-profiles.jsonl').read_text().splitlines()]
groups={}
for p in profiles:
 groups.setdefault(p['case'],[]).append(p)
 terms=p['terms']; low=min(t[2] for t in terms); high=max(t[2] for t in terms)
 if p['q']==0: expected=max(high,p['floor'])
 else:
  # Integrate on each profile/gap interval by midpoint quadrature, independently
  # of the Lua implementation's closed-form exponential integrals.
  cuts=sorted(set([0,p['width']]+[x for t in terms for x in t[:2]]))
  values=[]
  for at in p['positions']:
   numerator=denominator=0.0
   for a,b in zip(cuts,cuts[1:]):
    r=next((t[2] for t in terms if t[0]<=(a+b)/2<=t[1]),low)
    step=(b-a)/1000
    weight=sum(math.exp(-abs(a+(i+.5)*step-at)/p['lambda'])*step for i in range(1000))
    numerator+=(r/high)**p['q']*weight;denominator+=weight
   values.append(high*(numerator/denominator)**(1/p['q']))
  expected=max(max(values),p['floor'])
 assert abs(p['radius']-expected)<2, (p['case'],p['radius'],expected)
 assert p['radius']>=p['floor']
 for a,b,r,fold in terms:
  if fold: assert abs((b-a)/65536-({'large':0.2,'custom':5,'absolute':2}.get(p['case'],0.1)))<.001
for case in ['wide','manyrows','restored']:
 assert [p['radius'] for p in groups[case]]==[p['radius'] for p in groups['base']]
assert all(p['folds']==0 for p in groups['tworows'])
assert any(p['folds']==2 and len(p['positions'])==3 for p in groups['middle'])
assert all(p['folds']==1 for p in groups['base'])
print('PASS: independent quadrature, 0.01em width, endpoint floor, middle positions, two-row case, q=0, and width/row-count invariance.')
