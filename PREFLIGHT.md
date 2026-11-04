# CTAN preflight: matchedsplit 0.8.1

Date: 2026-10-29. Author and maintainer: Yu Zhai.
Copyright (C) 2026 Yu Zhai. LPPL 1.3c or later.

## Name checks

The CTAN package page and JSON package record for matchedsplit returned
HTTP 404. Catalogue search with the PKG filter found no entry; a control
search for amsmath returned known catalogue entries.

The compressed CTAN FILES.byname index contained no matchedsplit entry.
A positive control found two amsmath.dtx source entries in the same index.
The installed TeX file lookup found only the working-copy finaldelim.sty.

Sources checked:

- https://ctan.org/pkg/matchedsplit
- https://ctan.org/json/2.0/pkg/matchedsplit
- https://ctan.org/search?phrase=matchedsplit&PKG=on&FILES=on
- https://mirrors.ctan.org/FILES.byname.gz

These observations show no detected collision on the check date. They do
not reserve a name or predict pending submissions; CTAN makes the final
registration decision. File-search web results were not used alone as
proof: known source-file queries also returned no results, so the complete
archive filename index was used instead.

## Kernel requirement

The implementation now requires LaTeX 2020-10-01. Separate NewCommandCopy
calls save the native environment's start and end commands, replacing the
newer NewEnvironmentCopy wrapper. The kernel hook and command-copy APIs
are available from 2020-10-01, as documented by release guards in the
LaTeX project's ltdefns.dtx, ltclass.dtx and hook sources.

The declared date and explicit package error agree. A format older than
the requirement is rejected before the package defines its environments.
Rollback testing targets the dated kernel on the installed TeX Live 2026
system; it does not establish compatibility with all package versions in
a complete historical TeX Live release.

## Archive verification procedure

verify-release.ps1 creates an independent temporary extraction of the ZIP,
checks its eight-file manifest, and runs the test suite with the package
loaded from that extraction. User TEXMF configuration and writable caches
are isolated; the installed TeX Live system remains the dependency source.
The manual and shipped example are rebuilt twice with each of the three
engines. Additional tests use kernel rollback, and an older-format probe
must report the expected error. Recorder output checks package provenance.
An archive checksum detects any ZIP change during the run.

No CTAN upload is performed by the script or by these checks.

## Verification result

All checks passed for the final 0.8.1 archive on 2026-10-29:

- 45 positive engine/test combinations and 12 expected-error cases.
- Manual and shipped example compiled twice with pdfLaTeX, XeLaTeX and LuaLaTeX.
- Four selected cases passed with the 2020-10-01 kernel on each engine.
- Each engine rejected the 2020-02-02 format with the intended package error.
- Archive contents, package provenance and stable archive checksum passed.

Archive SHA256:
`B1DF52D11ACE16DCE471FC20D95D602F1321C75ECA513345DC8145017CB233AE`
