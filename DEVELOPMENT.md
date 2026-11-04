# Developer notes

Copyright (C) 2026 Yu Zhai. LPPL 1.3c or later.

## Structure

`finaldelim.sty` contains shared interfaces and the legacy implementation;
`finaldelim-luatex.sty` adapts physical cells to native amsmath, and
`finaldelim.lua` implements partitioning and cell ownership. Public interfaces are
specified in finaldelim.pdf; names beginning with `__ms` and the
msnativealign environments are internal and are not stable APIs.
`regression.tex` retains the extended user examples.

## LuaTeX processing (unreleased)

The adapter removes literal outer alignment cuts and defers row metadata to
the native alignment. It evaluates the remaining formula once in display
style, retaining native math spacing, delimiter construction and scripts.
Only horizontal ancestors of explicit cuts are opened; other boxes remain
opaque with their original shift. Each partition is repacked without changing
its contents. Rejoining is checked against the original glyph/rule coordinates
on every invocation before any debug decoration is applied.

Color stacks are balanced independently at cell boundaries: active pushes
are reopened in the next cell and closed in the preceding cell. This allows
native amsmath cell scopes, measurement passes, numbering and page breaks to
coexist with spanning rainbow pairs. Formula source is not rerun for amsmath
measurement: temporary cell copies are used instead. Source-owned cells are
freed after the native alignment finishes; only the final output copies ship.

Native aligned/align/alignat implement placement, struts, jot, tags, labels,
row spacing and page-break policy. There is no custom fixed row-gap formula.
Debug boxes use lua-visual-debug's implementation and standard lvdset settings;
alignment guides are zero-size PDF literals. Loading the standard package
separately avoids duplicate local outlines.

Active tagging explicitly selects legacy in auto mode (with a warning), and
is rejected in explicitly requested flat mode. No silent untagged output is
advertised as tagged. The Lua backend currently targets LTR display math and
the ordinary PDF color stack; arbitrary PDF literals or custom color stacks
inside a formula are outside the interface.

The new fixtures compare unequal-row amsmath dimensions at two jot values,
color/debug invariance, three column pairs, source evaluation counts, row
metadata and trailing breaks, in both Computer Modern and XITS Math. Existing
legacy measurement-internal assertions explicitly select backend=legacy.

Validation on 2026-11-04: the three-engine suite passed 67 positive
engine/fixture combinations and 13 expected-error cases. Two additional
public-backend PDF fixtures verify rainbow/debug geometry and 25 numbered
rows over two pages, including absence of duplicate glyphs and color leaks.
The current user demo matches native row spacing and relative glyph positions
within 0.001 pt in the PDF. Debug literals can change PDF text-run rounding;
the independent PDF checks allow 0.012 pt while TeX dimensions are compared
exactly. All 41 existing tagging fixtures pass through the explicit auto-mode
legacy compatibility path; explicitly requested flat tagging is rejected.
The new Lua tests also pass a kernel rollback to 2020-10-01 with current
dependencies and a separately loaded lua-visual-debug package.

Commands: `./test.ps1`, `python test-luatex-pdf.py`, and
`python test-tagging.py`. Python checks require pdfplumber/pypdf as applicable.
The manual is built with LuaLaTeX twice and inspected as rendered pages.

## Legacy processing

The environment collects its body with `+b`. The parser preserves braced
groups, tracks nested environment depth, and identifies top-level
delimiters, row controls and supported metadata. Open delimiter pairs
are stored on a stack. Each ordinary mathematical token is appended to
all active pairs. Closing a pair measures its contents in display style
with invisible boundaries and records the dimensions in a local box.

The rendered stream contains complete local delimiter constructions with
phantoms. matchedsplit passes that stream to aligned; matchedalign passes
it to a saved native align environment for numbering and layout.

Pairs are marked when an alignment tab or row break occurs while they are
open. A pair contained in one cell renders with native left/middle/right,
preserving its Inner math class, spacing and script attachment. Rainbow
uses the native-pair color renderer for these pairs. Spanning pairs retain
the matched-size open/relation/close atoms. This decision is per pair, so
a local pair nested inside a spanning pair can still use native layout.
Native-spacing tests compare operator-adjacent pairs, neighboring pairs,
middle delimiters and scripts against aligned, with and without rainbow.
The Unicode variant uses XITS Math to cover the user's demo configuration.

The current three-formula demo is checked in place: rainbow and plain
matchedsplit are compared with its native split example after removing
whole-formula translation. LuaLaTeX coordinates differ by at most 0.001 pt;
XeLaTeX coordinates differ by at most 0.010 pt. Native-spacing box dimensions
are also checked exactly under XITS Math. The spacing change passed all
62 other positive engine/fixture combinations, 13 expected-error cases,
41 tagging fixtures and the three-engine kernel rollback checks. The user
demo was compiled separately with LuaLaTeX and XeLaTeX. Logs are in
build/spacing-regression.txt and build/spacing-tagging.txt.

## Invariants

- Property keys must contain expanded numeric IDs.
- Preserve group braces, including a final single group: the scanner uses
  a sentinel to avoid TeX stripping that group's braces during argument scanning.
- Row markers, supported labels/tags and intertext must not execute during
  delimiter measurement.
- Parsing inside an alignment requires alignment-safe protection, not merely
  an ordinary TeX group.
- Do not expand arbitrary user macros while scanning.
- Box assignments and parser state are local; box registers are allocated
  lazily by pair ID and reused in later environments.

Token-list copying and appending to every active pair can be costly.
The implementation is not claimed to be linear in input size or nesting depth.

## amsmath integration

The split replacement also changes insplit@ because amsmath locally
rebinds split inside align/gather. Native align* and other alignment
environments share endalign. The native ending is restored locally when
those implementations are invoked, avoiding interference from the new
body-collecting align wrapper. Retest after upgrading amsmath.

## Tests and documentation

Run `./test.ps1` in PowerShell with all three engines on PATH. It places
outputs and Lua font caches under build/, restores the cache environment
variables afterwards, and gives each compiler process a 30-second timeout.
The timeout may need adjustment on a machine building fonts for the first time.

Numbering cases run twice and assert aux label values. Dimension tests
compare with native TeX boxes. Negative cases require a nonzero exit code
and a matchedsplit error; a timeout is a failure, not an expected rejection.
Inspect rendered PDFs for changes to delimiter sizes or layout.

Build the manual by running `pdflatex finaldelim.tex` twice from this
directory. The upload archive includes only the files in MANIFEST.md.
See AUDIT.md for the audit scope and remaining limitations.

## Rainbow implementation (0.8.0)

Package options establish defaults; each environment copies those defaults
into local settings before applying its optional keys. Palette indices are
stored by pair ID when a left delimiter opens, using the current stack
depth modulo the palette length. Siblings therefore reuse colors.
The rendering commands set color inside the existing math atom group;
measurement stays uncolored, and subsequent formula material is unaffected.

rainbow_assertions.tex checks palette cycling, sibling mapping, setting
reset, and equal width/height/depth with coloring enabled and disabled.
rainbow_test.tex and rainbow_local_test.tex exercise package/local options,
custom palettes, replacements, middle delimiters and ambient text color.

With rainbow enabled, a separate recursive pass colors explicit delimiter
pairs inside groups. It preserves group braces and spaces, does not expand
user macros, and skips native inner environments. Measurement retains the
original group tokens. Grouped pairs use native left/middle/right sizing
in the current math style and inherit the surrounding palette depth.
The renderer completes color resets inside an inner atom before returning
to the surrounding formula. This prevents color stack nodes from separating
a right delimiter from its scripts, leaving native script/prime handling intact.
rainbow_groups_test.tex compares colored/uncolored dimensions for exponents,
fractions, nested groups, middle delimiters, primes and scripts on pairs.
It also asserts inherited depth and local rainbow=false behavior. The
unicode fixture runs the same checks with unicode-math under XeLaTeX and LuaLaTeX.
Tagging tests compare grouped delimiters and script attachment with native
MathML and PDF structure.

Validation on 2026-11-04: 65 positive engine/fixture combinations and 13
expected-error cases passed, along with all 37 tagging fixtures. The four
new grouped-color fixtures passed veraPDF 1.30.3 PDF/UA-2 machine checks
after adding document-level metadata. Kernel rollback to 2020-10-01 passed
the grouped-color fixture with all three engines and installed dependencies.
The initial projected-partition comparison used the previous rainbow-enabled
implementation and therefore missed its existing top-level script-attachment
bug. Top-level delimiter renderers now also finish color resets inside their
math atoms. The full user demo with physics and XITS Math is compared against
rainbow=false, not against the old colored output. Tests include powers on
absolute-value delimiters and scripts/primes on top-level and cross-row pairs.
Logs for the initial grouped-color checks are retained in
build/rainbow-groups-regression.txt, build/rainbow-groups-tagging.txt and
build/accessibility/groups-validation.txt.

Follow-up top-level script validation: the current XITS Math/physics demo
matches rainbow=false in every extracted glyph position and size with
LuaLaTeX and XeLaTeX. The remaining 62 positive engine/fixture combinations
and 13 expected-error cases passed; the edited Unicode-only demo was checked
separately rather than passed to pdfLaTeX. All 39 tagging fixtures passed,
including rainbow/plain top-level right-delimiter script comparisons. The
two new fixtures passed veraPDF PDF/UA-2 machine checks. Logs are in
build/right-scripts-regression.txt, build/right-scripts-tagging.txt and
build/accessibility/right-scripts-validation.txt.

## Release verification

Run `./verify-release.ps1` after rebuilding dist/finaldelim.zip. The script
extracts the archive into a newly created system temporary directory and
uses the archived implementation and documentation. Test fixtures and the
test runner are supplied separately from the checkout as a harness; no
package implementation is copied from the checkout.

It clears custom TEXINPUTS, supplies an empty TEXMFHOME, isolates writable
font caches, and checks kpsewhich plus recorder provenance. It runs the
complete suite, rebuilds the archived manual and example with three engines,
checks selected cases under the 2020-10-01 kernel rollback, and checks that
2020-02-02 is rejected. The initial and final archive hashes must agree.
The temporary directory and compiler logs are retained for inspection.
This isolates files and configuration, not the operating system or the
installed TeX distribution. Kernel rollback retains installed package versions.

The native align copies use separate NewCommandCopy calls for start and
end commands. This preserves command-copy semantics without requiring the
NewEnvironmentCopy interface introduced in 2023. Both NewCommandCopy and
the kernel hooks used here are available from LaTeX 2020-10-01.

## Tagged mathematics regression (issue #1)

Run `python test-tagging.py` with Python 3, pypdf and LuaLaTeX available.
This is a separate optional suite: the normal three-engine tests do not
require a tagging-capable format or Python. The tagging suite uses the
installed TeX Live 2026 tooling with lua-unicode-math and mathml-SE.
Generated fixtures, PDFs, MathML and logs are retained in build/tagging.

The implementation marks delimiter measurement with amsmath's scoped
measuring state. Its tagging integration suppresses structure creation
and LuaMML conversion in the discarded measurement. Delimiter sizing uses
only the saved height and depth, rather than copying the measured node
list. When LuaMML is available, its annotation interface excludes this
zero-width sizing aid from the mathematical structure. The saved native
align implementations run under their native environment names, which
LuaMML uses to recognize equation-number structures. Restorations are local.

The new tests compare native and matched versions of numbered and starred
alignments, override options, rainbow coloring, nested/middle delimiters,
inner aligned displays, explicit tags, suppressed numbering and intertext.
They require clean final logs and compare normalized MathML rows, cells,
identifiers, operators, fractions and equation numbers. Spacing and mrow /
mstyle wrappers are intentionally excluded from the comparison: matched
and native delimiters need not have identical sizing or grouping markup.
PDF structure checks additionally verify parent links, unique structure
references, a single Formula, absence of sizing phantoms and corresponding
math element counts. This is regression coverage, not PDF/UA certification
or a screen-reader interoperability test.

The original 0.8.1 implementation fails the new suite on the reported
warnings. During development, nested_test, numbered_override_test and
rainbow_test were compiled with both implementations and rendered at
120 dpi: all four resulting pages were pixel-identical. The unchanged
three-engine suite and the 2020-10-01 kernel rollback remain required checks.
Kernel rollback retains the installed dependency versions.


## Embedded aligned blocks (unreleased)

matchedaligned accepts [position][local color options], with position c by
 default. It reuses the scanner and aligned renderer without consulting the
amsmath tag-position policy. Native aligned is not overridden. The
matchedaligned_test fixture checks dimensions against native aligned for
all three positions, including multiple column groups, under tbtags/leqno;
it also checks outer numbering and examples with nested colored delimiters.
The tagging suite compares the new environment against native aligned for
default and explicit positions, including local coloring. Invalid position
values have a dedicated negative test. The package handles delimiter layout
and does not guarantee the semantic correctness of formulas or of the
generated mathematical structure in tagged PDFs.

## Explicit column pairs (unreleased)

matchedalignat and matchedalignat* pass the mandatory pair count to the
saved native alignat implementation. Rendering uses the native environment
name for LuaMML and locally restores endalign, including when overridealign
and overridealignat are both enabled. overridealignat is independent.

The alignat_test, alignat_override_test and alignat_left_test fixtures check
native layout dimensions, multiple pairs with explicit spacing, nested
delimiters, local colors, row spacing, labels, tags, intertext and suppressed
numbers. The latter fixture combines fleqn and leqno. The tagging suite
adds ten fixtures covering numbered/starred forms, combined overrides,
multiple pairs and custom tags, compared with native MathML and PDF trees.

Validation on 2026-11-02: all 60 positive engine/fixture combinations and
13 expected-error cases passed; all 33 tagging fixtures passed. Independent
overridealignat and kernel rollback to 2020-10-01 also compiled with all
three engines. Rollback retains the installed dependency versions.
The ten new alignat tagging fixtures, rebuilt with PDF/UA-2 metadata,
document title and DisplayDocTitle, passed veraPDF 1.30.3's PDF/UA-2 machine
checks (zero failed rules/checks). Reports are in build/accessibility/ua2
and build/accessibility/alignat-ua2-summary.json. This does not establish
screen-reader usability; desktop interaction testing remains paused.
