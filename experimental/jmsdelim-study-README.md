# jmsdelim investigation

Tested the installed, unmodified jmsdelim 0.2.0 (2022/03/11), also the version
listed by CTAN when checked on 2026-11-04. Read both jmsdelim.dtx and the generated
jmsdelim.sty in TeX Live 2026. The three-page study uses LuaLaTeX and XITS Math;
it does not load matchedsplit. Reproduce from the repository root:

    lualatex -output-directory=build experimental/jmsdelim-study.tex
    python experimental/test-jmsdelim-study.py

Public project: https://ctan.org/pkg/jmsdelim
Source: C:/texlive/2026/texmf-dist/source/latex/jmsdelim/jmsdelim.dtx
Implementation: C:/texlive/2026/texmf-dist/tex/latex/jmsdelim/jmsdelim.sty

## Actual rule

DelimMin(k) updates a global requested minimum using max(current,k). Each
surround operation saves the surrounding pending state, resets the local
request, typesets its body into a temporary hbox, selects a delimiter command
from the resulting requested integer, emits the delimiters and body box, then
merges the pending request back outward. This is bottom-up propagation of
annotations, not measurement-based size inference. The geometry of the body box
is not consulted by the size selector. No horizontal-distance term exists.

Default display/text levels are 0=ordinary, 1=big, 2=Big, 3=bigg, 4=Bigg.
The command-list index saturates at the final entry. Custom command lists are
accepted through package keys. Script style maps nonzero default levels to big;
scriptscript style uses the ordinary delimiter. The numeric request still
propagates unchanged: DelimProtect explicitly saves/restores state to stop it.

## Confirmed outcomes

- Our tall fraction without any hint selects level 0.
- Explicit leaf hints 1 and 2 select those exact levels.
- Three nested pairs without hints all select 0.
- A level-2 leaf makes all three enclosing pairs level 2, not 2/3/4.
- Adding a level-3 hint outside the inner pairs produces levels 2/2/3.
- A level-4 request in a subscript also enlarges the outer pair to level 4.
  Protecting the script leaves the outer pair at 0.
- Moving the identical annotated tall fraction left/center/right leaves the
  selected level at 2 and the PDF delimiter glyph metrics identical.
- External scripts attach to the emitted closing math atom. This differs from
  native left/right's full inner atom and explains the closer scripts on page 1.
- The documented DelimSetup command is absent from this installed .sty; the
  fixture checks this with ifdefined. Do not assume every documentation example
  is operational in this release.

## Relevance to matchedsplit

Useful precedent: author-controlled local size hints can propagate outward
without exposing size arguments at every semantic notation macro. Treat this as
an optional override design, not an automatic optical-size algorithm. The package
is not a replacement for our geometry/distance experiment, rainbow, row boxes or
AMS alignment handling. It accepts a braced body and packages it into an hbox;
it does not itself implement cross-row delimiter continuation. No integration or
production code changes were made during this investigation.
