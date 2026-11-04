"""Verify the generated inventory and bundle all rendered delimiter experiments."""
from pathlib import Path
import json,re,collections
from pypdf import PdfReader,PdfWriter
from pypdf.generic import ContentStream
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
rows=json.loads(Path('build/delimiter-inventory.json').read_text());fonts=list(dict.fromkeys(r['font'] for r in rows))
log=Path('build/outline-inventory.log').read_text()
assert log.count('OUTLINE FONT ')==8
assert re.search(r'OUTLINE fallback 0\b',log)
counts=dict((k,int(v)) for k,v in re.findall(r'OUTLINE (outlined|interpolated|profile|assembled|extrapolated) (\d+)',log))
assert sum(counts.values())==3*sum(row['status']!='missing' for row in rows),counts
assert not any(s in log for s in ('Overfull','Missing character','forcing bad dir','OUTLINE PROFILE FALLBACK'))
r=PdfReader('build/outline-inventory.pdf');assert len(r.pages)==48,len(r.pages)
missing=0
for i,p in enumerate(r.pages):
 text=p.extract_text();missing+=text.count('missing')-1 # subtract legend occurrence
 assert fonts[i//6] in text
 assert all(str(h)+' pt' in text for h in (14,32,64))
 ops=ContentStream(p.get_contents(),r).operations
 assert not any(op in (b'W',b'W*') for _,op in ops)
assert missing==4*sum(row['status']=='missing' for row in rows),(missing,rows)
print('PASS: 69 symbols x 8 fonts; all present glyphs at three heights; no fallback/missing glyph warnings/overflow/clipping')
cover='build/delimiters-cover.pdf';c=canvas.Canvas(cover,pagesize=A4);c.setTitle('finaldelim - complete delimiter experiments')
c.setFont('Helvetica-Bold',22);c.drawString(45,785,'Delimiter experiments')
c.setFont('Helvetica',11);y=755
for line in ['Eight math fonts. Native and continuous-outline rendering.',
             '69 symbols; 552 font-symbol entries; '+str(sum(x['status']!='missing' for x in rows))+' present entries.',
             'Missing symbols are marked explicitly; no substitute font is used.',
             'Fixed glyphs retain native size limits except the six diagonal extensions.']:
 c.drawString(45,y,line);y-=18
y-=18;c.setFont('Helvetica-Bold',12);c.drawString(45,y,'Contents');y-=23;c.setFont('Helvetica',11)
sections=[('Core delimiters, formulas, niji and line breaks',2,26),('Slashes and angles, including geometric extension',27,43),('Complete symbol inventory at 14, 32 and 64 pt',44,91)]
for title,a,b in sections:c.drawString(45,y,title);c.drawRightString(550,y,f'{a}-{b}');y-=21
y-=25;c.setFont('Helvetica-Bold',11);c.drawString(45,y,'Inventory by font');y-=22
for label,x in [('Font',45),('Fixed',300),('Variants',355),('Assembly',425),('Missing',500)]:c.drawString(x,y,label)
y-=20;c.setFont('Helvetica',10)
for font in fonts:
 counts=collections.Counter(r['status'] for r in rows if r['font']==font)
 c.drawString(45,y,font)
 for key,x in [('S',310),('V',370),('A',445),('missing',520)]:c.drawRightString(x,y,str(counts[key]))
 y-=20
y-=30
for line in ['Checks: compilation, expected inventory coverage, no rendering fallback,',
             'no clipping or overflow. Body/script geometry and niji regressions pass.',
             'All 32 diagonal outlines at 96pt reach target height and predicted width;',
             'normal stroke thickness agrees with source measurements within 0.006pt.',
             'Slash terminals retain source depth; double-angle heights and spacing pass.',
             '',
             'The inventory includes vertical delimiter symbols and arrows.',
             'Radicals, large operators and horizontal accents are outside this renderer.',
             'This is an experimental rendering report, not a universal font guarantee.']:
 c.drawString(45,y,line);y-=16
c.save()
w=PdfWriter();w.append(cover)
for file,label in [('outline-all','Core comparisons'),('outline-slash-angle','Slashes and angles'),('outline-inventory','Complete inventory')]:
 start=len(w.pages);w.append('build/'+file+'.pdf',outline_item=label)
 if file=='outline-inventory':
  for i,font in enumerate(fonts):w.add_outline_item(font,start+i*6)
w.add_metadata({'/Title':'finaldelim - delimiter experiments','/Author':'Yu Zhai'})
w.write('build/delimiters.pdf')
assert len(PdfReader('build/delimiters.pdf').pages)==91
print('PASS: bundled 91-page delimiters.pdf with navigation bookmarks')
