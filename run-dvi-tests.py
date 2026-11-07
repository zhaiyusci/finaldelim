"""Build reproducible PDF/DVI comparison pairs (LuaLaTeX and dvipdfmx required)."""
from pathlib import Path
import os
import subprocess
import sys

root=Path(__file__).resolve().parent
os.chdir(root)
env=dict(os.environ, TEXMFVAR=str(root/'build/texmf-var'), TEXMFCACHE=str(root/'build/texmf-var'))
for name,preamble in [('test',''), ('global',r'\def\GlobalDebug{1}'),
                      ('stix',r'\def\MathFace{STIX Two Math}'),
                      ('traditional',r'\def\Traditional{1}')]:
    prefix='dvi-'+name
    for mode in ('pdf','dvi'):
        subprocess.run(['lualatex','--output-format='+mode,'-interaction=batchmode',
                        '-halt-on-error','-output-directory=build','-jobname='+prefix+'-'+mode,
                        preamble+r'\input{dvi-test.tex}'],env=env,check=True)
    subprocess.run(['dvipdfmx','-o',f'build/{prefix}-dvi.pdf',f'build/{prefix}-dvi.dvi'],check=True)
    subprocess.run([sys.executable,'test-dvi.py',prefix],check=True)
