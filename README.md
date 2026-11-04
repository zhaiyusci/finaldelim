# finaldelim

LuaLaTeX-based delimiter layout with explicit line splitting, rainbow colors,
and adjustable sizing. This is an independent development project derived
from matchedsplit, not a release of the original package.

## Load the package

Place `finaldelim.sty`, `finaldelim-luatex.sty`, `finaldelim-interface.sty`,
`finaldelim-physics.sty`, `finaldelim-size.lua`, and `finaldelim.lua` beside your
source, or under `tex/latex/finaldelim/` in a personal TEXMF tree.

```latex
\documentclass{article}
\usepackage[niji]{finaldelim}
\begin{document}
\begin{equation}
 F &= \left[a+b+\\
   & \frac{x}{y}+c\right]^2
\end{equation}
\end{document}
```

Compile with LuaLaTeX. The manual and public examples use Latin Modern Math; the package itself does not select a font. Existing environment names `matchedsplit`,
`matchedaligned`, `matchedalign`, `matchedalign*`, `matchedalignat` and
`matchedalignat*` are retained. `niji` aliases `rainbow` at package and environment
scope. Native amsmath handles alignment, row numbering and row spacing.
`debug=boxes`, `debug=alignment`, and `debug=all` enable diagnostics.

The new backend typesets continuous mathematics once, then physically partitions
its contents at explicit alignment/row markers. It does not use PDF clipping.
It does not select line breaks automatically or guarantee mathematical semantics.
The new algorithm targets LuaLaTeX; inherited legacy helpers are scaffolding.
Tagged-PDF support for physical partitioning has not been implemented.

## Sizing and native math interfaces

Weighted sizing is enabled by default. No Lua code is needed:

```latex
\usepackage[niji,lambda=20pt,q=8,scale=0.9,spanning=endpoints]{finaldelim}
% Or change subsequent formulas:
\FinalDelimSetup{spanning=full}
```

`equation` accepts `&` and `\\` directly, with one outer number.
`equation*` and `\[...\]` are unnumbered; `align` numbers each row.
Multiple column pairs are inferred. `alignat` retains its explicit pair count.
Display options such as `\begin{equation}[niji=false,spanning=full]` are local.
Nested matrices, cases and embedded alignments keep their own markers.

Inline `$\left[a+\left(b+c\right)\right]^2$` receives niji colors too.
Ordinary delimiters are not scanned; inline math is not split into rows.

The default `scale=0.9` reduces the target radius by ten percent without distorting glyphs.
Use `scale=1` for the full estimated radius.
The option works at package, setup, and environment level; native sizing is unaffected.

Selected defaults are a fixed physical decay length of 20pt, q=8, maximum over delimiter positions, and scale=0.9.
Cross-row pairs use first/last-row dimensions by default; `spanning=full`
uses the full-content weighted model. With one or more `\middle` delimiters,
every delimiter position contributes to the shared weighted radius. The
endpoint policy includes rows carrying middle delimiters too. Single-line
pairs use weighted sizing.
`sizing=native` disables weighted sizing while retaining colors and splitting.
See the English manual `finaldelim.pdf` for examples and parameter definitions.

## Validation

From this directory:

```powershell
$env:TEXMFVAR = Join-Path $PWD 'build/texmf-var'
$env:TEXMFCACHE = $env:TEXMFVAR
lualatex -interaction=nonstopmode -halt-on-error -output-directory=build experimental/weighted-size-demo.tex
lualatex -interaction=nonstopmode -halt-on-error -output-directory=build experimental/weighted-size-test.tex
python experimental/test-weighted-size.py
```

Compile `native-interface-test.tex` and `inline-interface-test.tex`, then run
`python test-native-interface.py` for native display tags and inline color geometry.
Compile `inline-weighted-test.tex` and run
`python test-native-interface.py build/inline-weighted-test.pdf` for weighted sizing.
`quickstart.tex` is a standalone public example.

Additional fixtures include `luatex_flat_test.tex`, `luatex_flat_unicode_test.tex`,
`luatex_render_test.tex`, and `luatex_pagebreak_test.tex`. Historical experiments
and inherited maintenance scripts remain available for development.

## Author and license

Yu Zhai <me@zhaiyusci.net>. LPPL 1.3c or later; see LICENSE and MANIFEST.md.
No public repository or release has been created for finaldelim yet.
See [project provenance](PROJECT.md) for its relationship to matchedsplit.

## Building the manual

Keep `manual-examples/` beside `finaldelim.tex` and compile the manual twice
with LuaLaTeX. The printed listings and rendered examples use the same files.
Formula sources appear in footnotes; the line-breaking section compares native
amsmath with direct breaks in `equation`.

Middle-delimiter validation: compile `middle-test.tex`,
`middle-profile-test.tex`, `middle-endpoint-test.tex`, and `middle-comparison.tex`. The traditional-font
variant uses `\def\TraditionalMath{1}\input{middle-test.tex}` with job name
`middle-traditional`. Run `python test-middle.py` for PDF geometry, coloring,
numbering and independent numerical integration checks.

Scale validation: compile `max-scale-sample.tex` and `scale-test.tex`, then run
`python test-scale.py`. The sample compares native sizing, maximum with scale 1,
and maximum with scale 0.9 in STIX Two Math.

## Physics

Load `physics` and `finaldelim` in either order. Integration is automatic:
macro-generated delimiters receive niji in inline and display math, automatic
`\qty`, `\bqty`, `\abs`, `\norm` and related argument bodies accept outer
breaks, and `\mqty` / `\smqty` retain their internal matrix rows and columns.
Starred arguments, fractions, scripts and unknown macros remain indivisible.
See manual section 3.8 and `experimental/physics-compat-README.md` for the tested
scope and reproducible PDF geometry regressions.
