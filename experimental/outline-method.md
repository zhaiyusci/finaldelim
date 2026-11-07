# Outline-v1: font-independent delimiter construction

This is the fixed algorithm for the experimental renderer. Font names do not
select different algorithms or numerical parameters. New fonts are read through
luaotfload at runtime; no Python preprocessing or handwritten Lua in the user's
document is required.

## Inputs and coordinates

Read the current mathematical font, its glyph indices, prebuilt `next` chain,
outline units, advances and native assembly nodes. Obtain outlines from
`fonts.handlers.otf.readers.loadshapes`, with a per-compilation file/subfont cache.
Compute actual ink bounds, including cubic Bezier extrema. Express target height
in that font's design units using the current math-style font size. Alignment is
about the current mathematical axis. The requested total height is twice the
already scaled model radius. Native delimiterfactor/shortfall apply only to
native rendering, not to continuous drawing.

## Prebuilt range

Choose the adjacent ink heights H0 and H1 enclosing H, and define

    t = (H-H0)/(H1-H0).

Interpolate advances with the same t. Below the smallest glyph, scale that
outline vertically to the target, retaining its horizontal stroke width.
At the tabulated heights, use the corresponding original outline.

1. If the paths have the same command sequence and their on-curve endpoints
   correspond geometrically, interpolate each cubic control point linearly.
   Normalize endpoints to each ink bounding box to check correspondence; a
   displacement above 1/4 of a box dimension rejects direct path interpolation.
   Matching command counts alone is insufficient: TeX Gyre Termes angle brackets
   exposed a differently anchored path with the same operator sequence.
2. Otherwise, match complete contours by geometric position, winding, anchor and
   normalized perimeter as described below. Preserve the vertices of both paths.
3. If contour matching is rejected, interpolate horizontal ink intervals at matching normalized heights.
   The grid contains 1025 uniform positions plus the original on-curve endpoint
   heights. Cubic curves use 96 subdivisions for this fallback's intersections.
   Separate intervals remain separate: gaps in a double stroke must not be filled.
   An interval count that changes within/between profiles is unsupported and
   retains native rendering rather than inventing a correspondence.

The result is a single compound filled path. The interpolated outline is centred
on the math axis. This constructs shapes between available font designs; it is
not a global polynomial fit, and it makes no claim that every font has a universal
parenthesis formula. The endpoint-correspondence check is a conservative heuristic,
not proof of compatibility for every possible font design.

## Beyond the prebuilt range

Read the font's vertical assembly parts, full advances and connector lengths.
Repeat extenders equally, and choose connector overlap continuously within the
font's permitted range to reach the requested ink height exactly. Correct the
first/last advances for actual outline bounds. Preserve cap and cusp geometry;
collect original outlines into one fill. Center the result on the math axis and
give its box the resulting extent so scripts attach to the drawn delimiter.
For the six diagonal delimiters listed below, use geometric extension instead.
When no assembly is available, or a gap exists between the last prebuilt glyph
and the shortest legal assembly, vertically extend the last prebuilt outline.
This may change curvature in that range; it never snaps the length to a font
size. Bar outlines remain straight with unchanged stroke width.

## Unsupported inputs and scope

Unreadable outlines, unavailable codepoints, unhandled component nodes and rejected
profile correspondences retain native rendering. Transformed faces and explicitly
selected variable instances currently retain native rendering; loading an unmodified
base outline would be incorrect. The source adapter can be extended independently of
the interpolation algorithm. Text extraction/tagging for the drawn delimiter paths
is not implemented. Drawing is enabled with `render=draw`.

## Cross-font verification

The same runtime implementation was compiled with Latin Modern Math, STIX Two Math,
TeX Gyre Pagella Math, TeX Gyre Termes Math, XITS Math and Libertinus Math.
`outline-crossfont.tex` renders 20pt and 64pt target atlases and an actual formula
for each. The samples have no native fallbacks. `outline-test.tex` checks source execution in eight fonts, including Fira and GFS; `test-outline.py` checks
body/script coordinates, niji colors, scope, labels and absence of clipping.
This is the verified test set, not a claim that every installed math font is tested.

## Exact-length regression

Compile `experimental/continuous-lengths.tex`. Its Lua assertions cover 2,638
target lengths in Latin Modern Math, STIX Two Math, XITS Math and Fira Math.
They include both sides of every prebuilt-size boundary, short targets and
targets up to 100pt. The test reads the emitted PDF path commands and computes
their actual cubic extrema: ink height and axis must agree with the requested
values within 8sp, and box height plus depth within 1sp. This tests the painted
outline, not just the box dimensions. The PDF supplies a visible size sweep
with middles and scripts; `outline-test.tex` checks body geometry and script
attachment separately in eight fonts.

## Stroke weight is separate

Keep the font's stroke geometry in outline-v1; do not add a font-name exception.
At 10pt, STIX Two Math's single bar and each stroke of its double bar are 0.57pt
wide. Its square-bracket stem grows from 0.79pt to 1.12pt across the prebuilt sizes.
Thus their relative weight differs in the original outlines. Font hinting versus
PDF path rasterization can additionally change apparent weight. Any future optical
stroke compensation should be an independent documented setting, not a change to
size interpolation or an unexplained STIX-specific constant.

Sans-serif coverage (2026-11-04): Fira Math and GFS Neohellenic Math
are exercised at 12, 20, 32 and 64 pt, plus a 11.5--16.5 pt bracket/brace
sweep. Formula tests cover scripts, middle fences, nested niji and numbered breaks.
The sample uses mathsf F because Fira lacks script F.

## Differently segmented contours

Before horizontal-section interpolation, try matching complete closed contours.
Flatten cubic segments with 96 subdivisions, align winding and choose the bottommost (then leftmost) vertex as a common
geometric anchor, and parameterize each contour by arc
length in that normalized coordinate system. Merge both sets of vertex parameters;
interpolate at this shared grid. This retains corners from both outlines and does
not impose a constant number of horizontal intersections. Contours remain separate.
Reject the match if any paired normalized coordinate differs by more than 0.12;
then try the existing section method or retain the native glyph. This guard is
heuristic, not a guarantee for arbitrary topology or reordered contours.

This handles GFS square brackets whose adjacent variants differ in curve count
and starting point. Flared terminals are retained instead of flattened into a
rectangular envelope. No font-name exception or stroke-weight adjustment is used.


Diagonal extension exception
----------------------------
For U+002F, U+005C, U+27E8, U+27E9, U+27EA and U+27EB, sizes above the prebuilt range now use
centerline-based geometric extension rather than retaining a capped glyph.
See outline-renderer-README.md for the anchored width trend, normal-thickness
preservation and measured validation. Other delimiters retain the assembly rule.

Multi-contour correspondence correction
---------------------------------------
The complete inventory exposed GFS double-angle variants that reverse the order
of their two independent contours between sizes. Contour correspondence now sorts
components by geometric bounding-box position before winding/anchor normalization
and the existing shape-distance guard. This fixes both U+27EA and U+27EB at 32pt
without a font-name exception. The full inventory's zero-fallback assertion is
also a regression check for this case.

Terminal neighborhoods and the angle vertex now keep their absolute vertical
extent; only straight middle sections grow. Double angles use per-contour
extension plus a source-spacing constraint. See the terminal regression tests
and the latest section of outline-renderer-README.md for details.
