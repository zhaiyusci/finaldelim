"""Issue #1 regression: python test-tagging.py (requires pypdf and LuaLaTeX)."""
from pathlib import Path
import os
import re
import subprocess
import xml.etree.ElementTree as ET
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'build' / 'tagging'
OUT.mkdir(parents=True, exist_ok=True)
ENV = dict(os.environ, TEXMFVAR=str(ROOT/'build/texmf-var'), TEXMFCACHE=str(ROOT/'build/texmf-var'))
NS = '{http://www.w3.org/1998/Math/MathML}'


def normalized(node):
    """Compare rows, cells, tokens and fractions, allowing spacing/group wrappers."""
    tag = node.tag.split('}')[-1]
    if tag == 'mspace':
        return []
    children = [item for child in node for item in normalized(child)]
    if tag in ('mrow', 'mstyle'):
        return children
    return [(tag, (node.text or '').strip(), children)]


def check_tree(path, expected):
    reader = PdfReader(path)
    seen = set()
    counts = {}
    def visit(ref, parent=None):
        obj = ref.get_object() if hasattr(ref, 'get_object') else ref
        if isinstance(obj, list):
            for child in obj:
                visit(child, parent)
        elif isinstance(obj, dict):
            if '/S' in obj:
                identity = (ref.idnum, ref.generation)
                assert identity not in seen, ('Repeated structure reference', identity)
                seen.add(identity)
                assert obj.raw_get('/P') == parent, ('Incorrect parent', identity)
                tag = str(obj['/S']).lstrip('/')
                counts[tag] = counts.get(tag, 0) + 1
                parent = ref
            if '/K' in obj:
                visit(obj.raw_get('/K'), parent)
    root = reader.trailer['/Root'].raw_get('/StructTreeRoot')
    visit(root, root)
    assert counts.get('Formula') == 1, counts
    assert not counts.get('mphantom'), counts
    for tag in ('mfrac', 'mi', 'mo', 'mtext', 'mtr', 'mtd'):
        assert counts.get(tag, 0) == sum(1 for n in expected.iter() if n.tag == NS+tag), (tag, counts)


def run(name, body, env='align', options='', native=False, wrap=False, env_options=''):
    package = r'\usepackage{amsmath}' if native else r'\usepackage['+options+r']{finaldelim}'
    formula = '\\begin{'+env+'}'+env_options+'\n'+body+'\n\\end{'+env+'}'
    if wrap:
        formula = '\\begin{equation}\n'+formula+'\n\\end{equation}'
    source = (r'\DocumentMetadata{tagging=on,tagging-setup={math/setup={mathml-SE}}}'+'\n'
              r'\documentclass{article}'+'\n'+r'\usepackage{lua-unicode-math}'+'\n'+package+'\n'
              r'\begin{document}'+'\n'+formula+'\n'+r'\end{document}'+'\n')
    (OUT/(name+'.tex')).write_text(source, encoding='utf-8')
    for passno in (1, 2):
        result = subprocess.run(['lualatex', '-interaction=nonstopmode', '-halt-on-error',
                                 '-output-directory='+str(OUT), str(OUT/(name+'.tex'))],
                                cwd=ROOT, env=ENV, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
        (OUT/f'{name}-pass{passno}.txt').write_bytes(result.stdout)
        assert result.returncode == 0, name
    log = (OUT/(name+'.log')).read_text(errors='replace')
    assert not re.search(r'Package tagpdf Warning|warning\s+\(nodes\)|undefined references|multiply defined|Overfull', log), name
    math = ET.parse(OUT/(name+'-luamml-mathml.html')).getroot().findall('.//'+NS+'math')
    assert len(math) == 1, (name, len(math))
    assert not math[0].findall('.//'+NS+'mphantom'), name
    check_tree(OUT/(name+'.pdf'), math[0])
    print('PASS', name, flush=True)
    return normalized(math[0])


body = r'F &= \left(a+\frac{x}{y}\label{eq:first}\\ &\quad+\frac{p}{q}\right)\label{eq:second}'
native_body = body.replace(r'\label{eq:first}', r'\right.\label{eq:first}').replace(r'&\quad', r'&\left.\quad')
reference = run('native', native_body, native=True)
for name, env, options in [('matched','matchedalign',''), ('rainbow','matchedalign','rainbow'),
                            ('override','align','overridealign')]:
    assert run(name, body, env, options) == reference, name
star_body = re.sub(r'\\label\{[^}]*\}', '', body)
star_native = re.sub(r'\\label\{[^}]*\}', '', native_body)
reference = run('native-star', star_native, 'align*', native=True)
assert run('matched-star', star_body, 'matchedalign*') == reference
assert run('override-star', star_body, 'align*', 'overridealign') == reference
nested = r'F &= \left(a+\left[\frac{x}{y}\\ &+\frac{p}{q}\right]\\ &+z\right)'
nested_native = nested.replace(r'\frac{x}{y}\\', r'\frac{x}{y}\right.\right.\\').replace(r'&+\frac{p}{q}', r'&\left.\left.+\frac{p}{q}').replace(r'\right]\\', r'\right]\right.\\').replace('&+z', r'&\left.+z')
assert run('nested', nested, 'matchedalign', 'rainbow') == run('native-nested', nested_native, native=True)
middle = r'F &= \left\{a\middle|\frac{x}{y}\\ &+\frac{p}{q}\right\}'
middle_native = middle.replace(r'\frac{x}{y}\\', r'\frac{x}{y}\right.\\').replace(r'&+\frac', r'&\left.+\frac')
assert run('middle', middle, 'matchedalign') == run('native-middle', middle_native, native=True)
# matchedsplit is implemented with aligned; compare that native counterpart.
reference = run('native-aligned', star_native, 'aligned', native=True, wrap=True)
assert run('split', star_body, 'matchedsplit', wrap=True) == reference
assert run('aligned', star_body, 'matchedaligned', wrap=True) == reference
for position in ('t', 'c', 'b'):
    baseline = run('native-aligned-'+position, star_native, 'aligned', native=True, wrap=True, env_options='['+position+']')
    assert run('aligned-'+position, star_body, 'matchedaligned', wrap=True, env_options='['+position+'][rainbow]') == baseline
assert run('override-split', star_body, 'split', 'overridesplit', wrap=True) == reference
# Explicit tags, suppressed numbering, intertext, and numbering after a break.
tagged = r'F &= \left(a+\frac{x}{y}\tag{A}\label{custom}\\ \intertext{Then} &+\frac{p}{q}\right)\notag\\ G &= z\label{last}'
tagged_native = tagged.replace(r'\tag{A}', r'\right.\tag{A}').replace(r'&+\frac', r'&\left.+\frac')
assert run('custom-tags', tagged, 'matchedalign') == run('native-custom-tags', tagged_native, native=True)
for name in ('matched','rainbow','override'):
    aux = (OUT/(name+'.aux')).read_text()
    assert r'\newlabel{eq:first}{{1}' in aux and r'\newlabel{eq:second}{{2}' in aux, name
aux = (OUT/'custom-tags.aux').read_text()
assert r'\newlabel{custom}{{{A}}' in aux and r'\newlabel{last}{{1}' in aux, aux
# alignat keeps its native column count and equation-label semantics.
for suffix, actual, control in [('', body, native_body), ('*', star_body, star_native)]:
    name = 'alignat' + ('-star' if suffix else '')
    baseline = run('native-'+name, control, 'alignat'+suffix, native=True, env_options='{1}')
    assert run(name, actual, 'matchedalignat'+suffix, env_options='[rainbow]{1}') == baseline
    assert run('override-'+name, actual, 'alignat'+suffix,
               'overridealign,overridealignat', env_options='{1}') == baseline
multi = r'F &= \left(a+\frac{x}{y} &\quad&\text{first}\\ &+\frac{p}{q}\right) &&\text{next}'
multi_native = multi.replace(r' &\quad', r'\right. &\quad').replace(r'&+\frac', r'&\left.+\frac')
assert run('alignat-multi', multi, 'matchedalignat', env_options='{2}') == run('native-alignat-multi', multi_native, 'alignat', native=True, env_options='{2}')
assert run('alignat-tags', tagged, 'matchedalignat', env_options='{1}') == run('native-alignat-tags', tagged_native, 'alignat', native=True, env_options='{1}')
for name in ('alignat', 'override-alignat'):
    aux = (OUT/(name+'.aux')).read_text()
    assert r'\newlabel{eq:first}{{1}' in aux and r'\newlabel{eq:second}{{2}' in aux, name
grouped = r'F &= \left[e^{-\left(\frac{a}{b}\right)\left(A+B\right)}\\ &+x_{\left(i\right)}\right]'
grouped_native = grouped.replace(r'\\', r'\right.\\').replace(r'&+x', r'&\left.+x')
assert run('rainbow-groups', grouped, 'matchedalign', 'rainbow') == run('native-groups', grouped_native, native=True)
scripts = r'F &= {\left(a^{\left[b\right]}\right)_{\left(c\right)}+\left(d\right)\prime}+\frac{\left(x\middle|y\right)}{\left(z\right)}'
assert run('rainbow-group-scripts', scripts, 'matchedalign', 'rainbow') == run('native-group-scripts', scripts, native=True)
# Color-stack resets must not detach scripts from top-level right delimiters.
right_scripts = r'F &= \left|\frac{a}{b}\right|^{n/2}+\left(x\right)_i^j'
assert run('rainbow-right-scripts', right_scripts, 'matchedalign', 'rainbow') == run('plain-right-scripts', right_scripts, 'matchedalign')
assert run('native-right-scripts', right_scripts, native=True) == run('local-right-scripts', right_scripts, 'matchedalign', 'rainbow')
print('All tagged MathML/PDF structure comparisons passed.')
