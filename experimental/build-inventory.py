import sys,re,subprocess,json
from pathlib import Path
sys.path.insert(0,'build/fit-deps')
from fontTools.ttLib import TTFont
fonts=list(zip(['Latin Modern Math','STIX Two Math','TeX Gyre Pagella Math','TeX Gyre Termes Math','XITS Math','Libertinus Math','Fira Math','GFS Neohellenic Math'],['latinmodern-math.otf','STIXTwoMath-Regular.otf','texgyrepagella-math.otf','texgyretermes-math.otf','XITSMath-Regular.otf','LibertinusMath-Regular.otf','FiraMath-Regular.otf','GFSNeohellenicMath.otf']))
table=Path(subprocess.check_output(['kpsewhich','unicode-math-table.tex'],text=True).strip()).read_text()
items=[]
for hx,cmd,cls in re.findall(r'\\UnicodeMathSymbol\{"([0-9A-F]+)\}\{\\(\w+)\s*\}\{\\(mathopen|mathclose|mathfence)\}',table):
 c=int(hx,16)
 if c not in (33,0x221a,0x221b,0x221c,0x27cc):items.append((c,cmd))
items+=[(47,'slash'),(92,'backslash'),(0x2191,'uparrow'),(0x2193,'downarrow'),(0x2195,'updownarrow'),(0x21d1,'Uparrow'),(0x21d3,'Downarrow'),(0x21d5,'Updownarrow')]
items.sort();inventory=[]
s=r'''\documentclass[10pt,a4paper]{article}
\usepackage[margin=16mm]{geometry}
\usepackage{unicode-math}
\usepackage{experimental/finaldelim-draw}
\usepackage{fancyhdr}\pagestyle{fancy}\fancyhf{}\fancyhead[L]{finaldelim: complete delimiter inventory}\fancyfoot[C]{\thepage}
\setlength\parindent{0pt}
\newcommand\Glyph[2]{$\displaystyle\left\Udelimiter 0 0 "#1\relax\phantom{\vrule width1pt height\dimexpr#2pt/2+\Umathaxis\displaystyle\relax depth\dimexpr#2pt/2-\Umathaxis\displaystyle\relax}\right.$}
\newcommand\Cell[2]{\hbox to .16\textwidth{\hfil\FinalDelimDrawOff\Glyph{#1}{#2}\hskip4pt\FinalDelimDrawOn\Glyph{#1}{#2}\hfil}}
\newcommand\Missing{\hbox to .16\textwidth{\hfil\textit{missing}\hfil}}
\newcommand\Name[2]{\hbox to .16\textwidth{\hfil\vbox{\hbox{\scriptsize\ttfamily #1}\hbox{\scriptsize #2}}\hfil}}
\begin{document}
\FinalDelimSetup{q=0,scale=1,niji=false}\delimiterfactor=1000\delimitershortfall=0pt\nulldelimiterspace=0pt
'''
for font,file in fonts:
 f=TTFont(subprocess.check_output(['kpsewhich',file],text=True).strip());cm=f.getBestCmap();v=f['MATH'].table.MathVariants;vc=dict(zip(v.VertGlyphCoverage.glyphs,v.VertGlyphConstruction))
 for start in range(0,len(items),12):
  if inventory or start:s+='\\clearpage\n'
  s+=(r'\setmathfont{'+font+'}\n' if start==0 else '')+r'\fancyhead[R]{'+font+'}\n'+r'{\Large\bfseries '+font+r'}\par\medskip'+'\n'
  s+='Each pair: native left, drawn right. Targets: 14, 32, 64 pt.\\par\nS: fixed glyph; V: size variants; A: assembly; missing: absent from font.\\par\\bigskip\n'
  for off in (0,6):
   batch=items[start+off:start+off+6]
   if not batch:continue
   s+='\\hbox{'
   for c,cmd in batch:
    g=cm.get(c);con=vc.get(g);status='missing' if not g else 'A' if con and con.GlyphAssembly else 'V' if con and len(con.MathGlyphVariantRecord)>1 else 'S'
    inventory.append(dict(font=font,code=c,command=cmd,status=status))
    s+=r'\Name{'+cmd+'}{'+f'U+{c:04X} / {status}'+'}'
   s+='}\\par\\smallskip\n'
   for h in (14,32,64):
    s+=f'\\textbf{{{h} pt}}\\par\\smallskip\\hbox{{'
    for c,cmd in batch:s+=(r'\Cell{'+f'{c:04X}'+'}{'+str(h)+'}') if c in cm else r'\Missing'
    s+='}\\par\\medskip\n'
   s+='\\bigskip\n'
s+=r'\end{document}'
Path('experimental/outline-inventory.tex').write_text(s)
Path('build/delimiter-inventory.json').write_text(json.dumps(inventory,indent=2))
print(len(items),'symbols',len(inventory),'font-symbol entries')
