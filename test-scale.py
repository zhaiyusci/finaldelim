import re
from pathlib import Path
# Targets from actual production compilation, including both fence paths.
def metrics(name):
 return [tuple(map(float,x)) for x in re.findall(r'WEIGHTED (?:pair|middles) \d+: (?:fences=\d+ )?([\d.]+)pt / ([\d.]+)pt',Path('build/'+name+'.log').read_text())]
a=metrics('max-scale-sample')
assert len(a)==12
for full,small in zip(a[::2],a[1::2]):
 assert abs(sum(small)-.9*sum(full))<.002
 assert abs((small[0]-small[1])-(full[0]-full[1]))<.002
small,full=metrics('scale-test')
assert abs(sum(small)-.9*sum(full))<.002
assert 'SCALE SCOPE AND NATIVE ASSERTIONS PASSED' in Path('build/scale-test.log').read_text()
print('PASS: exact target scaling about the axis; pairs/middles/endpoints; local restoration, package option, native invariance, source once')
