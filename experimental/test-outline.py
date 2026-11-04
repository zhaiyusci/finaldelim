from pathlib import Path
import re,unicodedata
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream
with pdfplumber.open('build/outline-test.pdf') as pdf:
 for i,tag in enumerate(['L','S','P','T','X','B','F','G']):
  chars=[dict(c,text=t) for c in pdf.pages[i].chars for t in unicodedata.normalize('NFKC',c['text']) if t!=' ']
  text=''.join(c['text'] for c in chars)
  a=text.index('Original'+tag+':')+len('Original'+tag+':');b=text.index('Drawn'+tag+':');c=text.index('End'+tag+':')
  orig=[v for v in chars[a:b] if v['text'] in 'abc+2j']
  drawn=[v for v in chars[b+len('Drawn'+tag+':'):c] if v['text'] in 'abc+2j']
  assert ''.join(v['text'] for v in orig)==''.join(v['text'] for v in drawn)=='a+bc2j'
  dx,dy=drawn[0]['x0']-orig[0]['x0'],drawn[0]['top']-orig[0]['top']
  for u,v in zip(orig,drawn):
   assert u['fontname']==v['fontname']
   for key,shift in [('x0',dx),('x1',dx),('top',dy),('bottom',dy)]:assert abs(v[key]-u[key]-shift)<.012,(tag,key,u,v)
 reader=PdfReader('build/outline-test.pdf')
 for page in reader.pages:
  ops=ContentStream(page.get_contents(),reader).operations
  assert not any(op in (b'W',b'W*') for _,op in ops)
 for page in pdf.pages[:8]:assert len(page.curves)>0
log=Path('build/outline-test.log').read_text()
assert 'OUTLINE ASSEMBLY DIMENSIONS AND SOURCE ASSERTIONS PASSED' in log
assert 'forcing bad dir' not in log
assert re.search(r'OUTLINE fallback 0\b',log)
assert r'\newlabel{outline:row}{{2}' in Path('build/outline-test.aux').read_text()
print('PASS: eight fonts: assembled boxes and body/script geometry unchanged; scope, source-once, labels, paths, no clipping; no native fallbacks')


with pdfplumber.open('build/outline-comparison.pdf') as pdf:
 for page in (pdf.pages[1],pdf.pages[3]):
  colors={tuple(c['non_stroking_color']) for c in page.curves}
  assert len(colors)==2,colors
  for c in page.chars:
   if unicodedata.normalize('NFKC',c['text']) in ('a','b','c','d','F','x','j','1','2'):
    assert c.get('non_stroking_color') in (0,0.0,(0,),(0,0,0),None),c
print('PASS: drawn paths inherit both nesting colors; ordinary formula glyphs remain black')

log=Path('build/outline-crossfont.log').read_text()
assert log.count('OUTLINE FONT ')==6
assert re.search(r'OUTLINE fallback 0\b',log)
assert 'Overfull' not in log
print('PASS: one runtime font-loading method, six fonts, no name-specific rules or native fallbacks in cross-font samples')


log=Path('build/outline-sans.log').read_text()
assert log.count('OUTLINE FONT ')==2
assert re.search(r'OUTLINE fallback 0\b',log)
assert 'Missing character' not in log and 'Overfull' not in log
with pdfplumber.open('build/outline-sans.pdf') as pdf:
 assert len(pdf.pages)==5
 for page in (pdf.pages[1],pdf.pages[3]):
  assert len({tuple(c['non_stroking_color']) for c in page.curves})==2
print('PASS: sans samples: two fonts, five pages, nested colors, no missing glyphs; no native fallbacks')
