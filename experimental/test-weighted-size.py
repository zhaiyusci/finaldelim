import re
from pathlib import Path
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream
with pdfplumber.open('build/weighted-size-test.pdf') as pdf:
 chars=[dict(c,text=t) for page in pdf.pages for c in page.chars for t in c['text'] if t!=' ']
 text=''.join(c['text'] for c in chars)
 heads=list(re.finditer('PlainStart:|RainbowStart:|TallerStart:|FullStart:|EndChecks.',text))
 assert len(heads)==5
 parts=[chars[a.end():b.start()] for a,b in zip(heads,heads[1:])]
 a,b=parts[:2]
 assert ''.join(c['text'] for c in a)==''.join(c['text'] for c in b)
 dx,dy=b[0]['x0']-a[0]['x0'],b[0]['top']-a[0]['top']
 for x,y in zip(a,b):
  assert x['fontname']==y['fontname']
  for k in ('x0','x1','top','bottom','size'):
   shift=dx if k in ('x0','x1') else dy if k in ('top','bottom') else 0
   assert abs(y[k]-x[k]-shift)<.003,(x['text'],k)
 # Increasing only the middle row must not affect endpoint fence glyphs.
 for delim in ('[',']'):
  x=next(c for c in parts[1] if c['text']==delim)
  y=next(c for c in parts[2] if c['text']==delim)
  assert x['fontname']==y['fontname'] and abs(x['height']-y['height'])<.003
 colored=[c for c in parts[1] if c.get('non_stroking_color') not in (0,(0,),(0,0,0),None)]
 assert colored and all(c['text'] in ('[',']') for c in colored)
log=Path('build/weighted-size-test.log').read_text()
pairs=re.findall(r'WEIGHTED pair \d+: ([\d.]+)pt / ([\d.]+)pt',log)
assert len(pairs)==4 and pairs[0]==pairs[1]==pairs[2] and pairs[3]!=pairs[0]
for name in ('weighted-size-test','weighted-size-demo'):
 reader=PdfReader('build/'+name+'.pdf')
 for page in reader.pages:
  assert not any(op in (b'W',b'W*') for args,op in ContentStream(page.get_contents(),reader).operations)
 assert 'Overfull' not in Path('build/'+name+'.log').read_text()
print('PASS: rainbow preserves geometry; colors stay on fences; endpoint sizing ignores middle-row height; full mode differs; source-once and no clipping.')
