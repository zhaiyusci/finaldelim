from pathlib import Path
import pdfplumber
with pdfplumber.open('build/single-line-size.pdf') as doc:
    assert len(doc.pages)==1
    c=doc.pages[0].chars
    starts=[i for i,x in enumerate(c) if x['text']=='𝑎']
    assert len(starts)==5, starts
    blocks=[]
    for i in starts:
        end=next(j for j in range(i,len(c)) if c[j]['text']=='2')
        blocks.append(c[i:end+1])
    ref=blocks[0]
    for b in blocks[1:]:
        assert [x['text'] for x in ref]==[x['text'] for x in b]
        dx,dy=b[0]['x0']-ref[0]['x0'],b[0]['top']-ref[0]['top']
        for x,y in zip(ref,b):
            assert x['fontname']==y['fontname']
            for k in ('x0','x1','top','bottom','size'):
                offset=dx if k in ('x0','x1') else dy if k in ('top','bottom') else 0
                assert abs(y[k]-x[k]-offset)<.003,(k,x['text'])
print('PASS: identical body geometry across all five single-line policies')
