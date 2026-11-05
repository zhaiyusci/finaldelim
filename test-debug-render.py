"""Check diagnostic overlays against unchanged native glyph geometry."""
import pdfplumber
from pypdf import PdfReader
with pdfplumber.open("build/debug-render-test.pdf") as pdf:
    assert len(pdf.pages) == 5
    baseline = [(c["text"], c["x0"], c["top"], c["x1"], c["bottom"]) for c in pdf.pages[0].chars]
    for page in pdf.pages[1:]:
        actual = [(c["text"], c["x0"], c["top"], c["x1"], c["bottom"]) for c in page.chars]
        assert len(actual) == len(baseline)
        # PDF text runs split at diagnostic literals; allow 0.01bp serialization rounding.
        # The backend also asserts exact node glyph/rule geometry before/after overlays.
        for a,b in zip(actual,baseline):
            assert a[0] == b[0]
            assert max(abs(x-y) for x,y in zip(a[1:],b[1:])) < 0.01
    assert len(pdf.pages[1].edges) > len(pdf.pages[0].edges)
    assert len(pdf.pages[2].edges) > len(pdf.pages[0].edges)
    assert len(pdf.pages[3].edges) > len(pdf.pages[0].edges)
    stream = PdfReader("build/debug-render-test.pdf").pages[4].get_contents().get_data()
    assert b"0 0 1 RG 0.7 w" in stream
print("PASS: all debug modes preserve glyph geometry; overlays present; lvdset color and width honored.")
