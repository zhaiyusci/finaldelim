import re
import sys
from pathlib import Path
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream
with pdfplumber.open(sys.argv[1] if len(sys.argv)>1 else 'build/inline-interface-test.pdf') as pdf:
 chars=[dict(c,text=t) for p in pdf.pages for c in p.chars for t in c['text'] if t!=' ']
 text=''.join(c['text'] for c in chars)
 heads=list(re.finditer('Plain:|Rainbow:|EndComparisons:',text))
 assert len(heads)==3
 a,b=[chars[x.end():y.start()] for x,y in zip(heads,heads[1:])]
 assert ''.join(c['text'] for c in a)==''.join(c['text'] for c in b)
 dx,dy=b[0]['x0']-a[0]['x0'],b[0]['top']-a[0]['top']
 worst=0
 for x,y in zip(a,b):
  assert x['fontname']==y['fontname']
  for k in ('x0','x1','top','bottom','size'):
   shift=dx if k in ('x0','x1') else dy if k in ('top','bottom') else 0
   worst=max(worst,abs(y[k]-x[k]-shift))
 assert worst<.012,worst
 colored=[c for c in b if c['non_stroking_color'] not in (0,(0,),(0,0,0),None)]
 assert colored and all(c['text'] in '()[]{}|\u2223' for c in colored),[(c['text'],c['non_stroking_color']) for c in colored]
 assert len({str(c['non_stroking_color']) for c in colored})>=2
 print('PASS inline native/niji geometry, scripts, middle, color isolation; deviation',worst)
for name in ('inline-interface-test','native-interface-test'):
 reader=PdfReader('build/'+name+'.pdf')
 for page in reader.pages:
  assert not any(op in (b'W',b'W*') for args,op in ContentStream(page.get_contents(),reader).operations)
 log=Path('build/'+name+'.log').read_text()
 assert 'Overfull' not in log
aux=Path('build/inline-interface-test.aux').read_text()
assert r'\newlabel{eq:tag}{{{T}}' in aux and r'\newlabel{eq:auto}{{1}' in aux
aux=Path('build/native-interface-test.aux').read_text()
for key,value in [('one',1),('two',2),('matrix',3),('row',5)]:
 assert r'\newlabel{eq:'+key+'}{{'+str(value)+'}' in aux
print('PASS native equation/align labels, custom tags, notag and no clipping')
