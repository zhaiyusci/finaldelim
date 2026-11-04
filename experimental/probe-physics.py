import json,subprocess,os
from pathlib import Path
cases=json.loads(Path('experimental/physics-cases.json').read_text())
base=Path('build/physics-probes');base.mkdir(exist_ok=True)
results=[]
for name,formula in cases:
 contexts=['inline','equation'] if not name.startswith('break') else ['equation']
 for context in contexts:
  for niji in [False,True]:
   job=f'{name}-{context}-{int(niji)}'
   tex=r'\documentclass{article}\usepackage{unicode-math}\setmathfont{Latin Modern Math}\usepackage{physics}\usepackage{experimental/finaldelim-draw}\FinalDelimSetup{niji='+str(niji).lower()+r'}\pagestyle{empty}\begin{document}'
   tex+=(r'$\displaystyle '+formula+'$') if context=='inline' else r'\begin{equation*}'+formula+r'\end{equation*}'
   tex+=r'\end{document}'
   (base/(job+'.tex')).write_text(tex)
   p=subprocess.run(['lualatex','-interaction=batchmode','-halt-on-error','-output-directory='+base.as_posix(),(base/(job+'.tex')).as_posix()],stdout=subprocess.DEVNULL,stderr=subprocess.STDOUT)
   log=(base/(job+'.log')).read_text(errors='replace')
   err=next((l for l in log.splitlines() if l.startswith('!')),'')
   results.append(dict(name=name,context=context,niji=niji,ok=p.returncode==0,error=err,job=job))
  print(name,context,[(r['niji'],r['ok']) for r in results[-2:]],flush=True)
Path('build/physics-results.json').write_text(json.dumps(results,indent=2))

