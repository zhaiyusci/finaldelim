# First contour-fitting experiment

This experiment does not modify the package renderer. It consumes the actual
LuaTeX glyph indices and assembly placements exported by `delimiter-atlas.lua`,
and reads the corresponding OpenType outlines with fontTools. It does not fit
raster pixels. Coordinates and errors below are in TeX points at a 10pt font size.

## Reproduction

From the project root, compile `experimental/delimiter-atlas.tex`, then run
`experimental/fit-delimiters.py` with Python, numpy, scipy, matplotlib and fontTools.
The script also looks in `build/fit-deps` for project-local dependencies.
Results: `build/delimiter-fit.pdf`, `build/delimiter-fit.json`, and
`build/double-bar-fit.json`. Compile `experimental/double-rule-comparison.tex`
for a separate native-glyph versus TeX-rule comparison using the same PDF backend.

## Parentheses model

The initial model is symmetric about the vertical midpoint. For total ink
height H, let t = 2|y|/H, and u = max(0, (t-f)/(1-f)). Define the left and
right boundaries of a left parenthesis by

    x_outer = x0 + A * [1 - (1-u^k)^(1/k)]
    x_inner = x_outer + T * (1-u^2)^gamma

The six fitted parameters are horizontal offset x0, bend width A, central
stroke thickness T, straight-middle fraction f, curvature exponent k, and
taper exponent gamma. The contours meet at the tips. The model uses one
continuous filled outline rather than separate glyph components. It is an
experimental approximation, not a finished typographic design.

Flattened cubic/quadratic curves are intersected at 301 horizontal sections
(excluding the outermost 0.5% near either tip). Least squares fits both boundary
positions, with three starting values for f. Reported RMS is horizontal boundary
error, not a perceptual score or a full Hausdorff distance. Tip fidelity and
curvature need separate evaluation. Original contours remain visible in gray.

Individual-height fits:
- Latin Modern Math: RMS 0.026–0.048 pt.
- STIX Two Math: RMS 0.021–0.041 pt.

To check prediction rather than only fit known shapes, train at requests
10, 18, 30, 48 and 80pt; interpolate the parameters by actual ink height; hold
out requests 14, 24, 36 and 64pt. Hold-out RMS:
- Latin Modern Math: 0.032, 0.050, 0.078, 0.072 pt.
- STIX Two Math: 0.039, 0.036, 0.626, 0.043 pt.

The STIX failure around the prebuilt/assembled transition is substantial. A
single interpolated parameter curve across that transition is not yet suitable
for production. More sizes and a deliberate transition policy are required.

## Double bar: no curve fit needed

For the STIX 64pt double bar, native output contains eight components. Horizontal
sections of their vector union have constant stroke width 0.57pt and centre-line
spacing 1.60pt: the visible joints are not widening of the vector union. Two filled
rectangles with those dimensions produce a continuous double bar. The separate
LuaLaTeX comparison demonstrates the disappearance of the repeated visible joints
in the tested Poppler render. Font hinting and rule rasterization can still differ
in apparent weight; this experiment does not claim pixel-identical rendering.

All experimental changes remain outside the committed package implementation.
