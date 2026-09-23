<!-- Adapted from moon-pptx for the Office workspace; see ../UPSTREAM.md. -->
# PPTX demos

The `pptx/demos` package builds a 26-slide presentation covering text, shapes,
charts, tables, media, SmartArt, animations, masters, and typed layouts. It is
part of the `moonbitlang/pptx` module and the root Office workspace. Its
black-box tests reopen the generated presentations through the public API.

`pptx/cmd/demos` is the executable entry point. From the repository root:

```sh
moon test --deny-warn --target native pptx/demos
bash scripts/generate_pptx_demos.sh
bash scripts/validate_pptx.sh demos_out_pptx/sample.pptx
```

The generator decodes the executable's hex output into a PPTX. The default
output directory is `demos_out_pptx/`; an explicit directory may be passed to
the script. To diagnose one feature, set `split_mode` in
[pptx/cmd/demos/main.mbt](../cmd/demos/main.mbt) to `true` and run the
executable directly. Its labeled hex streams contain one isolated deck each.

Schema checks complement opening, displaying, editing, and reopening the
output in PowerPoint, Keynote, or LibreOffice; they do not replace those checks.

## Slide list

| # | Slide | Features exercised |
|---|---|---|
| 1 | Title | Widescreen sizing, styled run, external hyperlink, speaker notes |
| 2 | Table of contents | Internal-slide hyperlinks (jump-to-slide via `ppaction://hlinksldjump`) |
| 3 | Text features | Multi-paragraph, alignment, AutoNum bullets |
| 4 | Shapes | rect / ellipse / round-rect + Connector + GroupShape |
| 5 | Custom geometry | Hand-drawn star path |
| 6 | Picture | Synthesized 16×16 BMP + image-size auto-detection + crop |
| 7 | Tables | Merged header + per-edge custom borders + cell fills |
| 8 | Charts I | Bar / line / pie grid |
| 9 | Charts II | Area / radar / doughnut grid |
| 10 | Charts III | Scatter + bubble (two value-axis families) |
| 11 | Charts IV | 3-D bar + stock + of-pie (extended axis + 3-D wrappers) |
| 12 | Slide background | Solid-fill slide background |
| 13 | Combo chart | Columns + line on a secondary value axis, plus the embedded data workbook — "Edit Data" opens the real rows |
| 14 | SVG image | Vector image with a raster fallback |
| 15 | Editing shapes | Recolour boxes already on the slide via `map_shapes` |
| 16 | Embedded media | A movie + a sound clip (placeholder media payloads) |
| 17 | SmartArt | Org chart synthesised into the five-part DiagramML graphic; the whole tree lays out via the recursive layoutDef; the CEO node carries per-node colour overrides |
| 18 | Animations | Fly-in entrance + spin emphasis on click (`with_animations` / `Timeline`) |
| 19 | Online video | YouTube clip embedded by URL (`add_youtube_video_mut`) |
| 20 | v0.5.2 features | Shape rotation / flip, run highlight + kerning + outline + glow, shape-level hyperlinks |
| 21 | v0.6 features | Gradient + pattern **text fills** (`with_text_fill`) and paragraph spacing — 150 % / absolute 28 pt line height, 18 pt space-before (`TextSpacing`) |
| 22 | v0.7 features | A gallery-styled table (`Table::with_style(MediumStyle2Accent1)`) + the `Fill::solid` / `linear_gradient` / `pattern` convenience constructors |
| 23 | Master / template | Defined master + footer, auto date, slide number |
| 24–25 | Typed layouts | Compile-time placeholder schema (`add_section_header_slide_mut` / `add_title_content_slide_mut`) |
| 26 | Closing | Back-link hyperlink + speaker notes |

Plus, deck-wide: a slide transition on every slide, named **slide
sections** grouping the deck in the slide panel (`set_sections_mut`),
and **document properties** in both parts of File ▸ Info — core.xml
(title / author / …) and app.xml (company / manager,
`set_app_properties_mut`).
