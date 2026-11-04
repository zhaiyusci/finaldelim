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
# Read every distinct prebuilt left-parenthesis variant directly from MATH.
# GlyphAssembly is deliberately never read or used.
records=[]
for name,font in fonts.items():
 variants=font['MATH'].table.MathVariants
 base=font.getBestCmap()[ord('(')]
 construction=variants.VertGlyphConstruction[variants.VertGlyphCoverage.glyphs.index(base)]
 names=list(dict.fromkeys([base]+[v.VariantGlyph for v in construction.MathGlyphVariantRecord]))
 for index,glyph in enumerate(names):
  row=dict(font=name,glyphs=[dict(index=font.getGlyphID(glyph),x=0,y=0,size=10)])
  cs=contours(row);pts=np.vstack(cs);lo,hi=pts[:,1].min(),pts[:,1].max();H=hi-lo;mid=(lo+hi)/2
  xmin=pts[:,0].min();cs=[c-np.array([xmin,mid]) for c in cs]
  y=np.linspace(-.995*H/2,.995*H/2,401)
  spans=[section(cs,z) for z in y];left=np.array([v[0][0] for v in spans]);right=np.array([v[-1][1] for v in spans])
  width=max(right);t0=np.median((right-left)[np.abs(y)<H*.1])
  def residual(p):
   a,b=shape(p,y,H);return np.r_[a-left,b-right]
  best=None
  for flat in [0,.15,.4]:
   fit=least_squares(residual,[0,width,t0,flat,2,.5],bounds=([-.4,.1,.05,0,1.1,.05],[.4,2*width,3,.95,5,2]),max_nfev=1200)
   if best is None or np.linalg.norm(fit.fun)<np.linalg.norm(best.fun):best=fit
  rec=dict(font=name,index=index,glyph=glyph,height=H,width=float(pts[:,0].max()-xmin),
           central_thickness=float(t0),glyph_count=1,parameters=best.x.tolist(),
           rms_pt=float(np.sqrt(np.mean(best.fun**2))),max_pt=float(max(abs(best.fun))))
  records.append((rec,cs,y,left,right))

# Leave each interior size out, then interpolate using only its two neighbours.
for name in fonts:
 subset=[r for r in records if r[0]['font']==name]
 for i in range(1,len(subset)-1):
  rec,cs,y,left,right=subset[i];before,after=subset[i-1],subset[i+1]
  r0,r1=before[0],after[0];t=(rec['height']-r0['height'])/(r1['height']-r0['height'])
  p=(1-t)*np.array(r0['parameters'])+t*np.array(r1['parameters'])
  a,b=shape(p,y,rec['height']);err=np.r_[a-left,b-right]
  rec.update(holdout_rms_pt=float(np.sqrt(np.mean(err**2))),holdout_max_pt=float(max(abs(err))),predicted_parameters=p.tolist())
  # A second, nonparametric reference: interpolate raw contour sections at equal y/H.
  a=(1-t)*before[3]+t*after[3];b=(1-t)*before[4]+t*after[4]
  rec['profile_holdout_rms_pt']=float(np.sqrt(np.mean(np.r_[a-left,b-right]**2)))
Path('build/prebuilt-fit.json').write_text(json.dumps([r[0] for r in records],indent=2))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
with PdfPages('build/prebuilt-fit.pdf') as pdf:
 for name in fonts:
  subset=[r for r in records if r[0]['font']==name]
  for start in range(0,len(subset),9):
   fig,axs=plt.subplots(3,3,figsize=(11.7,8.3))
   fig.suptitle(name+' — prebuilt parentheses only',fontsize=16)
   for ax in axs.flat:ax.axis('off')
   for ax,(r,cs,y,left,right) in zip(axs.flat,subset[start:start+9]):
    for c in cs:ax.add_patch(Polygon(c,facecolor='.8',edgecolor='none'))
    ax.plot(*fitted_polygon(r['parameters'],r['height']).T,color='#0072b2',lw=.8)
    if 'predicted_parameters' in r:ax.plot(*fitted_polygon(r['predicted_parameters'],r['height']).T,color='#d55e00',lw=.8,ls='--')
    ax.set_aspect('equal');ax.set_xlim(-1,11);ax.set_ylim(-r['height']/2-1,r['height']/2+1)
    extra='; held-out %.3f pt'%r['holdout_rms_pt'] if 'holdout_rms_pt' in r else '; endpoint (not held out)'
    ax.set_title('%s; H = %.2f pt\nfit RMS %.3f pt%s'%(r['glyph'],r['height'],r['rms_pt'],extra),fontsize=8)
   fig.text(.5,.025,'Gray: font outline. Blue: individual fit. Orange: leave-this-size-out prediction from adjacent prebuilt sizes. No assemblies.',ha='center',fontsize=9)
   fig.subplots_adjust(top=.88,bottom=.09,hspace=.42);pdf.savefig(fig);plt.close(fig)
 fig,axs=plt.subplots(2,2,figsize=(11.7,8.3));fig.suptitle('Prebuilt shapes: size trends and held-out prediction errors',fontsize=16)
 for name in fonts:
  rr=[r[0] for r in records if r[0]['font']==name];short='Latin Modern' if name.startswith('Latin') else 'STIX Two'
  for ax,key,title in [(axs[0,0],'width','Ink width'),(axs[0,1],'central_thickness','Central horizontal thickness')]:
   ax.plot([r['height'] for r in rr],[r[key] for r in rr],'o-',label=short);ax.set_title(title);ax.set_xlabel('Actual ink height (pt)');ax.set_ylabel('pt');ax.legend()
  rr=[r for r in rr if 'holdout_rms_pt' in r]
  axs[1,0].plot([r['height'] for r in rr],[r['holdout_rms_pt'] for r in rr],'o-',label=short)
  axs[1,1].plot([r['height'] for r in rr],[r['profile_holdout_rms_pt'] for r in rr],'o-',label=short)
 for ax,title in zip(axs[1],['Held-out parameter interpolation','Held-out raw-section interpolation (reference)']):
  ax.set_title(title);ax.set_xlabel('Held-out ink height (pt)');ax.set_ylabel('Horizontal boundary RMS error (pt)');ax.legend()
 fig.tight_layout(rect=[0,.04,1,.94]);fig.text(.5,.015,'10pt fonts. Only interior variants are held out; no extrapolation. Errors exclude the outermost 0.5% at each tip.',ha='center',fontsize=9)
 pdf.savefig(fig);plt.close(fig)
for name in fonts:
 rr=[r[0] for r in records if r[0]['font']==name]
 print(name,len(rr),'prebuilt variants')
 print('individual RMS range:',min(r['rms_pt'] for r in rr),max(r['rms_pt'] for r in rr))
 print('heldout RMS range:',min(r['holdout_rms_pt'] for r in rr if 'holdout_rms_pt' in r),max(r['holdout_rms_pt'] for r in rr if 'holdout_rms_pt' in r))
 print('profile interpolation max:',max(r['profile_holdout_rms_pt'] for r in rr if 'profile_holdout_rms_pt' in r))
 assert all(r['glyph_count']==1 for r in rr)
