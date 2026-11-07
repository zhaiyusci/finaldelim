"""Rendered-output checks for dvips and dvisvgm; compare with direct PDF.

Requires Poppler, Pillow, numpy, Node and sharp. FINALDELIM_SHARP may name an
absolute sharp module directory when it is not installed in node_modules.
"""
from pathlib import Path
import os, subprocess
import numpy as np
import pdfplumber
from PIL import Image, ImageFilter

def render_pdf(name):
    subprocess.run(['pdftoppm','-r','144','-png',f'build/{name}.pdf',f'build/{name}'],check=True)

def compare(a,b,debug=False):
    a=np.array(Image.open(a).convert('RGB'));b=np.array(Image.open(b).convert('RGB'))
    assert a.shape==b.shape,(a.shape,b.shape)
    # Compare ink and each saturated color, allowing 1px rasterizer differences.
    masks=[lambda x,weak:x.min(axis=2)<(245 if weak else 220)]
    masks += [lambda x,weak,i=i:(x[:,:,i]>x[:,:,(i+1)%3]+(10 if weak else 40)) &
              (x[:,:,i]>x[:,:,(i+2)%3]+(10 if weak else 40)) for i in range(3)]
    for index,mask in enumerate(masks):
        for x,y in ((mask(a.astype(float),False),mask(b.astype(float),True)),
                    (mask(b.astype(float),False),mask(a.astype(float),True))):
            expanded=np.array(Image.fromarray(y.astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
            unmatched=(x & ~expanded).sum()/max(1,x.sum())
            # Debug hairlines/dashes overlap glyphs and are rasterized
            # differently in SVG; preserve the stricter all-ink geometry test.
            limit=.04 if debug and index>0 else .015
            assert unmatched<limit,(str(a.shape),unmatched)

render_pdf('dvi-test-pdf')
render_pdf('dvi-traditional-pdf')
render_pdf('dvi-ps')
for page in range(1,4):
    target=f'build/dvi-svg-{page}.png'
    script="const s=require(process.env.FINALDELIM_SHARP||'sharp');s(process.argv[1],{density:144}).resize(1224,1584).flatten({background:'white'}).png().toFile(process.argv[2]);"
    subprocess.run(['node','-e',script,f'build/dvi-svg-{page}.svg',target],check=True)
    compare(f'build/dvi-test-pdf-{page}.png',target,page==3)
    compare(f'build/dvi-traditional-pdf-{page}.png',f'build/dvi-ps-{page}.png',page==3)
    print(f'PASS page {page}: dvips and dvisvgm ink/color masks match direct PDF')

with pdfplumber.open('build/driver-outlines-pdf.pdf') as a, \
     pdfplumber.open('build/driver-outlines-ps.pdf') as b:
    for kind in ('curves','rects'):
        aa,bb=getattr(a.pages[0],kind),getattr(b.pages[0],kind)
        assert len(aa)==len(bb)>0
        for c,d in zip(aa,bb):
            # Standard dvips uses a 600dpi placement grid.
            assert max(abs(c[k]-d[k]) for k in ('x0','x1','top','bottom'))<.08
            assert max(abs(x-y) for x,y in zip(c['non_stroking_color'],d['non_stroking_color']))<.001
print('PASS: dvips reproduces continuous OpenType-derived outlines, nested colors, roots and horizontal constructions')
