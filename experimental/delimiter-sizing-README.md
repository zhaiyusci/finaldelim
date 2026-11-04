> Historical parameter experiments: the cubic-mean results below are retained
> for comparison. The production package now uses a fixed maximum over delimiter
> positions, with lambda=20pt, q=8, and scale=0.9 (optional scale=1).

# Experimental delimiter sizing

## Selected defaults

The selected defaults are **lambda = 20 pt, q = 8, p = 3**.
They are defined in `delimiter-config.lua` and used by `font-size.lua`.
The decay length is a physical TeX length, independent of both font size and
formula width. Do not convert it to em or a fraction of formula width.
These are defaults for this experimental sizing implementation, not a change
to the released package's delimiter behavior.

Change the configuration file, or configure the loaded experiment before rendering:

```latex
\directlua{grid.configure{lambda_pt=20, q=8, p=3}}
```

`grid.cell()` uses the configuration; `grid.cell(lambda_pt, q, p)` can override
parameters for a comparison. All parameters are numeric. The configuration
requires positive finite lambda_pt and p, and nonnegative finite q; q=0 is the
experiment's sentinel for the infinity limit. Use `configure` for validated changes.
The PDF caption and recorded TSV values follow the active configuration.

## Model

For each marked term, retain its natural horizontal interval and radius
`r_i = max(h_i - a, d_i + a)` about the mathematical axis. Its interior remains
opaque. Set the radius of gaps and separators to `L = min(r_i)`.
Thus r(x) is a piecewise constant profile; overlapping parent and child boxes
are not counted twice. Splitting a constant-height interval does not change
its contribution.

For s = left or right, use d_left(x)=x and d_right(x)=W-x:

    R_s = [ integral r(x)^q exp(-d_s(x)/lambda) dx
            / integral exp(-d_s(x)/lambda) dx ]^(1/q)
    R   = [(R_left^p + R_right^p)/2]^(1/p)

Integrals cover [0,W] and are evaluated analytically per interval. The q=infinity
limit is the global maximum radius on positive-width intervals. Both sides
then agree, independently of the decay length.

The resulting R is a sizing input, not a measured delimiter glyph radius.
Native TeX delimiter selection still applies, including delimiterfactor,
delimitershortfall, font variants and extensible assembly. A single uniform
box returns its own radius for every q. Font size can nevertheless change the
available delimiter variants even for a fixed physical box.

## Experiments and observations

- `parameter-grid.tex`: 15 cases, q=1,2,4,8,16,infinity and lambda/W=1/8,1/4,1/2,1.
- `absolute-decay.tex`: the same cases with lambda=10,20,40,80 pt.
- `font-size.tex`: selected configurable defaults at 8,10,12,16,20 pt.
  Every formula is evaluated once per size and copied for native/model comparison.
  The mathematical axis is captured inside initialized math mode for each size.
  The single-square control remains physically 20 pt wide and tall at every size.

The first two are historical parameter sweeps and intentionally keep their
explicit grid values; they do not inherit the selected default configuration.

At q=8 and lambda=20 pt, extending the low parts of hllh barely changes the
result (29.17 to 29.15 pt in the 10 pt fixture). In lhl, the same extension moves
the high term far from both ends and reduces the radius (23.85 to 8.68 pt).
With fixed physical decay, enlarging a formula increases its distances relative
to lambda. Long lhl therefore need not acquire proportionally larger delimiters.
These are observed model behaviors, not an established universal aesthetic ranking.

## Reproduction

From the repository root, with LuaLaTeX and Python/pdfplumber available:

```powershell
$env:TEXMFVAR = Join-Path $PWD 'build/texmf-var'
$env:TEXMFCACHE = $env:TEXMFVAR
lualatex -interaction=nonstopmode -halt-on-error -output-directory=build experimental/font-size.tex
python experimental/test-font-size.py
```

Outputs are `build/font-size.pdf`, `build/font-size.tsv` and
`build/font-size-geometry.tsv`. Tests independently integrate the recorded
geometry and check 75 samples, single-square invariance and PDF page bounds.
Compilation checks single source execution, subdivision and reflection invariance.


## Rainbow and physical line splitting

`weighted-size.lua` connects the sizing experiment to the existing LuaTeX
physical-partition backend. Load it after `matchedsplit`:

```latex
\directlua{
  weighted = dofile('experimental/weighted-size.lua')
  weighted.configure{lambda_pt=20, q=8, p=3, spanning_scope='endpoints'}
  weighted.enabled = true
}
\begin{matchedalign}[rainbow]
 F &= \left[a+b+\\
   & \frac{\sum_{k=1}^n x_k}{1+\frac pq}+\\
   & (c+d)^2\right]^{n+1}_j
\end{matchedalign}
```

The cross-row policy is adjustable:

- `spanning_scope='endpoints'` (default): use the maximum height and depth
  of the first and last rows within the pair. Intermediate rows do not affect
  delimiter size. This retains the earlier endpoint policy; it does not apply
  the weighted integral to those rows.
- `spanning_scope='full'`: apply the weighted integral to the whole continuous
  contents, including intermediate rows.

Pairs without row breaks always use the weighted integral. Parsed node copies
are measured without replaying source tokens; final continuous layout then uses
native delimiter boxes and is physically partitioned into real cells/rows.
Rainbow, per-row numbering, alignat alignment and debug boxes reuse the existing
backend. Scripts on spanning groups retain the endpoint attachment metrics.

Unlike the hand-marked parameter sweeps, this integration measures actual
horizontal nodes: uncut nested boxes remain opaque; wrappers containing cuts
are opened. That change in granularity can change numerical results.
Explicit-size and middle-delimiter groups stay on the native sizing path.
Vertical cuts, overlapping profile intervals and unusual math-style transitions
are not established supported cases. This callback is opt-in and experimental;
no tagged-PDF support or non-LuaTeX support is added.

Compile `experimental/weighted-size-demo.tex` and
`experimental/weighted-size-test.tex` with LuaLaTeX, then run
`python experimental/test-weighted-size.py`. The checks cover rainbow geometry,
color leakage, middle-row independence in endpoint mode, a distinct full mode,
single source evaluation and absence of PDF clipping.
