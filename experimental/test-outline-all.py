from pathlib import Path
import re
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream
log=Path('build/outline-all.log').read_text()
assert log.count('OUTLINE FONT ')==8
assert re.search(r'OUTLINE fallback 0\b',log)
assert not any(x in log for x in ['Overfull','Missing character','forcing bad dir','OUTLINE PROFILE FALLBACK'])
with pdfplumber.open('build/outline-all.pdf') as pdf:
 assert len(pdf.pages)==25,len(pdf.pages)
 for i in range(8):
  for page in pdf.pages[1+3*i:4+3*i]:
   assert page.curves
  page=pdf.pages[3+3*i]
  colors={tuple(c['non_stroking_color']) for c in page.curves}
  assert len(colors)==2,(i,colors)
  text=page.extract_text()
  assert f'({2*i+1})' in text and f'({2*i+2})' in text
reader=PdfReader('build/outline-all.pdf')
for page in reader.pages:
 assert not any(op in (b'W',b'W*') for _,op in ContentStream(page.get_contents(),reader).operations)
print('PASS: unified 25-page collection, 8 fonts, all delimiter pairs/heights, nested colors, row numbering, no fallback/missing glyphs/overflow/clipping')
