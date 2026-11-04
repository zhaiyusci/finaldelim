import json,unicodedata as u
from pathlib import Path
import pdfplumber
from pypdf import PdfWriter
rows=json.loads(Path('build/physics-results.json').read_text())
rows=list({(r['name'],r['context'],r['niji']):r for r in rows}.values())
failed={(r['name'],r['context'],r['niji']) for r in rows if not r['ok']}
assert failed=={('dv','inline',True),('sin','inline',True),('mqty','equation',False),('mqty','equation',True)},failed
print(len(rows),'unique compile probes;',len(failed),'expected incompatibilities')
for name in ('qty','bqty','norm','braket','matrixel','explicit'):
 with pdfplumber.open('build/physics-probes/'+name+'-equation-1.pdf') as pdf:
  colors=[c for c in pdf.pages[0].curves if c['non_stroking_color'] not in (0,(0,),(0,0,0),None)]
  assert bool(colors)==(name=='explicit'),(name,len(colors))
for name,breaks in [('break-qty',True),('break-bqty',False),('break-explicit',True)]:
 with pdfplumber.open('build/physics-probes/'+name+'-equation-1.pdf') as pdf:
  chars={u.normalize('NFKC',c['text']):c for c in pdf.pages[0].chars}
  dy=abs(chars['b']['y0']-chars['a']['y0'])
  assert (dy>10)==breaks,(name,dy)
print('Confirmed: hidden display fences lack niji; braced bqty ignores the requested break')
w=PdfWriter()
w.append('build/physics-compat.pdf',outline_item='Commands, niji, and equation environments')
w.append('build/physics-weighting.pdf',outline_item='Effect of macro grouping on weighted sizing')
with open('build/physics-compatibility.pdf','wb') as f:w.write(f)
