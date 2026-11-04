import hashlib,re
from pathlib import Path
import pdfplumber
from pypdf import PdfReader
original=Path('build/physics-official-original.tex').read_text(encoding='utf-8')
adapted=Path('experimental/physics-official-finaldelim.tex').read_text(encoding='utf-8')
assert original.split(r'\begin{document}',1)[1]==adapted.split(r'\begin{document}',1)[1]
for name in ('original','classic','finaldelim'):
 log=Path('build/physics-official-'+name+'.log').read_text(errors='replace')
 assert f'Output written on physics-official-{name}.pdf (8 pages' in log
 assert 'Missing character' not in log and 'undefined references' not in log
 assert log.count('Overfull')==7
with pdfplumber.open('build/physics-official-finaldelim.pdf') as pdf:
 chars=[c for p in pdf.pages for c in p.chars]
 text=''.join(c['text'] for c in chars)
 assert all(c in text for c in ['÷','ℜ','ℑ']), 'Lost legacy symbol aliases'
 assert r'\bra{\phi}\ket{\psi}' in text, 'Verbatim math sample changed'
 colors=[c for p in pdf.pages for c in p.curves if c['non_stroking_color'] not in (0,(0,),(0,0,0),None)]
 assert colors
 assert 'OUTLINE fallback 0' in Path('build/physics-official-finaldelim.log').read_text()
aux=Path('build/displaymath-test.aux').read_text()
assert r'\newlabel{stream:first}{{1}' in aux and r'\newlabel{stream:second}{{2}' in aux
with pdfplumber.open('build/displaymath-test.pdf') as pdf:
 assert r'\bra{\phi}\ket{\psi}' in ''.join(c['text'] for p in pdf.pages for c in p.chars)
print('PASS: official document body unchanged; three eight-page builds; no missing glyphs; symbol aliases and verbatim examples retained; niji paths present; no outline fallback; streaming displaymath and numbering')
