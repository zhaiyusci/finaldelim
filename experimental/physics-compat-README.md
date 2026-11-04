# Physics integration tests

The production package automatically enables the adapter when physics is loaded,
in either order. The adapter lives in `finaldelim-physics.sty`; no experimental
bridge or extra user option is required. The outline renderer is still optional.

The original audit at commit 4536d3f recorded niji grouping failures, uncoloured
macro-generated display fences, matrix parser failures, ignored braced breaks,
and grouping-dependent weighted sizes. These are now regression cases.

## Coverage

`physics-cases.json` supplies inline/display and niji-off/on probes. It includes
ordinary and nested delimiter commands, derivatives and trigonometric function
arguments, bra-ket notation, matrices and small matrices, starred/manual sizing,
operator lookahead (`tr` followed by `qty` or `mqty`), all qty argument forms,
and explicit breaks within automatic delimiter arguments.

`physics-regression.tex` checks execution once, per-row labels, nested argument
breaks, matrix isolation, local palettes, local niji disabling and both loading
orders. `physics-weighting.tex` compares explicit/qty/braced delimiters using the
same lllhlll contents. `audit-physics.py` checks actual PDF positions and colours,
not just compilation, and produces `build/physics-compatibility.pdf`.

## Scope

The scanner parses the known physics argument grammars without expanding user
contents. It scans automatic delimiter bodies and preserves matrix bodies.
Starred delimiter arguments remain opaque, as do fractions, scripts and unknown
macros. Internal breaks inside these opaque arguments are not supported.
Measurement looks through a single unscripted ordinary wrapper around the entire
argument; it does not flatten arbitrary mathematical structures.

## Reproduce

Run from the project root with Python containing pdfplumber and pypdf:

```powershell
$env:TEXMFVAR=Join-Path $PWD 'build/texmf-var'
$env:TEXMFCACHE=$env:TEXMFVAR
python experimental/probe-physics.py
lualatex -interaction=batchmode -halt-on-error -output-directory=build experimental/physics-compat.tex
lualatex -interaction=batchmode -halt-on-error -output-directory=build -jobname=physics-after '\def\PhysicsAfter{1}\input{experimental/physics-compat.tex}'
lualatex -interaction=batchmode -halt-on-error -output-directory=build experimental/physics-weighting.tex
lualatex -interaction=batchmode -halt-on-error -output-directory=build physics-regression.tex
lualatex -interaction=batchmode -halt-on-error -output-directory=build -jobname=physics-regression-after '\def\PhysicsAfter{1}\input{physics-regression.tex}'
python experimental/test-physics-order.py
python experimental/audit-physics.py
```

Individual probe sources, logs and PDFs are retained in `build/physics-probes`.
