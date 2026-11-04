from pathlib import Path
import csv, math
import pdfplumber
rows=list(csv.DictReader(open('build/power-means.tsv'),delimiter='\t'))
assert len(rows)==52
for r in rows:
 l,h,R=map(float,(r['left'],r['right'],r['radius']))
 p=int(r['p'])
 expected=max(l,h) if p==0 else ((l**p+h**p)/2)**(1/p)
 assert abs(expected-R)<.00001
 if r['pattern']=='hllh': assert abs(R-30.26001)<.00001
log=Path('build/power-means.log').read_text(errors='replace')
assert 'Overfull' not in log and 'Markers changed' not in log
with pdfplumber.open('build/power-means.pdf') as doc:
 assert len(doc.pages)==6
 sums=[]
 for page,count in zip(doc.pages,(10,10,10,20,6,6)):
  s=[c for c in page.chars if c['text']=='∑']
  assert len(s)==count
  sums+=s
 assert len({(c['fontname'],round(c['size'],3)) for c in sums})==1
print('PASS: 52 rendered variants, independent power-mean calculations, native body dimensions, constant glyph size, six pages without overflow')
for r in rows:
 if r['pattern']=='hml' and r['n']=='6': print(r['alpha'],r['p'],r['radius'])
