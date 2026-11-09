# finaldelim

A LuaLaTeX-based project for matched delimiters, explicit line splitting,
rainbow coloring and adjustable delimiter sizing.

Derived from the matchedsplit development snapshot based on commit
8521f766b26a9bd0a6c04ef2b377da4ec64743fa. The original matchedsplit repository
is maintained separately with its measurement-based method.

Load `\usepackage{finaldelim}`. Implementation files are `finaldelim.sty`,
`finaldelim-luatex.sty`, and `finaldelim.lua`. Existing environment names
(`matchedsplit`, `matchedaligned`, `matchedalign`, `matchedalignat`) are retained.

The new physical-partition algorithm targets LuaLaTeX. Inherited legacy
helper definitions remain scaffolding, not a claim of cross-engine support.
Start with `experimental/weighted-size-demo.tex` and
`experimental/delimiter-sizing-README.md`. Sizing defaults are lambda=20pt,
q=3, maximum over positions, scale=1; spanning_scope=endpoints, with full optional.

This repository has no remote and no commits yet.
