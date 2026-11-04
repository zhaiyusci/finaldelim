# Code audit

Date: 2026-10-29. Reviewed version: 0.7. Fixed version: 0.7.1.
Copyright (C) 2026 Yu Zhai. LPPL 1.3c or later.

## Scope

This was a functional correctness and compatibility review, not an
independent security certification. It examined token scanning, grouping,
pair storage, measurement scope, metadata execution and amsmath replacement.
Methods included source inspection, minimal reproducers, dimension and
label assertions, compilation and visual inspection. User changes in
regression.tex were preserved.

## Findings

### A1 -- intertext executed during measurement (P2, fixed)

An intertext between a left delimiter and a later right delimiter was
executed in a math box, producing amsmath's Invalid use of intertext error.
The scanner now retains intertext and displaybreak for output only.
The audit_features case checks a pair spanning prose, with labels 1 and 3.
Multipage break decisions have not been tested comprehensively.

### A2 -- align inside gather exposed alignment tokens (P2, fixed)

The outer alignment interpreted ampersands while the inner replacement
align body was being scanned. A minimal reproducer failed with an extra
closing-brace error. Alignment-safe protection now surrounds preprocessing.
The nested gather/align case renders two rows with numbers 4 and 5.

### A3 -- missing metadata argument validation (P2, fixed)

Source inspection found that a missing label/tag argument could consume
an internal sentinel. No quantitative hang test was performed on the old
path. The reader now requires braced arguments and stops parsing with an
explicit package error if they are absent. Four negative cases cover
label, tag, starred tag and intertext with missing arguments.
Unbraced single-token metadata arguments are not supported in 0.7.1.

### A4 -- missing row-spacing bracket diagnostic (P3, fixed)

The row-spacing reader previously relied directly on TeX's delimited
argument scan. It now checks for a closing bracket before invoking the
reader and reports a package error if absent. TeX still validates the
actual dimension. The row-spacing negative case passes.

## Verification

On Windows with TeX Live 2026:

- 12 positive test files across three engines: 36 combinations passed.
- Three numbering cases run twice per engine: 45 positive compiler runs.
- Nine negative cases passed under pdfLaTeX.
- Dimension assertions cover independent pairs, nested contents and final
  grouped subscripts; aux assertions check automatic and custom labels.
- The audit PDF was inspected for delimiter sizing, intertext, numbering,
  nested matrices and clipping.

Reproduce using test.ps1; logs are stored in build/. These figures describe
the current 0.7.1 suite. Renaming the package to matchedsplit was followed
by another complete passing run.

## Remaining limits

The split replacement does not reproduce every native split width rule.
Groups and nested environments are opaque to the outer parser; cross-boundary
pairing and side-effectful macros are unsupported. The implementation
uses amsmath internals and must be retested against future releases.
Historical TeX formats, publisher classes, third-party package combinations,
multipage pagination and very large inputs have not been comprehensively
validated. Negative cases are not exhaustive fuzz testing.

The documented findings are resolved within the tested scope. This is not
a claim that every valid or invalid TeX input is handled correctly.

## Rainbow feature review (0.8.0)

The new color operation is scoped inside each rendered delimiter atom.
Depth indices are recorded independently from pair IDs; this preserves the
same color at both ends, and reuses colors for sibling pairs. Measurement
is unchanged. Environment options are local and reset from package defaults.

All 45 positive engine/case combinations passed (54 positive compiler runs,
including second passes for reference cases). Nine earlier negative cases
and three option-validation cases passed under pdfLaTeX. New assertions
cover color-independent box dimensions, palette cycling and local settings.
Rendered global/local palette examples were checked visually, including
middle delimiters, disabled coloring and preservation of ambient purple
formula text. Coloring inside opaque groups/environments remains unsupported.
