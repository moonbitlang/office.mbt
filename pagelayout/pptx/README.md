# PPTX page layout

`layout_presentation` reads presentation, layout, master and theme parts into the
shared `PageModel`. It preserves presentation slide order and source geometry.
The input archive is never rewritten. The returned `fonts` catalog is the one
that measured the model; pass it to `svg.render_pages` to embed the matching
TrueType or CFF programs in standalone SVGs.

Register locally available fonts before layout. Embedded EOT (uncompressed,
XOR-obfuscated or MTX-compressed) or raw SFNT faces are added to an independent copy of that registry. Caller faces
take precedence, so an application can supply a decoded or installed face.
`font_fallbacks` maps source family names to ordered replacement families; those
replacements must be registered or bundled. Font versions and fallback choices
affect glyph widths and wrapping. `allow_bundled_fallbacks=true` opts into the
standard bundled replacements and reports each substitution in
`font_substitutions`. These choices are document inputs, not global state.

The current renderer handles rectangular text boxes and shapes, straight lines,
solid colors, theme color mappings, slide backgrounds, rectangular picture
crops, rotation, flips and nested group transforms. Text layout includes style
inheritance, paragraph and run metrics, explicit spacing, language-specific line
breaks, character bullets, single underlines and legacy TrueType pair kerning.
Intrinsic glyph advances follow PowerPoint's eighth-point measurement grid;
character spacing retains hundredth-point precision and a zero kerning
threshold disables pair adjustments. Font sizes and shape geometry retain
their original precision.

This package is still under development. Unsupported geometry, graphic frames
(including tables and charts), non-solid fills, recognized drawing effects,
vertical or right-to-left text, text auto-fit, tab stops, preset dash patterns,
complex text decorations and automatic/picture bullets currently raise an
error naming the feature. Animation and transition playback are outside the
static `PageModel`. This is not a claim of complete PowerPoint compatibility.
SVG font embedding covers registered faces with outline programs; applications
using metrics-only or bundled fallback faces must provide their browser fonts.

The `render_fixture` command accepts an external deck and font manifest for
local visual comparison:

```sh
moon run pagelayout/pptx/render_fixture --target native -- \
  /absolute/path/input.pptx /absolute/path/output/slide /absolute/path/fonts.json
```

Each manifest entry has `family`, `path`, `bold` and `italic` fields. An optional
`fallback_for` array lists source families that may use that face as a fallback.
The command writes one SVG per slide and the corresponding model JSON. Private
decks, reference exports and installed font programs belong outside the source
tree. Synthetic font programs used by the tests contain only test glyphs.

The MTX decoder is adapted from `mtx-decompressor` under MPL-2.0. Its source,
license and attribution are in `mtx/`. Other files retain the module license.
