# Endpoint-size experiment

Run from the repository root with LuaLaTeX:

    lualatex -output-directory=build experimental/endpoint-size-comparison.tex
    lualatex -output-directory=build experimental/endpoint-size-test.tex
    python experimental/test-endpoint-size.py

The opt-in callback is not loaded by the production package.

Pipeline:
1. Parse source once, retaining explicit row/cell markers and math groups.
2. Measure copies of parsed nodes; obtain the first and last endpoint cells'
   height and depth. Other alignment groups in intermediate cells are excluded.
3. Generate native delimiter boxes against a zero-width measurement rule using
   those dimensions. Native left/right selects the glyph and centers it on the
   math axis. The measurement rule is discarded.
4. Lay out the complete continuous contents with those delimiter boxes. A
   spanning group's enclosing box advertises the last cell's attachment metrics
   to its parent math atom, so native script layout uses the endpoint dimensions.
   Every child box keeps its real dimensions and position. Nested spanning
   groups are processed inside out, including transparent color wrappers.
5. The existing backend physically partitions the final continuous list and
   repacks actual cell contents. AMS layout receives their real heights/depths.

No source tokens are replayed and no rendered glyphs/scripts are repositioned.
The comparison checks source execution counts and pair counts. Existing
partition assertions verify leaf positions and width against the final continuous
box. Independent PDF checks compare the endpoint expression and scripts against
native one-line math, and the middle fraction against the unoptimized formula.
A second page exercises tall endpoints, nested spanning pairs, rainbow and debug.

Still experimental: not a public option. Explicit-size fences, middle delimiters,
math choices, unusual style transitions and cuts through vertical structures need
further design/tests. This policy measures endpoint cells, not whole-row maxima.
The package's existing tagged-PDF and non-LuaTeX paths are unchanged.
