from pathlib import Path
import re
import pdfplumber
log=Path('build/width-decay.log').read_text(errors='replace').replace('\n','')
assert 'Overfull' not in log and 'Markers changed' not in log
matches=re.findall(r'DECAY (\w+) (\d+) W=([\d.]+) H=([\d.]+) L=([\d.]+) fixed=([\d.]+) quarter=([\d.]+) half=([\d.]+) full=([\d.]+)',log)
assert len(matches)==9
rows={(s,int(n)):list(map(float,v)) for s,n,*v in matches}
for s in ('lhl','hml','hllh'):
 rs=[rows[s,n] for n in (1,3,6)]
 assert rs[0][0]<rs[1][0]<rs[2][0]
 assert len({(r[1],r[2]) for r in rs})==1
 for r in rs: assert r[4]<=r[5]<=r[6]
 if s=='hllh':
  for r in rs: assert all(abs(v-r[1])<.001 for v in r[3:])
assert rows['lhl',6][3]<5 and rows['lhl',6][5]>14
with pdfplumber.open('build/width-decay.pdf') as doc:
 assert len(doc.pages)==3
 all_sums=[]
 for p,count in zip(doc.pages,(12,12,24)):
  sums=[c for c in p.chars if c['text']=='∑']
  assert len(sums)==count
  all_sums.extend(sums)
 assert len({(c['fontname'],round(c['size'],3)) for c in all_sums})==1
print('PASS: nine natural-width cases; invariant heights and glyph sizes; width-dependent decay; hllh control; three pages without overflow')
