# Physics compatibility audit

Tested 2026-11-04 with TeX Live 2026, LuaHBTeX 1.24.0, physics 1.3,
Latin Modern Math, and finaldelim's continuous-outline renderer.
This records observed incompatibilities, not a declaration of full support.

## Results

90 unique compilation probes cover 24 expressions, inline and equation contexts,
and niji off/on (line-break probes use equation only). Four combinations fail:

- Inline `\dv{x}(...)` and `\sin(...)` with niji: extra grouping error.
  Physics uses `\argopen` / `\argclose`; the latter uses `\aftergroup\egroup`.
  Finaldelim's colour wrapper adds groups and changes which group closes first.
- `\mqty(a&b\\c&d)` in equation, with or without niji: the display parser
  mistakes the macro's internal alignment tokens for outer break/alignment
  markers. Sizing then reports `Endpoint prototype requires horizontal cuts`.

Successful compilation does not imply full feature support:

- In equation, macro-generated fences (`\qty`, `\bqty`, `\norm`, bra-ket, etc.)
  receive weighted sizing and drawn outlines, but no niji colour. The display
  token pass sees explicit fences, while these fences appear during expansion.
  Direct `\left...\right` remains coloured in the same test.
- `\qty(a+\\b)` actually breaks into two rows; `\bqty{a+\\b}` compiles but
  leaves a and b on one baseline. The braced macro argument hides the break.
- Physics `\braces` places its content in an extra math group. In the lllhlll
  probe, explicit brackets and `\qty[...]` produce sizing targets
  11.337 pt / 6.337 pt, while `\bqty`, `\pqty`, `\abs`, and `\norm` produce
  15.151 pt / 10.151 pt. The distance model sees the grouped content as one box.

Ordinary unbroken examples of qty, abs, norm, commutator, bra, ket, braket,
matrixel, expval, simple derivatives, differentials, and inline matrices compile.
Inline niji works for the tested ordinary delimiter macros and nested groups.
The explicit fixed-size and starred samples compile as well.
Both macro-package loading orders give identical sample glyph geometry and colours.

Verified workarounds for particular cases (not a general compatibility layer):

- Inline: `\dv{x}\qty(...)` and `\sin\qty(...)` avoid the argclose conflict.
- Equation matrix: `\pmqty{a&b\\c&d}` compiles.
- For coloured multiline formulae, use explicit `\left...\right` around physics
  commands and put the intended outer `&` and `\\` outside macro arguments.

## Reproduce

Run from the project root with a writable TeX font cache:

```powershell
$env:TEXMFVAR=Join-Path $PWD 'build/texmf-var'
$env:TEXMFCACHE=$env:TEXMFVAR
python experimental/probe-physics.py
lualatex -interaction=batchmode -halt-on-error -output-directory=build experimental/physics-compat.tex
lualatex -interaction=batchmode -halt-on-error -output-directory=build -jobname=physics-after '\def\PhysicsAfter{1}\input{experimental/physics-compat.tex}'
lualatex -interaction=batchmode -halt-on-error -output-directory=build experimental/physics-weighting.tex
python experimental/test-physics-order.py
python experimental/audit-physics.py
```

`audit-physics.py` verifies the currently known failures and silent limitations;
update those expectations when compatibility is repaired. Individual probe
sources/logs/PDFs are in `build/physics-probes`. The combined five-page sample is
`build/physics-compatibility.pdf`. No package implementation was changed in this audit.
