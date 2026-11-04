"""Measure diagonal delimiter outlines at 10pt; no renderer changes."""
import sys,subprocess,json,csv
from pathlib import Path
sys.path.insert(0,str(Path('build/fit-deps').resolve()))
import numpy as np
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
class Flat(BasePen):
 def __init__(self,gs):super().__init__(gs);self.cs=[]
 def _moveTo(self,p):self.p=[np.array(p,float)]
 def _lineTo(self,p):self.p.append(np.array(p,float))
 def _curveToOne(self,a,b,c):
  p=self.p[-1];a,b,c=map(np.array,(a,b,c))
  for t in np.linspace(0,1,129)[1:]:self.p.append((1-t)**3*p+3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3*c)
 def _qCurveToOne(self,a,b):
  p=self.p[-1];a,b=map(np.array,(a,b))
  for t in np.linspace(0,1,129)[1:]:self.p.append((1-t)**2*p+2*(1-t)*t*a+t*t*b)
 def _closePath(self):self.cs.append(np.array(self.p+[self.p[0]]))
 def _endPath(self):self._closePath()
files=['latinmodern-math.otf','STIXTwoMath-Regular.otf','texgyrepagella-math.otf','texgyretermes-math.otf','XITSMath-Regular.otf','LibertinusMath-Regular.otf','FiraMath-Regular.otf','GFSNeohellenicMath.otf']
names=['LM','STIX2','Pagella','Termes','XITS','Libertinus','Fira','GFS']
records=[];summary=[]
for name,file in zip(names,files):
 f=TTFont(subprocess.check_output(['kpsewhich',file],text=True).strip());gs=f.getGlyphSet();scale=10/f['head'].unitsPerEm
 v=f['MATH'].table.MathVariants;vc=dict(zip(v.VertGlyphCoverage.glyphs,v.VertGlyphConstruction));cm=f.getBestCmap()
 for kind,code in [('slash',47),('backslash',92),('langle',0x27e8),('rangle',0x27e9)]:
  base=cm[code];con=vc.get(base);glyphs=list(dict.fromkeys([base]+([x.VariantGlyph for x in con.MathGlyphVariantRecord] if con else [])))
  rows=[]
  for glyph in glyphs:
   p=Flat(gs);gs[glyph].draw(p);cs=[c*scale for c in p.cs];pts=np.vstack(cs);lo=pts.min(axis=0);hi=pts.max(axis=0);H=hi[1]-lo[1];W=hi[0]-lo[0]
   ys=lo[1]+H*np.linspace(.60,.85,51);centres=[];thickness=[]
   for y in ys:
    xs=[]
    for c in cs:
     a,b=c[:-1],c[1:];m=((a[:,1]<=y)&(b[:,1]>y))|((b[:,1]<=y)&(a[:,1]>y));a,b=a[m],b[m]
     xs.extend(a[:,0]+(y-a[:,1])*(b[:,0]-a[:,0])/(b[:,1]-a[:,1]))
    xs=sorted(xs);assert len(xs)==2,(name,kind,glyph,len(xs));centres.append(sum(xs)/2);thickness.append(xs[1]-xs[0])
   slope,intercept=np.polyfit(ys,centres,1);thick=float(np.median(thickness)/np.sqrt(1+slope*slope))
   row=dict(font=name,kind=kind,glyph=glyph,height=H,width=W,slope=abs(float(slope)),thickness=thick,straight_error=float(np.max(np.abs(np.array(centres)-(slope*ys+intercept)))))
   records.append(row);rows.append(row)
  rows.sort(key=lambda r:r['height']);last=rows[-1]
  item=dict(font=name,kind=kind,count=len(rows),assembly=bool(con and con.GlyphAssembly),max_height=last['height'],max_width=last['width'],last_slope=last['slope'],last_thickness=last['thickness'])
  if len(rows)>1:
   prev=rows[-2];item['previous_width']=prev['width'];item['previous_height']=prev['height'];item['previous_thickness']=prev['thickness']
   item['width_derivative']=(last['width']-prev['width'])/(last['height']-prev['height'])
  if len(rows)>=4:
   train=rows[-4:-1];hs=[r['height'] for r in train];ws=[r['width'] for r in train];m,b=np.polyfit(hs,ws,1)
   item['heldout_width_errors']={'fixed_width':abs(train[-1]['width']-last['width']),'proportional':abs(train[-1]['width']*last['height']/train[-1]['height']-last['width']),'linear_last3':abs(m*last['height']+b-last['width'])}
  summary.append(item)
Path('build/diagonal-measurements.json').write_text(json.dumps(dict(records=records,summary=summary),indent=2))
with open('build/diagonal-measurements.csv','w',newline='') as out:
 w=csv.DictWriter(out,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
for r in summary:
 if r['kind'] in ('slash','langle'):print(json.dumps(r))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig,axes=plt.subplots(2,3,figsize=(13,7))
for i,kind in enumerate(('slash','langle')):
 for name in names:
  rows=sorted([r for r in records if r['font']==name and r['kind']==kind],key=lambda r:r['height'])
  for j,key in enumerate(('width','slope','thickness')):axes[i,j].plot([r['height'] for r in rows],[r[key] for r in rows],'.-',label=name)
 for j,label in enumerate(('Ink width (pt)','Arm dx/dy','Normal stroke thickness (pt)')):
  axes[i,j].set(xlabel='Ink height at 10pt font size (pt)',ylabel=label,title=kind);axes[i,j].grid(alpha=.2)
axes[0,0].legend(ncol=2,fontsize=8);fig.tight_layout();fig.savefig('build/diagonal-measurements.png',dpi=150)
