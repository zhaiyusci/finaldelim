"""Independent PDF checks for the endpoint experiment (run from repo root)."""
import pdfplumber
from pypdf import PdfReader
from pypdf.generic import ContentStream

def geometry(a,b,tol=.003):
    assert [x['text'] for x in a] == [x['text'] for x in b]
    dx,dy=b[0]['x0']-a[0]['x0'],b[0]['top']-a[0]['top']
    for x,y in zip(a,b):
        assert x['fontname']==y['fontname']
        for k in ('x0','x1','top','bottom','size'):
            delta=dx if k in ('x0','x1') else dy if k in ('top','bottom') else 0
            assert abs(y[k]-x[k]-delta)<tol,(x['text'],k,y[k]-x[k]-delta)

with pdfplumber.open('build/endpoint-size-test.pdf') as doc:
    c=doc.pages[0].chars
    closes=[i for i,x in enumerate(c) if x['text']==']']
    assert len(closes)==2
    # Include the parenthesized endpoint expression, bracket, superscript and subscript.
    geometry(c[closes[0]-6:closes[0]+5],c[closes[1]-6:closes[1]+5])
print('PASS: endpoint bracket and scripts match native single-line geometry')
with pdfplumber.open('build/endpoint-size-comparison.pdf') as doc:
    c=doc.pages[0].chars
    sums=[i for i,x in enumerate(c) if x['text']=='∑']
    assert len(sums)==2
    segments=[]
    for i in sums:
        end=next(j for j in range(i,len(c)) if c[j]['text']=='𝑞')
        segments.append(c[i-1:end+1])
    geometry(*segments)
print('PASS: tall middle fraction retains native glyph sizes and internal geometry')
for name in ('endpoint-size-test','endpoint-size-comparison'):
    reader=PdfReader('build/'+name+'.pdf')
    for page in reader.pages:
        assert not any(op in (b'W',b'W*') for args,op in ContentStream(page.get_contents(),reader).operations)
print('PASS: physical content partition, no PDF clipping')
