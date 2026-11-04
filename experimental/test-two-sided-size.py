from pathlib import Path
import re
import pdfplumber
log=Path('build/two-sided-size.log').read_text(errors='replace')
assert 'Overfull' not in log
rows={s:list(map(float,v.split())) for s,v in re.findall(r'TWOSIDE ([hml]+) ([0-9. ]+)',log)}
assert len(rows)==12
for s,v in rows.items():
    m=rows[s[::-1]]
    assert v[0]==m[1] and v[1]==m[0] and v[2:]==m[2:]
    assert v[3]<=v[2]<=max(v[:2])
assert rows['hhll'][2]<rows['hlhl'][2]<rows['hllh'][2]
with pdfplumber.open('build/two-sided-size.pdf') as doc:
    assert len(doc.pages)==2
    for page,n in zip(doc.pages,(24,48)):
        sums=[c for c in page.chars if c['text']=='∑']
        assert len(sums)==n
        assert len({(c['fontname'],round(c['size'],3)) for c in sums})==1
print('PASS: 12 patterns, mirrored estimates, ordered means, identical tall-glyph sizes, two pages without overflow')
