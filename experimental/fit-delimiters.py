"""Fit font contours, not screenshots. Run from finaldelim project root."""
import sys, json, csv
from pathlib import Path
sys.path.insert(0,str(Path('build/fit-deps').resolve()))
import numpy as np
from scipy.optimize import least_squares
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.patches import Polygon
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
FONTS={'Latin Modern Math':'c:/texlive/2026/texmf-dist/fonts/opentype/public/lm-math/latinmodern-math.otf',
       'STIX Two Math':'c:/texlive/2026/texmf-dist/fonts/opentype/public/stix2-otf/STIXTwoMath-Regular.otf'}
class Flatten(BasePen):
 def __init__(self,gs): super().__init__(gs);self.contours=[];self.cur=[]
 def _moveTo(self,p):self.cur=[np.array(p,float)]
 def _lineTo(self,p):self.cur.append(np.array(p,float))
 def _curveToOne(self,a,b,c):
  p=self.cur[-1];a,b,c=map(lambda v:np.array(v,float),(a,b,c))
  for t in np.linspace(0,1,81)[1:]:self.cur.append((1-t)**3*p+3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3*c)
 def _qCurveToOne(self,a,b):
  p=self.cur[-1];a,b=np.array(a,float),np.array(b,float)
  for t in np.linspace(0,1,81)[1:]:self.cur.append((1-t)**2*p+2*(1-t)*t*a+t*t*b)
 def _closePath(self):
  if len(self.cur):self.contours.append(np.array(self.cur+[self.cur[0]]));self.cur=[]
 def _endPath(self):self._closePath()
fonts={n:TTFont(p) for n,p in FONTS.items()}
rows=[json.loads(x) for x in Path('build/delimiter-outlines.jsonl').read_text().splitlines()]
def contours(row):
 f=fonts[row['font']];gs=f.getGlyphSet();result=[]
 for g in row['glyphs']:
  pen=Flatten(gs);gs[f.getGlyphName(g['index'])].draw(pen)
  for c in pen.contours:result.append(c*g['size']/f['head'].unitsPerEm+np.array([g['x'],g['y']]))
 return result

def segments(cs):
 return np.vstack([c[:-1] for c in cs]),np.vstack([c[1:] for c in cs])
def section(cs,y):
 intervals=[]
 for c in cs:
  a,b=c[:-1],c[1:];m=((a[:,1]<=y)&(b[:,1]>y))|((b[:,1]<=y)&(a[:,1]>y))
  a,b=a[m],b[m];xs=sorted(a[:,0]+(y-a[:,1])*(b[:,0]-a[:,0])/(b[:,1]-a[:,1]))
  intervals.extend(zip(xs[::2],xs[1::2]))
 merged=[]
 for a,b in sorted(intervals):
  if merged and a<=merged[-1][1]+1e-8:merged[-1][1]=max(merged[-1][1],b)
  else:merged.append([a,b])
 return merged

def shape(p,y,H):
 x0,A,t0,f,k,gamma=p
 u=np.clip((np.abs(y)/(H/2)-f)/(1-f),0,1)
 outer=x0+A*(1-np.maximum(0,1-u**k)**(1/k))
 inner=outer+t0*np.maximum(0,1-u*u)**gamma
 return outer,inner

def fitted_polygon(p,H):
 y=np.linspace(-H/2,H/2,601);a,b=shape(p,y,H)
 return np.column_stack([np.r_[a,b[::-1]],np.r_[y,y[::-1]]])
records=[]
for row in rows:
 if row['delimiter']!='(':continue
 cs=contours(row);pts=np.vstack(cs);lo,hi=pts[:,1].min(),pts[:,1].max();H=hi-lo;mid=(hi+lo)/2
 xmin=pts[:,0].min();cs=[c-np.array([xmin,mid]) for c in cs]
 y=np.linspace(-.995*H/2,.995*H/2,301)
 spans=[section(cs,z) for z in y];left=np.array([v[0][0] for v in spans]);right=np.array([v[-1][1] for v in spans])
 width=max(right);t0=np.median((right-left)[np.abs(y)<H*.1])
 def residual(p):
  a,b=shape(p,y,H);return np.r_[a-left,b-right]
 best=None
 for flat in [0,.3,.65]:
  result=least_squares(residual,[0,width,t0,flat,2,.5],bounds=([-.4,.1,.05,0,1.1,.05],[.4,2*width,3,.95,5,2]),max_nfev=1200)
  if best is None or np.linalg.norm(result.fun)<np.linalg.norm(best.fun):best=result
 rec=dict(font=row['font'],target=row['target'],height=H,glyph_count=len(row['glyphs']),parameters=best.x.tolist(),rms_pt=float(np.sqrt(np.mean(best.fun**2))),max_pt=float(max(abs(best.fun))))
 records.append((rec,cs,y,left,right))

# Hold out alternating atlas sizes: interpolate model parameters using actual ink height.
train_targets={10,18,30,48,80}
for name in fonts:
 subset=[r for r in records if r[0]['font']==name];train=[r[0] for r in subset if r[0]['target'] in train_targets]
 for rec,cs,y,left,right in subset:
  if rec['target'] not in train_targets:
   pred=np.array([np.interp(rec['height'],[r['height'] for r in train],[r['parameters'][j] for r in train]) for j in range(6)])
   a,b=shape(pred,y,rec['height']);rec['holdout_rms_pt']=float(np.sqrt(np.mean(np.r_[a-left,b-right]**2)))
   rec['predicted_parameters']=pred.tolist()
Path('build/delimiter-fit.json').write_text(json.dumps([r[0] for r in records],indent=2))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
with PdfPages('build/delimiter-fit.pdf') as pdf:
 for name in fonts:
  fig,axs=plt.subplots(3,3,figsize=(11.7,8.3));fig.suptitle(name+' — native contours and fitted continuous parentheses',fontsize=15)
  for ax,(r,cs,y,left,right) in zip(axs.flat,[r for r in records if r[0]['font']==name]):
   for c in cs:ax.add_patch(Polygon(c,facecolor='.8',edgecolor='none'))
   p=r['parameters'];ax.plot(*fitted_polygon(p,r['height']).T,color='#0072b2',lw=.8,label='fit')
   if 'predicted_parameters' in r:ax.plot(*fitted_polygon(r['predicted_parameters'],r['height']).T,color='#d55e00',lw=.8,ls='--')
   ax.set_aspect('equal');ax.set_xlim(-1,11);ax.set_ylim(-r['height']/2-1,r['height']/2+1);ax.axis('off')
   extra=('; held-out %.3f pt'%r['holdout_rms_pt']) if 'holdout_rms_pt' in r else ''
   ax.set_title('Request %d; actual %.2f pt; %d glyphs\nfit RMS %.3f pt%s'%(r['target'],r['height'],r['glyph_count'],r['rms_pt'],extra),fontsize=8)
  fig.text(.5,.025,'Gray: original outlines. Blue: individual fit. Orange dashed: prediction from other heights. Each panel uses equal x/y scaling.',ha='center',fontsize=9)
  fig.subplots_adjust(top=.88,bottom=.09,hspace=.42);pdf.savefig(fig);plt.close(fig)
 # The double bar is a construction problem: compare contours and their measured cross sections.
 fig,axs=plt.subplots(1,3,figsize=(11.7,8.3));fig.suptitle('STIX Two Math: 64 pt double bar — original outlines versus two continuous rules',fontsize=14)
 row=next(r for r in rows if r['font']=='STIX Two Math' and r['delimiter']=='double' and r['target']==64)
 cs=contours(row);pts=np.vstack(cs);low,high=pts[:,1].min(),pts[:,1].max();mid=(high+low)/2
 cs=[c-np.array([0,mid]) for c in cs];ys=np.linspace(-31.99,31.99,2400)
 intervals=[section(cs,y) for y in ys];assert all(len(v)==2 for v in intervals)
 widths=np.array([[b-a for a,b in v] for v in intervals]);centers=np.array([[(a+b)/2 for a,b in v] for v in intervals])
 thickness=float(np.median(widths));cx=np.median(centers,axis=0)
 for c in cs:axs[0].add_patch(Polygon(c,color='black',linewidth=0))
 for x in cx:axs[1].add_patch(Polygon([[x-thickness/2,-32],[x+thickness/2,-32],[x+thickness/2,32],[x-thickness/2,32]],color='black',linewidth=0))
 for ax,title in zip(axs[:2],['Original: 8 glyph components','Two filled rectangles; no component joints']):
  ax.set_aspect('equal');ax.set_xlim(-3,7);ax.set_ylim(-34,34);ax.axis('off');ax.set_title(title,fontsize=10)
 axs[2].plot(widths[:,0],ys,color='#0072b2',lw=1);axs[2].axvline(thickness,color='#d55e00',ls='--');axs[2].set_xlabel('Actual outline stroke width (pt)');axs[2].set_ylabel('Height (pt)');axs[2].set_title('Horizontal sections through the left stroke')
 fig.text(.5,.035,'Median thickness %.4f pt; range %.4f–%.4f pt; centre spacing %.4f pt. Measurements are from vector outlines, not pixels.'%(thickness,widths.min(),widths.max(),cx[1]-cx[0]),ha='center',fontsize=10)
 fig.subplots_adjust(top=.88,bottom=.12,wspace=.4);pdf.savefig(fig);plt.close(fig)
 Path('build/double-bar-fit.json').write_text(json.dumps(dict(thickness_pt=thickness,min_pt=float(widths.min()),max_pt=float(widths.max()),spacing_pt=float(cx[1]-cx[0])),indent=2))
print('Double-bar outline widths:',widths.min(),thickness,widths.max(),'spacing:',cx[1]-cx[0])
for name in fonts:
 rr=[r[0] for r in records if r[0]['font']==name]
 print(name,'individual RMS range:',min(r['rms_pt'] for r in rr),max(r['rms_pt'] for r in rr),'held-out RMS:',[(r['target'],round(r['holdout_rms_pt'],4)) for r in rr if 'holdout_rms_pt' in r])
