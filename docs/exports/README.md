# Generated exports

**These files are generated — do not hand-edit them.** They are rendered from the markdown
sources in `docs/` and will be overwritten on the next build.

| Export | Source of truth |
|---|---|
| `PRGR_Complete_Briefing.html` / `.pdf` | `docs/PRGR_Complete_Briefing.md` |
| `PRGR_Optics_and_Capture_Guide.html` / `.pdf` | `docs/PRGR_Optics_and_Capture_Guide.md` |

The HTML files are fully self-contained (images embedded as base64), so a single `.html`
or `.pdf` can be emailed or opened offline with no repo access.

## To regenerate

Edit the markdown source in `docs/`, then re-render. The HTML is print-tuned, so the
simplest path to a PDF is to open the `.html` in a browser and **Print → Save as PDF**.
(The maintained render pipeline uses `python-markdown` + headless Chromium; ask the docs
owner to rebuild if you don't have that set up.)
