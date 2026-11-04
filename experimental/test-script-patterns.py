import unicodedata as ud
import pdfplumber
with pdfplumber.open('build/script-patterns.pdf') as pdf:
 p=pdf.pages[0]
 us=sorted([c for c in p.chars if ud.normalize('NFKC',c['text'])=='U'],key=lambda c:c['top'])
 ds=sorted([c for c in p.chars if ud.normalize('NFKC',c['text'])=='D'],key=lambda c:c['top'])
 for i,name in enumerate(('lhl','hll','llh','lhhl','hlhl','lllhlll')):
  upper=sorted(us[i*3:i*3+3],key=lambda c:c['x0'])[1:]
  lower=sorted(ds[i*3:i*3+3],key=lambda c:c['x0'])[1:]
  vals=[]
  for u,d in zip(upper,lower):
   curves=[c for c in p.curves if abs(c['x1']-u['x0'])<5 and abs(c['top']-u['top'])<15]
   c=min(curves,key=lambda c:abs(c['x1']-u['x0']))
   vals.append((u['top']-c['top'],d['bottom']-c['bottom'],c['height']))
  assert vals[1][2]<vals[0][2],(name,vals)
  assert all(abs(vals[0][j]-vals[1][j])<.015 for j in (0,1)),(name,vals)
  print(name, 'delimiter heights',round(vals[0][2],3),round(vals[1][2],3),'pt; script-to-fence offsets unchanged')
 assert len(pdf.pages)==2
print('PASS: all six height patterns; scripts follow final outlines at both scales')
