"""Generate prototype outline data for the installed math fonts. No assembly fitting."""
import sys,json,subprocess
import numpy as np
from pathlib import Path
sys.path.insert(0,str(Path('build/fit-deps').resolve()))
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
from fontTools.pens.boundsPen import BoundsPen
class PathPen(BasePen):
 def __init__(self,gs):super().__init__(gs);self.path=[]
 def _moveTo(self,p):self.path.append(['m',*p])
 def _lineTo(self,p):self.path.append(['l',*p])
 def _curveToOne(self,a,b,c):self.path.append(['c',*a,*b,*c])
 def _qCurveToOne(self,a,b):
  p=self._getCurrentPoint();self._curveToOne(tuple(p[i]+2*(a[i]-p[i])/3 for i in range(2)),tuple(b[i]+2*(a[i]-b[i])/3 for i in range(2)),b)
 def _closePath(self):self.path.append(['h'])
 def _endPath(self):self.path.append(['h'])
def lua(x):
 if isinstance(x,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in x.items())+'}'
 if isinstance(x,(list,tuple)):return '{'+','.join(map(lua,x))+'}'
 if isinstance(x,str):return json.dumps(x)
 if isinstance(x,bool):return 'true' if x else 'false'
 return format(x,'.12g')
result={}
for filename in ['latinmodern-math.otf','STIXTwoMath-Regular.otf']:
 path=subprocess.check_output(['kpsewhich',filename],text=True).strip();f=TTFont(path);gs=f.getGlyphSet();math=f['MATH'].table.MathVariants
 data={'units':f['head'].unitsPerEm,'glyphs':{},'delimiters':{}}
 def add(name):
  gid=f.getGlyphID(name)
  if gid not in data['glyphs']:
   p=PathPen(gs);gs[name].draw(p);b=BoundsPen(gs);gs[name].draw(b)
   data['glyphs'][gid]={'path':p.path,'bounds':b.bounds,'advance':f['hmtx'][name][0]}
  return gid
 for code in [40,41,91,93,123,125,10216,10217,124,8214,8968,8969,8970,8971]:
  base=f.getBestCmap().get(code)
  if base not in math.VertGlyphCoverage.glyphs:continue
  c=math.VertGlyphConstruction[math.VertGlyphCoverage.glyphs.index(base)]
  ids=list(dict.fromkeys([add(base)]+[add(v.VariantGlyph) for v in c.MathGlyphVariantRecord]))
  ids.sort(key=lambda i:data['glyphs'][i]['bounds'][3]-data['glyphs'][i]['bounds'][1])
  if c.GlyphAssembly:
   for part in c.GlyphAssembly.PartRecords:add(part.glyph)
  data['delimiters'][code]={'variants':ids,'assembly':bool(c.GlyphAssembly)}
 # Only topology-changing intervals need the sampled-boundary fallback.
 bad=set()
 for spec in data['delimiters'].values():
  for a,b in zip(spec['variants'],spec['variants'][1:]):
   pa,pb=data['glyphs'][a]['path'],data['glyphs'][b]['path']
   if [c[0] for c in pa]!=[c[0] for c in pb]:bad.update((a,b))
 def flatten(path):
  contours=[];cur=[]
  for c in path:
   if c[0]=='m':cur=[np.array(c[1:],float)]
   elif c[0]=='l':cur.append(np.array(c[1:],float))
   elif c[0]=='c':
    p=cur[-1];a,b,e=np.array(c[1:]).reshape(3,2)
    for t in np.linspace(0,1,97)[1:]:cur.append((1-t)**3*p+3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3*e)
   elif c[0]=='h':contours.append(np.array(cur+[cur[0]]));cur=[]
  return contours
 zset=set(np.linspace(-.5,.5,1025))
 for gid in bad:
  g=data['glyphs'][gid];b=g['bounds'];H=b[3]-b[1];mid=(b[3]+b[1])/2
  for c in g['path']:
   if len(c)>1:zset.add(max(-.5,min(.5,(c[-1]-mid)/H)))
 zs=sorted(zset)
 for gid in bad:
  g=data['glyphs'][gid];b=g['bounds'];H=b[3]-b[1];mid=(b[3]+b[1])/2
  cs=flatten(g['path']);a=np.vstack([c[:-1] for c in cs]);e=np.vstack([c[1:] for c in cs]);values=[]
  for z in zs:
   y=mid+max(-.5+1e-10,min(.5-1e-10,z))*H
   mask=((a[:,1]<=y)&(e[:,1]>y))|((e[:,1]<=y)&(a[:,1]>y))
   aa,ee=a[mask],e[mask];xs=aa[:,0]+(y-aa[:,1])*(ee[:,0]-aa[:,0])/(ee[:,1]-aa[:,1])
   assert len(xs)>=2
   values.append([float(z),float(min(xs)),float(max(xs))])
  g['profile']=values
 result[filename.lower()]=data
Path('build/outline-font-data.lua').write_text('return '+lua(result)+'\n',encoding='utf-8')
print('Exported',sum(len(v['glyphs']) for v in result.values()),'glyph outlines from installed fonts')
