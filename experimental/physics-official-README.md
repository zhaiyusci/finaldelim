# Official physics manual compatibility build

Upstream: Sergio C. de la Barrera, physics 1.3, LPPL.
Source: https://ctan.org/tex-archive/macros/latex/contrib/physics (physics.tex).
The local original comes from TeX Live 2026's doc/latex/physics directory.

`physics-official-finaldelim.tex` is a renamed, attributed adaptation. Only the
preamble is changed; the complete document body and all official examples are
retained. The test verifies body equality against a pristine copy.

Run from the project root:

```powershell
./experimental/build-physics-official.ps1
python experimental/test-physics-official.py
```

The default adapted source can also be compiled directly from the project root:

```powershell
lualatex -interaction=nonstopmode -halt-on-error -output-directory=build experimental/physics-official-finaldelim.tex
```

Outputs:

- `build/physics-official-original.pdf`: pristine official source, LuaLaTeX.
- `build/physics-official-classic.pdf`: original math fonts, finaldelim and niji.
- `build/physics-official-finaldelim.pdf`: Latin Modern Math, finaldelim, niji and
  continuous outlines.

All three are eight pages. There are no missing-glyph warnings. The full renderer
reports zero outline fallbacks. The seven overfull boxes in the original tables
remain (their widths can change with font/sizing); the test does not rewrite the
upstream layout to hide these existing warnings. The upstream source uses the
compilation date in its title; it is not a new upstream release date.

## Findings and changes

The official source exposed a real interface regression: displaymath expands
its begin/end into bracket-display commands, whereas finaldelim's bracket
interface collects a literal closing token. This made the document run away
while looking for the terminator. Production displaymath now retains native
streaming display behavior, including verbatim material in the official examples.
Use equation-star or bracket displays for finaldelim's explicit outer line breaks.
`displaymath-test.tex` covers this interaction alongside numbered equations and
ordinary finaldelim breaks; the existing native-interface regressions also pass.

Separately, physics and unicode-math compete over div, Re and Im. Unicode-math
installs math symbols at begin-document; physics saves traditional symbol aliases
and reuses the names as operators. Without a preamble adaptation, divisionsymbol
can be missing and real/imaginary can become less-than/equals. The Unicode sample
preserves physics' operator definitions at begin-document and maps its three
legacy symbol aliases to the correct Unicode characters. This adjustment is
confined to the adapted manual; it is not hidden in finaldelim's sizing code.
The original/classic variants do not need this font-specific adaptation.

The official manual mostly exercises math inside tables and traditional displays.
It complements, rather than replaces, physics-regression.tex and the 130 probes
that exercise finaldelim's outer argument-break scanner.
