# Continuous outline renderer

The prototype now loads the current math font at runtime. No pre-exported font
file or Python is needed to compile a document. See `outline-method.md` for the
fixed outline-v1 algorithm, supported cases and conservative fallbacks.

In this checkout:

```tex
\usepackage{unicode-math}
\setmathfont{STIX Two Math} % or another supported outline math font
\usepackage{experimental/finaldelim-draw}
```

Use `\FinalDelimDrawOn` / `\FinalDelimDrawOff` to compare renderers; these settings
are local to the TeX group. Sizing, niji and direct equation/align breaks keep the
usual finaldelim interface. The experimental package is not the production default.

Build from the project root with LuaLaTeX and the eight fonts listed below.
Python checks need fontTools, numpy, scipy, matplotlib, Pillow, pdfplumber,
pypdf and reportlab; PDF rendering uses pdftoppm. Generated data and PDFs stay
under the ignored build directory. The Lua renderer itself needs no Python.

```powershell
New-Item -ItemType Directory -Force build
python experimental/measure-diagonals.py
python experimental/build-inventory.py
foreach ($sample in @('outline-comparison','outline-crossfont','outline-test',
    'outline-sans','outline-all','outline-slash-angle','outline-inventory')) {
    lualatex -interaction=batchmode -halt-on-error -output-directory=build experimental/$sample.tex
}
pdftoppm -scale-to 1100 -png build/outline-slash-angle.pdf build/outline-slash-angle
python experimental/test-outline.py
python experimental/test-outline-all.py
python experimental/test-outline-slash-angle.py
python experimental/test-diagonal-terminals.py
python experimental/bundle-delimiters.py
```

The final combined artifact is `build/delimiters.pdf` (91 pages, with bookmarks).
The scheme is fixed as outline-v1: per-font contour interpolation, single-fill
native assemblies, and terminal-preserving extension of six diagonal delimiters.
It remains opt-in through `experimental/finaldelim-draw.sty`.

The comparison has four pages for Latin Modern and STIX Two; the cross-font
comparison has six pages, adding Pagella, Termes, XITS and Libertinus.
The same renderer reads all six without per-font code. Current tests verify native
assembly box dimensions and body/script positions, source-once behavior, local
renderer scope, labels, nesting colors and lack of clipping.

`export-outline-fonts.py` and `build/outline-font-data.lua` belong to the earlier
offline prototype and are no longer used by the renderer. Python/fontTools remain
useful for the independent fitting studies and data inspection.

Sans-serif sample: compile experimental/outline-sans.tex to build/outline-sans.pdf.
It compares Fira Math and GFS Neohellenic Math at four heights and in complete
formulas. See outline-method.md for contour correspondence and its conservative guards.
The geometry fixture now includes both families (eight fonts total).

Unified collection: compile experimental/outline-all.tex with LuaLaTeX into
build/outline-all.pdf, then run experimental/test-outline-all.py. This is the
single review document for all eight fonts: three pages per font (paired height
atlas, intermediate-height sweep, complete formulas) plus a page index. Run
experimental/test-outline.py as well for the detailed body/script geometry tests.

Slash/angle comparison: experimental/outline-slash-angle.tex generates one
17-page PDF (index, eight single-diagonal pages and eight double-angle pages). Each page compares native and continuous
slash, backslash, left angle and right angle at 10, 14, 18, 24, 32, 48, 64 and
96 pt targets. Run experimental/test-outline-slash-angle.py after compiling.
In this sample LM angles plateau at large targets, while Fira slashes remain
small and its angles grow. These behaviors occur in native rendering. The experimental renderer now
extends these six diagonals beyond the largest prebuilt size using the recent
width trend and separately controlled normal stroke thickness.

Diagonal extrapolation measurements (2026-11-04)
------------------------------------------------
Reproduce with experimental/measure-diagonals.py. Outputs are
build/diagonal-measurements.json, .csv and .png. All four diagonal delimiters
are measured in eight fonts at 10pt. Only prebuilt glyphs are measured.
Width/height are ink bounds; stroke thickness is measured normal to the arm
from horizontal sections at 60--85% of glyph height. Cubics are flattened at
128 steps. This is a geometric measurement, not a perceptual study.

Most large slash variants retain nearly constant arm slope. Angle variants
in STIX2, Pagella, Termes, Libertinus and Fira progressively narrow relative
to height; LM and GFS are closer to constant arm slope. Thus uniform scaling
is not a general font-preserving extrapolation policy.

Hold out the largest variant and predict its ink width using preceding data.
Mean absolute errors in pt for fixed width / proportional width / a linear
fit to the last three preceding sizes:
slash: 3.5943 / 0.1780 / 0.0835 (7 fonts; Fira has only one slash glyph).
left angle: 0.7711 / 0.3089 / 0.0416 (8 fonts).
These are near-range prediction errors, not validation of arbitrarily tall
extrapolation or a proof of visual quality. Fonts are not independent designs.

Candidate: beyond the largest prebuilt height H0, anchor width at W0 and
continue a nonnegative local width slope m: W(H)=W0+m*(H-H0). Obtain m from
recent variants; for a single available glyph derive an arm slope instead.
Construct the strokes geometrically rather than affine-scaling the whole
outline, so normal stroke thickness is controlled independently. Start by
retaining the largest glyph's normal thickness for an experimental comparison;
font measurements do show some thickening with height, so this is a conservative
new policy, not an exact continuation of every typeface. Preserve terminal and
vertex treatment where feasible. This policy is now enabled for slash, backslash and single left/right angles
in the opt-in experimental renderer. The production package is unchanged.


Implemented diagonal extension
------------------------------
The last three distinct prebuilt glyphs provide a nonnegative least-squares
ink-width slope, anchored at the largest glyph. A single available glyph uses
its measured arm slope (half for angles). Upper-arm sections estimate the
centerline; each contour point is mapped relative to that centerline. Vertical
coordinates reach the requested ink height. Horizontal centerline growth is
solved to reach the predicted ink width; horizontal stroke offsets are multiplied
by sqrt(1+new_slope^2)/sqrt(1+old_slope^2) to retain normal thickness. Original
terminal/vertex contours are mapped too, with cubic curves flattened at 96 steps.
The map tends to the original outline at the prebuilt boundary (up to flattening
error). Original side bearings are retained and the box advance follows ink-width
growth. Niji remains inherited from the enclosing PDF color state.

Validation: all 32 exported 96pt contours (four symbols, eight fonts) match target
height and predicted width, and retain measured largest-glyph stroke thickness
within 0.006pt. Run measure-diagonals.py before test-outline-slash-angle.py to
provide the independent source-font measurements. This validates geometry,
not a universal claim about aesthetic preference at extreme sizes.

Complete inventory and unified report
-------------------------------------
Run build-inventory.py to enumerate the local unicode-math table's vertical
fence/open/close symbols, excluding exclamation, radicals and long division,
and adding slash, backslash and six vertical arrows. The 69-symbol inventory
covers eight installed fonts (552 entries). Missing source glyphs are printed
as missing. Each present glyph is compared at 14, 32 and 64 pt using an explicit
Unicode delimiter code, so command aliases do not change the tested geometry.
Font coverage and MATH construction type are saved in build/delimiter-inventory.json.

Compile experimental/outline-inventory.tex, run the existing outline and diagonal
tests, then run experimental/bundle-delimiters.py. The latter checks inventory
coverage, absence of rendering fallbacks/overflow/clipping, and bundles the core
comparisons, diagonal experiments and inventory into build/delimiters.pdf with
bookmarks and a coverage summary. Fixed glyphs without variants or assembly keep
the native size limit; diagonal extension is the documented exception.


Terminal preservation and double-angle extension
------------------------------------------------
The original height map also stretched terminal details; in Fira a slash tip
transition grew from about 0.163pt to 1.718pt at 96pt target height. The height
map now protects terminal neighborhoods (and the angle vertex) in absolute font
units and extends only the intervening straight sections. The centerline map
and independent normal-thickness compensation still determine width and weight.
The protected margin is min(15% of source height, twice the measured horizontal
stroke width). The map is continuous and becomes the original outline at the
prebuilt boundary, up to curve-flattening error.

U+27EA/U+27EB now extend too. Split the two source contours by geometric position,
extend each using its own variant history, and retain original relative vertical
offsets. Correct the second contour's horizontal translation to retain original
stroke-center separation at the upper quarter-height reference section. Stroke
spacing is not scaled with height. Other fixed-size symbols retain native limits.

The diagonal PDF now has 17 pages: index, eight single-diagonal pages, eight
double-angle pages (32, 64, 96, 144pt). test-diagonal-terminals.py compares exported
slash terminal transition lengths against original font outlines and checks both
double-angle strokes. Fira's exported 96pt tip transition is now 0.1626pt, matching
the original. The combined report has 91 pages. These checks complement the
existing full inventory, normal-thickness, box/script, niji and line-break tests.
