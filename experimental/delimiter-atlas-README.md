# Delimiter construction atlas

Compile `experimental/delimiter-atlas.tex` with LuaLaTeX from the project root,
using `-output-directory=build`. Outputs: `build/delimiter-atlas.pdf` and
`build/delimiter-atlas.csv`.

This is a post-checkpoint experiment, not a change to finaldelim's renderer.
It compares Latin Modern Math and STIX Two Math at 10pt, for nine requested
heights (10 to 80pt) and ten delimiters. No finaldelim sizing is loaded.
Delimiter factor 1000 and shortfall 0 isolate the font's size selection.
Captions report the actual delimiter box height plus depth and glyph count;
the invisible sizing rule is excluded from these measurements. Glyph IDs and
widths are recorded in the CSV. Counts above one indicate component assembly.

Initial observations in this installed font set:
- At an 80pt request, Latin Modern parentheses use 13 glyph components;
  STIX Two uses 7. Both attain 80pt.
- Angle brackets stop at their largest available glyph in this native path:
  30pt for Latin Modern and 38.22pt for STIX Two, even at an 80pt request.
- The prebuilt-to-assembled transition differs by font and symbol.

Next investigation: extract and overlay outlines at equal scale to distinguish
actual contour discontinuities from rasterization artifacts. The atlas alone
is not evidence that every visible joint is a defect in the underlying outline.
