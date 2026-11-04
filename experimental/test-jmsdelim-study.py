"""Validate the installed jmsdelim behavior recorded by the study fixture."""
import re
from pathlib import Path
import pdfplumber
log=Path('build/jmsdelim-study.log').read_text(errors='replace')
expected={'unseeded':[0], 'seed1':[1], 'seed2':[2], 'nested0':[0,0,0],
'nested2':[2,2,2], 'outer3':[2,2,3], 'leak':[4,4], 'protect':[4,0],
'left':[2], 'center':[2], 'right':[2]}
for name,levels in expected.items():
    actual=[int(x) for x in re.findall(r'JMS-PROBE '+name+r': level=(\d+)',log)]
    assert actual==levels,(name,actual,levels)
assert 'JMS-SETUP undefined' in log
with pdfplumber.open('build/jmsdelim-study.pdf') as doc:
    assert len(doc.pages)==3
    c=doc.pages[2].chars
    left=[x for x in c if x['text']=='[']
    right=[x for x in c if x['text']==']']
    assert len(left)==len(right)==3
    for pair in (left,right):
        assert len({x['fontname'] for x in pair})==1
        assert max(x['size'] for x in pair)-min(x['size'] for x in pair)<.001
        assert max(x['height'] for x in pair)-min(x['height'] for x in pair)<.001
print('PASS: all 11 propagation scenarios and three equal-size distance cases')
