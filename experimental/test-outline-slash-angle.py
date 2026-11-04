from pathlib import Path
from PIL import Image
import re
from pypdf import PdfReader
from pypdf.generic import ContentStream
log=Path('build/outline-slash-angle.log').read_text()
assert log.count('OUTLINE FONT ')==8
assert re.search(r'OUTLINE fallback 0\b',log)
assert not any(s in log for s in ('Missing character','Overfull','forcing bad dir'))
r=PdfReader('build/outline-slash-angle.pdf');assert len(r.pages)==17
for p in r.pages[1:9]:
 text=p.extract_text()
 for h in (10,14,18,24,32,48,64,96):assert f'{h} pt' in text
 ops=ContentStream(p.get_contents(),r).operations
 assert any(op==b'f' for _,op in ops)
 assert not any(op in (b'W',b'W*') for _,op in ops)
print('PASS: eight fonts, all eight target heights, vector paths, no fallback/missing glyphs/overflow/clipping')
for group,pages in enumerate(([1,3,4,5],[6,7,8,9])):
 canvas=Image.new('RGB',(1100,1556),'white')
 for j,n in enumerate(pages):
  im=Image.open(f'build/outline-slash-angle-{n}.png');im.thumbnail((550,778))
  canvas.paste(im,((j%2)*550,(j//2)*778))
 canvas.save(f'build/slash-review-{group}.png')

# Inspect actual exported contours at 96pt, independently of renderer counters.
import json, math, statistics
import pdfplumber
measure=json.loads(Path('build/diagonal-measurements.json').read_text())
names=['LM','STIX2','Pagella','Termes','XITS','Libertinus','Fira','GFS']
kinds=['slash','backslash','langle','rangle'];pt_to_bp=72/72.27
with pdfplumber.open('build/outline-slash-angle.pdf') as pdf:
 for page,name in zip(pdf.pages[1:9],names):
  for curve,kind in zip(page.curves[-4:],kinds):
   rows=sorted([r for r in measure['records'] if r['font']==name and r['kind']==kind],key=lambda r:r['height'])
   last=rows[-1];recent=rows[-3:]
   growth=max(0,statistics.linear_regression([r['height'] for r in recent],[r['width'] for r in recent]).slope) if len(recent)>1 else last['slope']*(.5 if 'angle' in kind else 1)
   expected=last['width']+growth*(96-last['height'])
   assert abs(curve['height']/pt_to_bp-96)<.002,(name,kind,'height')
   assert abs(curve['width']/pt_to_bp-expected)<.006,(name,kind,'width')
   pts=curve['pts'];segments=list(zip(pts,pts[1:]+pts[:1]))
   ys=[];centres=[];widths=[]
   for i in range(33):
    y=curve['top']+curve['height']*(.15+.25*i/32);hits=[]
    for (x0,y0),(x1,y1) in segments:
     if (y0<=y<y1) or (y1<=y<y0):hits.append(x0+(y-y0)*(x1-x0)/(y1-y0))
    assert len(hits)==2,(name,kind,len(hits))
    ys.append(y);centres.append(sum(hits)/2);widths.append(abs(hits[1]-hits[0]))
   slope=statistics.linear_regression(ys,centres).slope
   thickness=statistics.median(widths)/math.sqrt(1+slope*slope)/pt_to_bp
   assert abs(thickness-last['thickness'])<.006,(name,kind,thickness,last['thickness'])
assert int(re.search(r'OUTLINE extrapolated (\d+)',log).group(1))>0
print('PASS: all 32 exported 96pt contours reach target height/width and retain largest-glyph normal stroke thickness (0.006pt tolerance)')
