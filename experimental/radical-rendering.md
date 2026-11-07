# Native-size radical drawing

`render=draw` converts the already laid-out root sign and its overbar to one
nonzero-filled PDF path. It preserves the sign box dimensions and shift and
replaces the overbar rule with a kern of the same vertical extent. The
radicand, degree and scripts are untouched. No weighted sizing is applied to
radicals. Unsupported shapes/fonts keep native output.

The renderer identifies native radical boxes and verifies the sign glyphs
against the current font's root variants/assembly parts. It uses the existing
font outline loader, including its transformed-font restrictions. The overbar
contour is wound consistently with the root contour so overlap remains filled.

## Reproduce

From the project root, with a writable LuaTeX font cache:

```powershell
lualatex -interaction=batchmode -halt-on-error -output-directory=build experimental/radical-comparison.tex
python experimental/test-radicals.py
```

`build/radical-comparison.pdf` has native/drawn page pairs for Latin Modern
Math, STIX Two Math, XITS Math and Fira Math. Samples include inline and script
styles, nested and indexed roots, tall fractions, an eight-row matrix, colors,
ordinary integrals, multiple integrals, contour integrals and explicit limits.
TeX asserts identical native/drawn box dimensions. PDF tests verify the same
body, degree, script and integral glyph positions/colors, with only root-sign
glyphs replaced by paths. The original overbar is removed, not painted twice.

## Integral audit

`build/integral-audit.txt` inspects the font instances actually used by the
integral test box. All four fonts supply two variants for U+222B, U+222C,
U+222D and U+222E. Each ordinary displayed operator uses one complete glyph.
STIX Two Math additionally supplies a vertical assembly for U+222B; its ordinary
integral does not use that assembly. The other audited operators have no
vertical assembly. This is a statement about these fonts and formulas, not
all integral fonts or manually stretched integrals. No integral replacement
is installed.
