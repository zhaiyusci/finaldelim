# Distribution manifest

finaldelim development snapshot, 2026-11-04. No finaldelim release yet.
Copyright (C) 2026 Yu Zhai. LPPL 1.3c or later; maintained by Yu Zhai.

The inherited distribution manifest lists:

- `finaldelim.sty` -- directly maintained package source;
- `finaldelim-luatex.sty` -- LuaTeX alignment adapter;
- `finaldelim-interface.sty` -- native display and inline interfaces;
- `finaldelim-size.lua` -- delimiter sizing;
- `finaldelim.lua` -- LuaTeX physical partition backend;
- `finaldelim.tex` -- user manual source;
- `manual-examples/*.tex` -- live source-and-result examples used by the manual;
- `manual-examples/classic-split-highlight.txt` -- highlighted copy of the classic example for the manual;
- `finaldelim.pdf` -- compiled user manual;
- `experimental/finaldelim-draw.sty`, `experimental/finaldelim-draw.lua`, and
  `experimental/finaldelim-outline-fonts.lua` -- optional outline renderer, also
  required to compile the continuous-outline examples in the manual;
- `quickstart.tex` -- native equation, align and inline examples;
- `numbered_example.tex` -- complete example using the replacement options;
- `luatex_example.tex` -- multi-pair LuaLaTeX example with numbering and debug;
- `README.md` -- package description, installation and license;
- `LICENSE` -- license and maintenance notice;
- `CHANGELOG.md` -- version history;
- `MANIFEST.md` -- this list.

No extraction step is required. The PDF is generated from finaldelim.tex.
Build logs, auxiliary files, font caches and development-only audit/test
files are intentionally excluded from the upload archive.
