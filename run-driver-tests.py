"""Build dvips and dvisvgm samples. Run run-dvi-tests.py for PDF references first."""
from pathlib import Path
import os, subprocess, sys
root=Path(__file__).resolve().parent
os.chdir(root)
env=dict(os.environ,TEXMFVAR=str(root/'build/texmf-var'),TEXMFCACHE=str(root/'build/texmf-var'))
def run(args):
    result=subprocess.run(args,env=env,capture_output=True,text=True,errors='replace')
    output=result.stdout+result.stderr
    print(output,end='')
    assert result.returncode==0, args
    assert not any(s in output for s in ('characters will be left blank','expect bad output','WARNING:','ERROR:')),output
def compile(name,source,mode='dvi'):
    run(['lualatex','--output-format='+mode,'-interaction=batchmode','-halt-on-error',
         '-output-directory=build','-jobname='+name,source])
compile('dvi-svg',r'\def\DVIDriver{dvisvgm}\input{dvi-test.tex}')
run(['dvisvgm','--no-fonts','--page=1-3','--bbox=papersize','--output=build/dvi-svg-%p.svg','build/dvi-svg.dvi'])
compile('dvi-ps',r'\def\DVIDriver{dvips}\def\Traditional{1}\input{dvi-test.tex}')
run(['dvips','-o','build/dvi-ps.ps','build/dvi-ps.dvi'])
run(['ps2pdf','build/dvi-ps.ps','build/dvi-ps.pdf'])
compile('driver-outlines-pdf','driver-outlines.tex','pdf')
compile('driver-outlines-ps','driver-outlines.tex')
run(['dvips','-o','build/driver-outlines.ps','build/driver-outlines-ps.dvi'])
run(['ps2pdf','build/driver-outlines.ps','build/driver-outlines-ps.pdf'])
run([sys.executable,'test-driver-outputs.py'])
