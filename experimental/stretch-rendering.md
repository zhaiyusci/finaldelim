# Horizontal symbol drawing

The existing `render=draw` option now handles horizontal font assemblies,
accent glyph boxes, and pure arrow constructions made by amsmath centered
leaders. It does not change native symbol sizes or label placement.

- Font assemblies: retain native part positions, shifts and effective glue;
  paint every contour with one nonzero fill.
- Long arrows: retain the arrowheads and initial/terminal pieces, expand the
  centered leader at its native offsets, and paint the combined contours once.
- Wide hats and tildes: retain the native chosen glyph or assembly. No new
  width interpolation or enlargement is applied.
- Fraction rules, overlines and underlines remain rules.

Mixed-font or unsupported constructions retain native rendering. Drawn
symbols are paths, so they no longer contribute glyph text extraction.

## Reproduce

Compile `experimental/stretch-comparison.tex` with LuaLaTeX from the project
root, using `-output-directory=build`, then run
`python experimental/test-stretch.py`.

The eight-page PDF compares native and drawn forms in Latin Modern Math,
STIX Two Math, XITS Math and Fira Math. It includes labels above and below
arrows, nested braces, colored bodies, short and wide accents, script styles,
and ordinary rules as controls. TeX asserts identical box dimensions; the PDF
check compares body/label/script glyph geometry and colors independently.
