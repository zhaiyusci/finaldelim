# Prebuilt-only parenthesis fitting

Run `experimental/fit-prebuilt-delimiters.py` from the project root with the
same Python dependencies as `fit-delimiters.py`. It reads font MATH variant
lists directly; it does not consume the atlas samples and never reads the
GlyphAssembly recipes. At 10pt, this yields all 8 distinct Latin Modern Math
left-parenthesis variants and all 13 STIX Two Math variants, including base glyphs.

Outputs: `build/prebuilt-fit.pdf` (four pages), `build/prebuilt-fit.json`.
The first three pages show original contours, individual fits, and held-out
predictions. The fourth page shows width, central thickness and error trends.

The six-parameter outline model is unchanged from delimiter-fit-README.md.
This isolates the effect of excluding assemblies instead of changing both the
training data and the model at once. Each interior variant is removed in turn;
its parameters are linearly interpolated by ink height using its immediately
smaller and larger prebuilt neighbours. Neither endpoint is predicted, and
there is no extrapolation beyond the prebuilt range.

Results (horizontal boundary RMS, TeX pt, 10pt font):

| Font | Individual fit range | Held-out parameter prediction range | Worst raw-section prediction |
| --- | --- | --- | --- |
| Latin Modern Math | 0.0256–0.0477 | 0.0266–0.0437 | 0.0157 |
| STIX Two Math | 0.0344–0.0446 | 0.0347–0.0404 | 0.0065 |

The raw-section reference interpolates the original left/right boundaries at
matching normalized vertical positions, again excluding the target variant.
Its lower error suggests that interpolation of the font's own outlines may
preserve its design better than fitting this particular analytic family.
Both references exclude the outermost 0.5% at either tip and are not perceptual
quality scores. Curve tips, derivative continuity and right parentheses still
need validation before use in the package.

Within the measured prebuilt ranges, ink width and central horizontal stroke
thickness vary smoothly with height. The large error from interpolating across
the prebuilt/assembled transition is outside this experiment's scope. All
production package files are unchanged by this experiment.
