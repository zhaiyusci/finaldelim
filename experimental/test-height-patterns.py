from pathlib import Path
import re
import pdfplumber
log=Path('build/height-patterns.log').read_text(errors='replace')
assert 'Overfull' not in log
rows={s:list(map(float,v.split())) for s,v in re.findall(r'PATTERN ([hl]{4}): ([0-9. ]+)',log)}
assert len(rows)==6
for s,v in rows.items():
 assert v==rows[s[::-1]],s
 if s!='lhhl': assert len(set(v))==1
with pdfplumber.open('build/height-patterns.pdf') as doc:
 assert len(doc.pages)==1
 c=doc.pages[0].chars
 assert sum(x['text']=='∑' for x in c)==48
 sums=[x for x in c if x['text']=='∑']
 assert len({(x['fontname'],round(x['size'],3)) for x in sums})==1
print('PASS: six patterns, mirrored policies, 48 identical tall-box sum glyphs, one page without overflow')
