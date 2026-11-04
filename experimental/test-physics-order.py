import pdfplumber
from pathlib import Path
with pdfplumber.open('build/physics-compat.pdf') as a,pdfplumber.open('build/physics-after.pdf') as b:
 assert len(a.pages)==len(b.pages)==4
 for i,(p,q) in enumerate(zip(a.pages,b.pages),1):
  assert len(p.chars)==len(q.chars) and len(p.curves)==len(q.curves)
  for x,y in zip(p.chars,q.chars):
   assert x['text']==y['text']
   assert all(abs(x[k]-y[k])<.001 for k in ('x0','x1','top','bottom'))
  for x,y in zip(p.curves,q.curves):
   assert all(abs(x[k]-y[k])<.001 for k in ('x0','x1','top','bottom'))
   assert x['non_stroking_color']==y['non_stroking_color']
  colors=[c for c in p.curves if c['non_stroking_color'] not in (0,(0,),(0,0,0),None)]
  print('Page',i,':',len(p.curves),'paths;',len(colors),'colored paths')
 print('PASS: both loading orders give identical sample geometry and colors')
