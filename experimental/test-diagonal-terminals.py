"""Independent cap and double-stroke checks against source font geometry."""
from pathlib import Path
import sys,json,math,statistics,subprocess
sys.path.insert(0,'build/fit-deps')
import pdfplumber
from fontTools.ttLib import TTFont
# Reuse only the font contour reader, not its measurements or renderer equations.
ns={};exec(Path('experimental/measure-diagonals.py').read_text().split('files=')[0],ns)
Flat=ns['Flat']
files=['latinmodern-math.otf','STIXTwoMath-Regular.otf','texgyrepagella-math.otf','texgyretermes-math.otf','XITSMath-Regular.otf','LibertinusMath-Regular.otf','FiraMath-Regular.otf','GFSNeohellenicMath.otf']
pt=72/72.27

def hits(paths,y):
 xs=[]
 for points in paths:
  for (x0,y0),(x1,y1) in zip(points,points[1:]+points[:1]):
   if y0<=y<y1 or y1<=y<y0:xs.append(x0+(y-y0)*(x1-x0)/(y1-y0))
 return sorted(xs)

def cap_length(paths):
 low=min(y for p in paths for x,y in p);high=max(y for p in paths for x,y in p)
 def width(z):
  xs=hits(paths,z)
  return xs[-1]-xs[0] if len(xs)>=2 else 0
 full=width(low+.25*(high-low))
 a,b=low,low+.2*(high-low)
 for _ in range(50):
  m=(a+b)/2
  if width(m)<.9*full:a=m
  else:b=m
 return (a+b)/2-low

def source(font,code):
 gs=font.getGlyphSet();base=font.getBestCmap()[code];v=font['MATH'].table.MathVariants
 names=[base]
 if base in v.VertGlyphCoverage.glyphs:
  con=v.VertGlyphConstruction[v.VertGlyphCoverage.glyphs.index(base)]
  names+= [r.VariantGlyph for r in con.MathGlyphVariantRecord]
 shapes=[]
 for name in dict.fromkeys(names):
  p=Flat(gs);gs[name].draw(p)
  # PDF coordinates have y increasing downward.
  paths=[[(float(x)*10/font['head'].unitsPerEm,-float(y)*10/font['head'].unitsPerEm) for x,y in c] for c in p.cs]
  height=max(y for c in paths for x,y in c)-min(y for c in paths for x,y in c)
  shapes.append((height,paths))
 return max(shapes,key=lambda x:x[0])

def pdf_paths(curves):return [[(x/pt,y/pt) for x,y in c['pts']] for c in curves]

with pdfplumber.open('build/outline-slash-angle.pdf') as pdf:
 for i,file in enumerate(files):
  f=TTFont(subprocess.check_output(['kpsewhich',file],text=True).strip())
  for j,code in enumerate((47,92)):
   _,paths=source(f,code);expected=cap_length(paths)
   actual=cap_length(pdf_paths([pdf.pages[i+1].curves[-4+j]]))
   assert abs(actual-expected)<.012,(file,code,'cap',actual,expected)
   if i==6:print('Fira cap, source / drawn (pt):',round(expected,4),round(actual,4))
  page=pdf.pages[9+i]
  # A compound path is exposed as two curves by pdfplumber, one per stroke.
  assert len(page.curves)==16,(file,len(page.curves))
  for row,H in enumerate((32,64,96,144)):
   for j,code in enumerate((0x27ea,0x27eb)):
    originalH,paths=source(f,code)
    if H<=originalH:continue
    curves=page.curves[row*4+j*2:row*4+j*2+2]
    drawn=pdf_paths(curves)
    lo=min(y for p in drawn for x,y in p);hi=max(y for p in drawn for x,y in p)
    assert abs(hi-lo-H)<.003,(file,code,H,hi-lo)
    # Compare horizontal stroke-center separation well away from ends and vertex.
    smin=min(y for p in paths for x,y in p);smax=max(y for p in paths for x,y in p)
    s=hits(paths,smin+.25*(smax-smin));d=hits(drawn,lo+.25*(hi-lo))
    assert len(s)==len(d)==4,(file,code,len(s),len(d))
    sg=(s[2]+s[3]-s[0]-s[1])/2;dg=(d[2]+d[3]-d[0]-d[1])/2
    assert abs(sg-dg)<.04,(file,code,H,'separation',sg,dg)
print('PASS: original slash terminal depth retained; double angles reach target heights and preserve stroke-center separation')
