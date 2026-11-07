# finaldelim

LuaLaTeX-based delimiter layout with explicit line splitting, rainbow colors,
and adjustable sizing. This is an independent development project derived
from matchedsplit, not a release of the original package.

## Load the package

Place `finaldelim.sty`, `finaldelim-luatex.sty`, `finaldelim-interface.sty`,
`finaldelim-physics.sty`, `finaldelim-size.lua`, `finaldelim-draw.lua`,
`finaldelim-outline-fonts.lua`, `finaldelim-output.lua`, and `finaldelim.lua` beside your
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

Compile with LuaLaTeX. The manual and public examples use Latin Modern Math; the package itself does not select a font. `niji` aliases `rainbow` at package and environment
scope. Native amsmath handles alignment, row numbering and row spacing.
`debug=boxes`, `debug=alignment`, and `debug=all` enable diagnostics.

For DVI output, use the **LuaLaTeX -> dvipdfmx** route. Select the `dvipdfmx`
driver for color/graphics, for example with `\documentclass[dvipdfmx]{article}`,
and run:

```sh
lualatex --output-format=dvi document.tex
dvipdfmx document.dvi
```

The output mode and graphics driver are detected automatically. Continuous
outlines, niji, physical line breaks, numbering and debug overlays also support
`dvips` and `dvisvgm`. Select the corresponding document-class driver, then use
`dvips -o document.ps document.dvi` or
`dvisvgm --no-fonts --page=1- --bbox=papersize document.dvi`.
The package option `dvi-driver=auto|dvipdfmx|dvips|dvisvgm` can override detection;
it must agree with the color/graphics driver and the converter.

The PostScript and SVG routes use PostScript specials. dvisvgm therefore needs
its Ghostscript-backed PostScript handler. Traditional dvips retains its normal
font restrictions: use TFM/Type 1 fonts (for example `\usepackage[OT1]{fontenc}`
with traditional math), rather than LuaLaTeX's OpenType font output. For
`unicode-math`, use dvipdfmx or dvisvgm. This is separate from the outline paths,
which carry their own geometry. SVG debug hairlines use an explicit 0.1bp width.
Use a current TeX distribution; the regression suite is tested with TeX Live 2026.
Run `python run-dvi-tests.py` to compare direct PDF with converted DVI, including
Latin Modern Math, STIX Two Math, traditional TeX fonts and page-wide debugging.
`python run-driver-tests.py` additionally exercises dvips and dvisvgm, compares
rendered pages with direct PDF, and checks continuous outline geometry through
PostScript. Its raster comparison requires Poppler, Pillow, numpy, Node and sharp;
`FINALDELIM_SHARP` can point to an installed sharp module directory.

The new backend typesets continuous mathematics once, then physically partitions
its contents at explicit alignment/row markers. It does not use PDF clipping.
It does not select line breaks automatically or guarantee mathematical semantics.
The new algorithm targets LuaLaTeX; inherited legacy helpers are scaffolding.
Tagged-PDF support for physical partitioning has not been implemented.

## Sizing and native math interfaces

Weighted sizing is enabled by default. No Lua code is needed:

```latex
\usepackage[niji,lambda=20pt,q=8,scale=0.9,spanning=folded]{finaldelim}
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
Cross-row pairs use `spanning=folded` by default: intervening rows are
represented by 0.01em-wide measurement boxes with their maximum height and
depth. `spanning=endpoints` uses only delimiter-bearing row dimensions;
`spanning=full` uses the full-content weighted model. With one or more `\middle` delimiters,
every delimiter position contributes to the shared weighted radius. The
endpoint policy includes rows carrying middle delimiters too. Single-line
pairs use weighted sizing.
`sizing=native` disables weighted sizing while retaining colors and splitting.
See the English manual `finaldelim.pdf` for examples and parameter definitions.

## Continuous outlines

Use `\usepackage[render=draw]{finaldelim}` to draw continuous delimiter outlines.
The default `render=native` uses font glyphs. Both settings work in
`\FinalDelimSetup{render=draw}` and environment options such as
`\begin{equation}[render=draw]`. No extra package or experimental directory is
needed. Drawing loads on demand and falls back to glyphs for unsupported fonts
or shapes. The drawn PDF paths do not provide text extraction or tagging.

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

Keep `manual-examples/` and `manual-assets/` beside `finaldelim.tex` and compile the manual twice
with LuaLaTeX. The printed listings and rendered examples use the same files.
The manual follows writing problems: a tall central term (`lllhlll`),
outline steps and joins, nested pairs, then line breaks and existing-document
integration. Formula sources appear in footnotes; the line-breaking section
compares native amsmath with direct breaks in `equation`. The opening sizing
comparison typesets one shared source under both policies.

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

## Explicit environments

`fdequation`, `fdequation*`, `fdalign`, `fdalign*`, `fdalignat`, and
`fdalignat*` provide explicit finaldelim displays. `fdsplit` and
`fdaligned` provide embedded blocks; `fdaligned` takes `[t|c|b][options]`.
The standard equation, align and alignat interfaces are replaced by default.
Load `\usepackage[override=false]{finaldelim}` to retain the native standard
interfaces and use the fd-prefixed environments explicitly. This is a
load-time choice; sizing and niji still apply to delimiters in native math.
`overrideequation`, `overridealign`, and `overridealignat` allow individual
load-time choices. `overridesplit` remains opt-in.

The manual includes actual 96 dpi rasterizations of delimiter joins. Regenerate
them with `python manual-assets/build-joints.py` (Pillow and Poppler required).
Compile `debug-render-test.tex` and run `python test-debug-render.py` to verify
diagnostic overlays and unchanged glyph geometry.

`spanning=folded` retains delimiter-bearing rows and replaces each intervening
run of rows by a 0.01em-wide measurement box with the maximum height and depth.
It uses the weighted model, with the endpoint estimate as a lower bound. Actual
contents are unchanged; `folded` is the default. Compile `folded-test.tex`
and run `python test-folded.py` for independent quadrature and folding invariants.

The representative width is configurable with `fold-width=0.01em` at package,
setup, and environment scope. Positive TeX dimensions are accepted; relative
units are evaluated when typesetting each formula.

`render=draw` also draws native square/nth-root signs and overbars as a single
filled outline, preserving native size, index placement, scripts and spacing.
Integral signs remain native. Compile `experimental/radical-comparison.tex` and
run `python experimental/test-radicals.py` for four-font comparisons and geometry
checks. See `experimental/radical-rendering.md` for the integral audit.

Continuous drawing also covers horizontal font assemblies (over/underbraces and
expression arrows), wide accents, and amsmath centered-leader long arrows. It
preserves native dimensions, labels, attachment and script positioning. Compile
`experimental/stretch-comparison.tex` and run `python experimental/test-stretch.py`
for four-font comparisons. Complete accents retain their native selected size.

For weighted delimiters, `render=draw` uses the exact target height `2R` after
`scale`, without native delimiterfactor/shortfall or snapping to font sizes.
Prebuilt outlines are interpolation samples; larger constructions use continuously
adjusted connector overlap. Delimiter boxes and scripts follow the final extent.
Compile `experimental/continuous-lengths.tex` for the four-font size sweep and
assertions of actual outline bounds around every prebuilt-size boundary.
