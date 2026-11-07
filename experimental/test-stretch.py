"""Native/drawn geometry, labels, nesting and colors for horizontal symbols."""
from pathlib import Path
import pdfplumber
from pypdf import PdfReader
with pdfplumber.open('build/stretch-comparison.pdf') as pdf:
 assert len(pdf.pages)==8
 for i in range(0,8,2):
  native=[c for c in pdf.pages[i].chars if c['top']>65]
  drawn=[c for c in pdf.pages[i+1].chars if c['top']>65]
  for c in drawn:
   candidates=[(j,d) for j,d in enumerate(native) if c['text']==d['text'] and abs(c['x0']-d['x0'])<.03 and abs(c['top']-d['top'])<.03]
   assert candidates,(i,c['text'],c['x0'],c['top'])
   j,d=min(candidates,key=lambda jd:abs(c['x0']-jd[1]['x0'])+abs(c['top']-jd[1]['top']))
   assert abs(c['x1']-d['x1'])<.03 and abs(c['bottom']-d['bottom'])<.03
   assert c['non_stroking_color']==d['non_stroking_color']
   native.pop(j)
  assert native,'No symbols replaced'
  # Every body/label letter survives; removed glyphs are symbol pieces only.
  for c in native:
   assert not c['text'].isalnum() or c['text'] in {'\u02c6','\u02dc'},(i,'Lost content',c['text'])
  print('PASS font pair',i//2+1,': body, labels, scripts, colors and rule-only examples unchanged')
log=Path('build/stretch-comparison.log').read_text(errors='replace')
for key in ('horizontal','accents','leader_arrows'):
 import re
 assert int(re.search(r'OUTLINE '+key+r' (\d+)',log)[1])>0
assert 'Missing character' not in log
assert 'Overfull' not in log
print('PASS: native dimensions asserted in TeX; font assemblies, accents and centered-leader arrows all drawn.')
