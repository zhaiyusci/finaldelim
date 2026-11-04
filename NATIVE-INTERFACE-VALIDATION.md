# Native interface validation ¡ª 2026-11-04

LuaHBTeX 1.24.0 (TeX Live 2026), LaTeX 2026-11-01.

- Native equation/equation-star, bracket displays, inferred multiple pairs,
  align row labels, matrices and cases: compiled successfully.
- Custom equation tag and label retained outside the inner aligned block;
  align notag does not consume a number. Aux values asserted independently.
- Source-side counter executes once; leqno/fleqn fixture compiles successfully.
- Inline native and weighted sizing with niji on/off: same glyphs, fonts,
  positions and scripts within 0.000286 PDF points. Only explicit delimiters
  colored, including nested script pairs and middle delimiters.
- Both flat-backend dimension fixtures (traditional and Unicode math) pass.
- Existing demo geometry, rainbow/debug geometry, 25-row page breaking,
  numbering and absence of repeated glyphs pass test-luatex-pdf.py. These
  native-geometry fixtures were compiled with sizing=native.
- Weighted sizing fixtures pass test-weighted-size.py: first/last-row envelope
  unaffected by middle-row height; full weighted mode differs; no clipping.
- Six-page English manual compiled twice and all pages visually inspected.

These checks do not establish tagged-PDF correctness. The new algorithm
remains LuaLaTeX-only; XeTeX/pdfTeX porting is outside this change.
