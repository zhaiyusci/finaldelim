"""Compile probes first, then verify geometry, color, real breaks and numbering."""
import json,re,unicodedata as ud
from pathlib import Path
import pdfplumber
from pypdf import PdfWriter
cases=json.loads(Path('experimental/physics-cases.json').read_text())
base=Path('build/physics-probes')
def colored(c):return c['non_stroking_color'] not in (0,(0,),(0,0,0),None)
def compare(a,b):
 assert ''.join(c['text'] for c in a)==''.join(c['text'] for c in b)
 dx,dy=b[0]['x0']-a[0]['x0'],b[0]['top']-a[0]['top']
 assert max(abs(y[k]-x[k]-(dx if k=='x0' else dy)) for x,y in zip(a,b) for k in ('x0','top'))<.015
count=0
for name,_ in cases:
 contexts=['equation'] if name.startswith('break') else ['inline','equation']
 for context in contexts:
  for flag in [0,1]:
   job=f'{name}-{context}-{flag}';log=(base/(job+'.log')).read_text(errors='replace')
   assert 'Output written on '+job+'.pdf' in log,job
   assert 'Missing character' not in log and 'Overfull' not in log,job
   count+=1
   with pdfplumber.open(base/(job+'.pdf')) as pdf:
    p=pdf.pages[0]
    assert all(not colored(c) for c in p.chars if ud.normalize('NFKC',c['text']).isalnum()),job
    if not flag:assert not any(colored(c) for c in p.curves),job
    if flag and name in ('qty','bqty','norm','nested','dv','sin','braket','matrixel','explicit','mqty'):
     assert any(colored(c) for c in p.curves),job
  if not name.startswith('break'):
   with pdfplumber.open(base/f'{name}-inline-0.pdf') as a,pdfplumber.open(base/f'{name}-equation-0.pdf') as b:
    compare(a.pages[0].chars,b.pages[0].chars)
  with pdfplumber.open(base/f'{name}-{context}-0.pdf') as a,pdfplumber.open(base/f'{name}-{context}-1.pdf') as b:
   compare(a.pages[0].chars,b.pages[0].chars)
for name in ('break-qty','break-bqty','break-explicit','break-nested'):
 for flag in [0,1]:
  with pdfplumber.open(base/f'{name}-equation-{flag}.pdf') as pdf:
   cs={ud.normalize('NFKC',c['text']):c for c in pdf.pages[0].chars}
   assert abs(cs['b']['y0']-cs['a']['y0'])>10,name
for suffix in ('','-after'):
 log=Path('build/physics-regression'+suffix+'.log').read_text(errors='replace')
 assert 'PHYSICS SOURCE ONCE PASSED' in log
 aux=Path('build/physics-regression'+suffix+'.aux').read_text()
 for label,num in [('one',1),('two',3),('matrix',4)]:
  assert r'\newlabel{ph:'+label+'}{{'+str(num)+'}' in aux
with pdfplumber.open('build/physics-regression.pdf') as a,pdfplumber.open('build/physics-regression-after.pdf') as b:
 compare(a.pages[0].chars,b.pages[0].chars)
 colors={tuple(c['non_stroking_color']) for c in a.pages[0].curves if isinstance(c['non_stroking_color'],tuple)}
 assert {(1,0,0),(0,0,1)}<=colors,colors
 assert any(abs(c[1]-.447)<.002 for c in colors if len(c)==3),colors
metrics=re.findall(r'WEIGHTED pair \d+: ([\d.]+)pt / ([\d.]+)pt',Path('build/physics-weighting.log').read_text())
assert len(metrics)==6 and len(set(metrics))==1,metrics
print(f'PASS: {count} compilation probes; inline/display geometry, niji, real breaks, matrix isolation, both load orders, local palette, labels, source once, transparent measurement')
w=PdfWriter();w.append('build/physics-compat.pdf',outline_item='Commands and colors')
w.append('build/physics-weighting.pdf',outline_item='Equivalent weighted sizing')
w.append('build/physics-regression.pdf',outline_item='Nested breaks and matrices')
with open('build/physics-compatibility.pdf','wb') as f:w.write(f)
