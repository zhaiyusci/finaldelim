from pathlib import Path
import pdfplumber
from pypdf import PdfReader
with pdfplumber.open('build/radical-comparison.pdf') as pdf:
 assert len(pdf.pages)==8
 for i in range(0,8,2):
  native=[c for c in pdf.pages[i].chars if c['top']>65]
  drawn=[c for c in pdf.pages[i+1].chars if c['top']>65]
  removed=[]
  for c in drawn:
   candidates=[(j,d) for j,d in enumerate(native) if c['text']==d['text'] and abs(c['x0']-d['x0'])<.03 and abs(c['top']-d['top'])<.03]
   assert candidates, (i,c['text'],c['x0'],c['top'])
   j,d=min(candidates,key=lambda jd:abs(c['x0']-jd[1]['x0'])+abs(c['top']-jd[1]['top']))
   assert abs(c['x1']-d['x1'])<.03 and abs(c['bottom']-d['bottom'])<.03
   assert c['non_stroking_color']==d['non_stroking_color']
   native.pop(j)
  assert native, 'No radical glyphs replaced'
  assert all(c['text'] in {'\u221a','\u23b7'} for c in native), 'Non-radical content disappeared'
  print('Font pair',i//2+1,'preserved body, degrees, scripts, integral glyphs and limits; replaced',repr(''.join(c['text'] for c in native)).encode('ascii','backslashreplace').decode())
log=Path('build/radical-comparison.log').read_text(errors='replace')
assert 'OUTLINE radical_fallback 0' in log
assert 'Missing character' not in log
assert 'Overfull' not in log
print('PASS: native box dimensions checked in TeX; four fonts; inline, nested, tall, indexed roots and color preserved.')
