"""Run from any directory; regenerate the actual 96 dpi joint comparison."""
from pathlib import Path
import os
import subprocess
from PIL import Image, ImageOps
root = Path(__file__).resolve().parent.parent
build = root / "build"
build.mkdir(exist_ok=True)
env = dict(os.environ, TEXMFVAR=str(build / "texmf-var"), TEXMFCACHE=str(build / "texmf-var"))
subprocess.run(["lualatex", "-interaction=batchmode", "-halt-on-error", "-output-directory=build", "manual-assets/joints.tex"], cwd=root, env=env, check=True)
subprocess.run(["pdftoppm", "-r", "96", "-png", "build/joints.pdf", "build/joints"], cwd=root, check=True)
images = [Image.open(build / f"joints-{i}.png").convert("RGB") for i in (1, 2)]
bounds = [ImageOps.invert(image).getbbox() for image in images]
crop = (min(b[0] for b in bounds)-4, min(b[1] for b in bounds)-4,
        max(b[2] for b in bounds)+4, max(b[3] for b in bounds)+4)
size = ((crop[2]-crop[0])*8, (crop[3]-crop[1])*8)
for name, image in zip(("native", "draw"), images):
    image.crop(crop).resize(size, Image.Resampling.NEAREST).save(root / "manual-assets" / f"joints-{name}.png")
