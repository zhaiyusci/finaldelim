from pathlib import Path
import re
import pdfplumber
log=Path('build/natural-means.log').read_text(errors='replace')
assert 'Overfull' not in log and 'Markers changed' not in log
rows={s:list(map(float,v)) for s,*v in re.findall(r'NATURAL ([hml]+) left=([\d.]+) right=([\d.]+) geo=([\d.]+) arith=([\d.]+) rms=([\d.]+)',log.replace('\n',''))}
assert len(rows)==12,rows
for s,v in rows.items():
 m=rows[s[::-1]]
 assert abs(v[0]-m[1])<.001 and abs(v[1]-m[0])<.001
 assert v[2]<=v[3]+.001<=v[4]+.002<=max(v[:2])+.003
with pdfplumber.open('build/natural-means.pdf') as doc:
 assert len(doc.pages)==2
 sums=[]
 for p,count in zip(doc.pages,(30,60)):
  selected=[c for c in p.chars if c['text']=='∑']
  assert len(selected)==count
  sums.extend(selected)
 assert len({(c['fontname'],round(c['size'],3)) for c in sums})==1
print('PASS: natural body dimensions match unmarked TeX; 12 mirrored policies; 90 identical sum glyphs across two pages; no overflow')
