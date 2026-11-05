# Changelog

Copyright (C) 2026 Yu Zhai. LPPL 1.3c or later.

## Unreleased

- Preserve native streaming `displaymath` after adapting bracket displays;
  verify the complete official physics manual, including verbatim display
  examples, in traditional-font and Unicode continuous-outline builds.

- Integrate physics automatically in either loading order: runtime niji for
  macro-generated fences, safe function-argument closing, automatic delimiter
  argument breaks, and protected matrix arguments. Measure through single
  unscripted ordinary grouping wrappers without changing actual content boxes.

- Include every `\middle` position in distance-weighted delimiter sizing;
  support multiple middles, nested groups, niji and physical row splitting.
- Preserve native middle spacing and glyph construction. Extend the endpoint
  envelope to rows carrying middle delimiters.
- Restore xcolor state and nesting depth across primitive middle boundaries.
- Add native/weighted comparison PDFs, exact native-limit box checks in two
  font setups, and independent profile integration tests.

- Rewrite the English user manual around delimiter sizing, niji and direct
  equation breaks, with Wikipedia-sourced Stirling and normal-distribution
  examples and an explanation of the typographic purpose of distance weighting.

- Enable weighted delimiter sizing on package load, with public `lambda=20pt`,
  `q=8`, `p=3`, `spanning=endpoints/full` and `sizing=weighted/native` options.
- Add `\FinalDelimSetup`, direct breaks in equation/equation-star/bracket displays,
  and default native align/alignat integration; retain outer equation tags.
- Apply niji/rainbow to explicit inline delimiter pairs without changing script
  attachment or spacing. Add native-interface and PDF geometry regressions.
- Rewrite the English manual for a LaTeX-only user interface.

- Add a LuaTeX backend that typesets native mathematics once and physically
  partitions its cells, preserving native spacing and attached-script shifts.
- Feed those cells into native amsmath alignments, including multiple alignat
  pairs, per-row numbering, tags, labels, jot, row spacing and page breaks.
- Preserve rainbow colors across cell boundaries with balanced color scopes.
- Add debug=boxes/alignment/all/none, using lua-visual-debug and its lvdset
  configuration. Add a complete LuaLaTeX example and new regression fixtures.
- Add backend=auto/flat/legacy. Auto retains the legacy path for other engines
  and warns when active tagging requires it; explicit flat rejects tagging.

- Preserve native left/right spacing for pairs contained in one alignment
  cell, including after operators such as lim and Tr.

- Keep rainbow color resets inside top-level delimiter atoms so following
  superscripts, subscripts and primes retain their attachment.

- Color explicit left/middle/right pairs inside braced groups in rainbow
  mode, preserving native math styles and script attachment. Ordinary
  delimiters remain unchanged.

- Add matchedalignat and matchedalignat*, with native column counts, spacing,
  numbering, local color options and independent overridealignat support.

- Add matchedaligned with explicit block position and separate local color options.

- Apply amsmath tag placement to matchedsplit as well as overridden split.
- Clarify that delimiter layout carries no guarantee of semantic correctness.

- Exclude delimiter measurement and invisible sizing aids from math tagging.
- Preserve native align environment names for tagged equation numbers.
- Add LuaLaTeX MathML and PDF structure comparisons against native amsmath.

## 0.8.1 -- 2026-10-29

- Replace NewEnvironmentCopy with separate NewCommandCopy calls.
- Require LaTeX 2020-10-01 or newer, with an explicit error on older kernels.
- Add clean-archive verification and minimum-kernel rollback tests.
- Document the difference between kernel rollback and historical distributions.

## 0.8.0 -- 2026-10-29

- Add rainbow coloring at package and environment scope.
- Add local enable/disable and custom cyclic color palettes.
- Preserve math dimensions and surrounding text/formula color.

## 0.7.1 -- 2026-10-29

- Fix measurement across intertext and parsing of align inside gather.
- Validate braced metadata arguments and row-spacing brackets.
- Consolidate the public package as finaldelim.sty.
- Add the English user manual and distribution metadata.

## 0.7 -- 2026-10-29

- Add matchedalign, matchedalign* and the overridealign option.
- Retain native amsmath numbering, tags and reference handling.

## 0.6 -- 2026-10-29

- Add the overridesplit option and tag-position handling.

## 0.5 -- 2026-10-29

- Repair nested delimiter measurement and preservation of token groups.
- Add independent-pair measurements and explicit diagnostics.

- Fix the shared sizing policy to the maximum of position estimates. Replace
  the experimental `p` option with `scale` (default 1), applied once about the
  math axis after weighted or endpoint estimation; `scale=0.9` reduces the target.

- Set the default target-radius scale to 0.9; scale=1 remains available.

- Expose continuous outlines as `render=draw` / `render=native` at package,
  setup, and environment scope. Install the Lua renderer beside the core files;
  remove the experimental loading entry points and matchedxxx environment aliases.

- Provide fdequation, fdalign, fdalignat (including starred forms), fdsplit
  and fdaligned as explicit APIs; override=false retains native display
  interfaces. Standard equation/align/alignat replacement remains the default.

- Rewrite the user manual around formula-writing problems, add a shared-source
  lllhlll sizing comparison, and consolidate explicit environments and options.

- Add rendered spanning-policy and debug comparisons and reproducible raster
  close-ups of delimiter joins; remove the redundant line-breaking subsection.
- Initialize inherited box directions on diagnostic copies before invoking
  lua-visual-debug, preventing a crash for script attachment boxes.

- Add opt-in spanning=folded: compress intermediate rows to 0.01em-wide height/depth
  envelopes for weighted sizing, preserving delimiter-bearing rows and an
  endpoint lower bound. Use render=draw throughout the manual except native
  comparisons, and show all three spanning policies side by side.

- Make spanning=folded the default, with a 0.01em representative width.
  Keep endpoints and full as explicit alternative policies.

- Expose fold-width as a positive TeX length (default 0.01em), with package,
  setup, and local display scope; move continuation operators to row starts
  in the spanning-policy comparison.
