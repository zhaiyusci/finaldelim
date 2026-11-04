# Physical partition reference backend

This directory is an **experimental LuaLaTeX implementation**, not a replacement
for the public `matchedsplit` package. The public package retains its existing
engine support. No release decision about engines has been made.

## Model

The formula is evaluated once as a continuous display-style math list. Explicit
`&` and `\\` tokens become zero-width cut markers. TeX performs mathematical
spacing, delimiter construction, and script positioning before partitioning.

The backend then moves the resulting contents into cells and rows. A box with
no cut inside remains opaque, including its original shift. Only horizontal
wrappers containing cuts are opened; their fragments retain the wrapper's
shift. Fractions, radicals, operator limits, and script contents are not
reconstructed. There is no automatic line-break selection or PDF clipping.
The delivered split display contains the moved nodes, not a complete formula
repeated behind clipping windows.

Every render checks that rejoining the fragments preserves glyph and rule
positions to the nearest scaled point. A temporary copy is made for this check
and freed; it is not shipped to the PDF. Only the `\FlatCompare` test command
deliberately prints native, rejoined, and split versions for comparison.

## Usage and validation

Run from the repository root:

```powershell
./experimental/test-flat.ps1
python experimental/check-flat-pdf.py
```

The Python check needs `pdfplumber`. The PowerShell harness uses hidden compiler
processes and writes only under `build/`. It derives `build/flat-demo.tex` from
the user's current `demo.tex` without editing the original. Both matched
examples use the new uncolored core; the native `split` comparison is retained.

The experimental interface is:

```latex
\usepackage{experimental/flat-core}
\begin{equation}
  \begin{flatmatchedsplit}
    f&=\left(a+b\\&+c\right)^2_i
  \end{flatmatchedsplit}
\end{equation}
```

The fixtures cover ten formulas with Computer Modern and XITS Math: fractions,
spanning and nested delimiters, superscripts and subscripts on spanning pairs,
middle and invisible delimiters, radicals, operator limits, and explicit
alignment points. Two counter checks establish single source evaluation.
The independent PDF check compares native/rejoined positions (0.003 pt
tolerance) and verifies that split displays contain the expected character
sequence. The user's demo is compared per row against native `split` with a
0.006 pt tolerance; row placement is deliberately excluded.

## Unfinished integration

- This implementation requires LuaLaTeX. Pure TeX experiments established real
  partitioning of flat lists and shallow unpacking of native delimiter boxes,
  but `\lastbox` resets a retrieved box's shift. Retaining attached-script shifts
  in a general XeLaTeX/pdfLaTeX implementation remains unresolved.
- Rainbow coloring is not implemented here. The public package's color
  transformation is deliberately not reused to alter the new math list.
- Active PDF tagging is rejected. Structural tagging needs a separate design
  and regression pass before this backend can be used in tagged documents.
- The small input adapter recognizes literal top-level `&` and bare `\\`.
  Nested alignment environments, `\\[length]`, starred breaks, `\intertext`,
  per-row tags, and the production package's options are not integrated.
- The demonstration row builder uses alternating right/left cells and a simple
  baseline gap. It does not yet reproduce all amsmath placement policies,
  including `tbtags`, `fleqn`, and page breaks.
- Breaks inside vertical structures are unsupported. The model assumes cuts
  between the user's top-level formula pieces, not inside fraction/script
  internals. Only left-to-right formula boxes are supported.

These limitations are reasons to keep the backend isolated, not claims that
the complete package rewrite is finished.

## XeTeX output-level alternative

`xe-output.sty` now demonstrates a different implementation of the visual
model. XeTeX retains one native formula box; xdvipdfmx translates disjoint
output ranges at the user's explicit cuts. **This is not physical partitioning
of TeX's node list.** In the PDF, each glyph/rule is emitted once at its final
row position. There is no clipping, hidden full-formula copy, or script
reconstruction. The native script shift is never extracted or lost.

`zref-savepos` records untransformed cut coordinates. A subsequent compilation
uses their differences to compute cell widths and alignment translations.
`pdf:btrans matrix 1 0 0 1 x y` / `pdf:etrans` bracket each range. The outer box
reports the resulting grid dimensions. The prototype uses a conservative
uniform baseline step based on the complete native formula's height and depth.
It therefore does not yet match amsmath's row spacing.

Run `./experimental/test-xe-output.ps1`, then
`python experimental/check-xe-output.py`. The harness runs three compilation
passes for stable saved positions, using hidden compiler processes. It also
derives an uncolored test from the current user demo without editing it.
Five XITS Math fixtures cover scripts on spanning pairs, three-row nesting,
alignment, middle delimiters and invisible delimiters. The PDF check verifies
identical character counts/order, unchanged relative positions within each
moved range, and the absence of clipping operators and form XObjects. Maximum
observed within-range PDF displacement error was below 0.01 pt (0.012 pt test
tolerance). These are output-coordinate checks, not a proof for arbitrary input.

The explicit experimental environment is `xeflatmatchedsplit`. This research
adapter still needs production integration: rerun diagnostics for stale/missing
positions, amsmath row spacing/numbering policies, rainbow, nested environments,
optional row spacing, and links/annotation rectangles inside formulas. Tagged
output is rejected. Page breaks within the grid are not implemented. Direct
XeTeX node-list partitioning with script-shift retention remains unresolved;
the output-level path avoids needing that operation.

Driver reference: [Dvipdfmx User's Manual](https://tug.org/dvipdfmx/doc/dvipdfmx/dvipdfmx.pdf),
transformation specials. The formal package remains unchanged by these experiments.

## Delimiter sizing experiments

See [Delimiter sizing](delimiter-sizing-README.md) for the selected adjustable
defaults (lambda=20 pt, q=8, p=3), model, comparisons and reproduction commands.
