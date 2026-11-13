// Drawing glyph runs (port of the text parts of krilla's `content` module
// and of `text::group`).

///|
/// The start of the text of a glyph in `text` (`glyph_text`).
#inline
fn glyph_text_start(g : Glyph) -> Int32 {
  if g.text_start < 0 {
    0
  } else {
    g.text_start
  }
}

///|
/// The end of the text of a glyph in `text` (`glyph_text`).
#inline
fn glyph_text_end(text : String, g : Glyph) -> Int32 {
  if g.text_end > text.length() {
    text.length()
  } else {
    g.text_end
  }
}

///|
fn glyph_text(text : String, g : Glyph) -> String {
  let start = glyph_text_start(g)
  let end = glyph_text_end(text, g)
  if start >= end {
    ""
  } else {
    text.unsafe_substring(start~, end~)
  }
}

///|
/// `glyph_text` as a view, for comparisons that need no copy.
fn glyph_text_view(text : String, g : Glyph) -> StringView {
  let start = glyph_text_start(g)
  let end = glyph_text_end(text, g)
  if start >= end {
    ""
  } else {
    text.unsafe_view(start~, end~)
  }
}

///|
/// Whether `codepoints` is `glyph_text(text, g)`. Not upstream (`c != text`
/// on two `&str`): the code units are compared in place, since this is
/// asked for every glyph that is drawn.
fn is_glyph_text(codepoints : String, text : String, g : Glyph) -> Bool {
  let start = glyph_text_start(g)
  let end = glyph_text_end(text, g)
  let len = if start >= end { 0 } else { end - start }
  if codepoints.length() != len {
    return false
  }
  // In bounds: `0 <= start`, and `start + len == end <= text.length()` if
  // `len > 0`; `i < len == codepoints.length()`.
  for i in 0..<len {
    if codepoints.unsafe_get(i) != text.unsafe_get(start + i) {
      return false
    }
  }
  true
}

///|
/// The glyphs with their cluster ranges clamped to the text
/// (`0 <= text_start <= text_end <= text.length()`). Glyphs whose ranges
/// are all inside the text are returned as they are, without a copy: the
/// caller's array is then read while the run is drawn. The one piece of
/// the caller's code that runs meanwhile is `ColorGlyphs.is_color`, which
/// must not write to it.
fn clamp_clusters(glyphs : ArrayView[Glyph], text : String) -> ArrayView[Glyph] {
  let len = text.length()
  let mut clamped = true
  for g in glyphs {
    if g.text_start < 0 || g.text_end < g.text_start || g.text_end > len {
      clamped = false
      break
    }
  }
  if clamped {
    return glyphs
  }
  let out = []
  for g in glyphs {
    let start = if g.text_start < 0 {
      0
    } else if g.text_start > len {
      len
    } else {
      g.text_start
    }
    let end = if g.text_end < start {
      start
    } else if g.text_end > len {
      len
    } else {
      g.text_end
    }
    out.push({ ..g, text_start: start, text_end: end, })
  }
  out
}

///|
/// Whether a run of glyphs needs to be segmented into spans with
/// `/ActualText` (krilla `use_text_spanner`). Also registers the codepoints
/// of glyphs as long as no span is needed.
fn use_text_spanner(
  sc : SerializeContext,
  glyphs : ArrayView[Glyph],
  text : String,
  context_color : Int32,
  fc : FontContainer,
) -> Bool {
  if glyphs.is_empty() {
    return false
  }
  let mut do_text_span = false
  // (krilla's `check_single` closure is written out at its two calls: a
  // closure that captures `do_text_span` is an allocation per run.)
  for i in 0..<(glyphs.length() - 1) {
    let prev = glyphs[i]
    let next = glyphs[i + 1]
    // If two glyphs are part of the same cluster, we definitely need a text
    // span.
    if prev.text_start == next.text_start && prev.text_end == next.text_end {
      do_text_span = true
    }
    // As soon as we know that the glyph run requires a text span, we do not
    // insert any codepoints anymore, because otherwise we might
    // unnecessarily pollute the cmap with entries that wouldn't be
    // necessary. The text spanner will then iterate over the all glyphs
    // again and thus take care of inserting cmap entries for any remaining
    // glyphs we ignore now.
    if !do_text_span {
      do_text_span = check_text_span_prop(sc, prev, text, context_color, fc)
    }
  }
  // Since the loop checks groups of two, we need to manually check the last
  // glyph.
  if !do_text_span {
    do_text_span = check_text_span_prop(
      sc,
      glyphs[glyphs.length() - 1],
      text,
      context_color,
      fc,
    )
  }
  do_text_span
}

///|
/// Whether the glyph needs a text span: registers its codepoints, unless it
/// has others already (krilla `check_text_span_prop`, which sets a `&mut
/// bool`).
fn check_text_span_prop(
  sc : SerializeContext,
  glyph : Glyph,
  text : String,
  context_color : Int32,
  fc : FontContainer,
) -> Bool {
  let { fid, code, } = fc.add_glyph(sc, glyph.glyph_id, context_color)
  match fc.get_codepoints(fid, code) {
    // If there already exists an entry, then the codepoints are invalid, and
    // we will have to use a text span.
    Some(c) => !is_glyph_text(c, text, glyph)
    None => {
      fc.set_codepoints(fid, code, glyph_text(text, glyph), glyph.location)
      false
    }
  }
}

///|
/// A segment of a glyph run, possibly with an actual text.
priv struct GlyphSpan {
  glyphs : ArrayView[Glyph]
  actual_text : String?
}

///|
/// krilla's `func` of `GlyphSpanner::next`: registers the codepoints of a
/// glyph of a spanned run and returns whether the glyph has already been
/// assigned other codepoints. `has_previous`, `previous_start` and
/// `previous_end` are its `previous_range` (the cluster of the glyph
/// before, if there is one).
///
/// Not upstream: a function of its own that is given the range as numbers
/// and returns the one thing that is not the glyph's own range, since a
/// closure, an option of a tuple and a tuple of a tuple were allocations
/// for every glyph of a run that needs spans (every glyph of text that is
/// written from right to left).
fn span_glyph(
  sc : SerializeContext,
  g : Glyph,
  has_previous : Bool,
  previous_start : Int32,
  previous_end : Int32,
  forbid_invalid_codepoints : Bool,
  context_color : Int32,
  fc : FontContainer,
  text : String,
) -> Bool {
  let { fid, code, } = fc.add_glyph(sc, g.glyph_id, context_color)
  let codepoints = fc.get_codepoints(fid, code)
  // Whether the glyph has these codepoints already.
  let same = match codepoints {
    Some(c) => is_glyph_text(c, text, g)
    None => false
  }
  // Check if the glyph has already been assigned codepoints that don't
  // match the one we are seeing right now.
  let incompatible = codepoints is Some(_) && !same
  // Only set the codepoint if there isn't a previous, different mapping,
  // and if we are not already building a spanned run.
  let same_prev = has_previous &&
    previous_start == g.text_start &&
    previous_end == g.text_end
  if !incompatible && (!same_prev || forbid_invalid_codepoints) && !same {
    fc.set_codepoints(fid, code, glyph_text(text, g), g.location)
  }
  incompatible
}

///|
/// Segment a glyph run into spans that either need an `/ActualText` or not
/// (krilla `GlyphSpanner`). The cluster ranges of the glyphs are inside the
/// text (`clamp_clusters`).
fn glyph_spans(
  sc : SerializeContext,
  slice : ArrayView[Glyph],
  text : String,
  reversed : Bool,
  forbid_invalid_codepoints : Bool,
  context_color : Int32,
  fc : FontContainer,
) -> Array[GlyphSpan] {
  let out = []
  let mut slice = slice
  while !slice.is_empty() {
    let mut use_span : Bool? = None
    let mut count = 1
    // Get the range of the first glyph, as well as whether it's
    // incompatible.
    let first = slice[0]
    let first_start = first.text_start
    let first_end = first.text_end
    let first_incompatible = span_glyph(
      sc, first, false, 0, 0, forbid_invalid_codepoints, context_color, fc, text,
    )
    let mut prev_start = first_start
    let mut prev_end = first_end
    let mut i = 1
    while i < slice.length() {
      let next = slice[i]
      let next_start = next.text_start
      let next_end = next.text_end
      let next_incompatible = span_glyph(
        sc, next, true, prev_start, prev_end, forbid_invalid_codepoints, context_color,
        fc, text,
      )
      let same_range = prev_start == next_start && prev_end == next_end
      let mut stop = false
      match use_span {
        None =>
          if same_range {
            use_span = Some(true)
          } else {
            use_span = Some(first_incompatible)
            if first_incompatible || next_incompatible {
              stop = true
            }
          }
        Some(true) => if !same_range { stop = true }
        Some(false) =>
          if same_range {
            count -= 1
            stop = true
          } else if next_incompatible {
            stop = true
          }
      }
      if stop {
        break
      }
      prev_start = next_start
      prev_end = next_end
      count += 1
      // `/ReversedChars` show strings shall not contain interior space
      // glyphs. (The text of the cluster is `" "`: in bounds, since the
      // clusters are inside the text.)
      if reversed &&
        count > 1 &&
        prev_end - prev_start == 1 &&
        text.unsafe_get(prev_start).to_int() == 0x20 {
        break
      }
      i += 1
    }
    if count == 1 {
      use_span = Some(first_incompatible)
    }
    let head = slice[0:count]
    slice = slice[count:]
    let actual_text = if use_span.unwrap_or(false) {
      Some(text.unsafe_substring(start=first_start, end=first_end))
    } else {
      None
    }
    out.push({ glyphs: head, actual_text, })
  }
  out
}

///|
/// The number of glyphs at the start of the non-empty `slice` that can be
/// shown with one operator (same PDF font, same y offset, no y advance):
/// the next group of krilla's `GlyphGrouper`. Not upstream: the caller
/// keeps the rest of the slice, so that segmenting a span allocates neither
/// an iterator nor an array of groups.
fn glyph_group_len(
  sc : SerializeContext,
  slice : ArrayView[Glyph],
  context_color : Int32,
  fc : FontContainer,
) -> Int32 {
  let first = slice[0]
  let first_fid = fc.add_glyph(sc, first.glyph_id, context_color).fid
  let mut count = 1
  while count < slice.length() {
    let next = slice[count]
    // If either of those is different, we need to start a new subrun.
    if first_fid != fc.add_glyph(sc, next.glyph_id, context_color).fid ||
      first.y_offset != next.y_offset ||
      first.y_advance != 0.0 ||
      next.y_advance != 0.0 {
      break
    }
    count += 1
  }
  count
}

///|
/// An approximate bounding box of a glyph run.
fn get_glyphs_bbox(
  glyphs : ArrayView[Glyph],
  x : Double,
  y : Double,
  size : Double,
  font : Font,
) -> Rect {
  let (x0, y0, x1, y1) = font.bbox
  let s = size / font.units_per_em
  let fb = Rect::from_ltrb(x0, y0, x1, y1)
  let (bl0, bt0, br0, bb0) = match fb {
    Some(fb) => {
      let r = fb
        .transform(Transform::from_scale(s, -s))
        .transform(Transform::from_translate(x, y))
      (r.left, r.top, r.right, r.bottom)
    }
    None => (x, y, x + 1.0, y + 1.0)
  }
  let mut bl = bl0
  let mut bt = bt0
  let mut br = br0
  let mut bb = bb0
  let mut x = x
  let mut y = y
  for g in glyphs {
    x += g.x_advance * size
    y -= g.y_advance * size
    bl = @cmp.minimum(bl, x + g.x_offset * size)
    br = @cmp.maximum(br, x + g.x_offset * size)
    bt = @cmp.minimum(bt, y - g.y_offset * size)
    bb = @cmp.maximum(bb, y - g.y_offset * size)
  }
  { left: bl, top: bt, right: br, bottom: bb, }
}

///|
/// Text rendering modes.
#derive(Eq)
priv enum RenderMode {
  FillMode
  StrokeMode
  FillStrokeMode
}

///|
/// The bounding box that is given for a solid fill or stroke of text if the
/// box of the glyphs is not needed.
let unit_rect : Rect = { left: 0.0, top: 0.0, right: 1.0, bottom: 1.0, }

///|
/// The position of the next glyph of a run (krilla's `cur_x` and `cur_y`,
/// which it hands on as `&mut f32`). Not upstream: a value that the
/// functions take and return, so that a run needs no cells for the two.
#valtype
priv struct TextCursor {
  x : Double
  y : Double
}

///|
/// krilla's `fill_action` closure of `draw_glyphs`. (Not upstream, like
/// the three methods after it: a closure is an allocation per glyph run,
/// and what these captured is given to `fill_stroke_glyph_run` anyway.)
fn ContentBuilder::glyphs_fill_action(
  self : ContentBuilder,
  sc : SerializeContext,
  fill : Fill,
  glyphs : ArrayView[Glyph],
  x : Double,
  y : Double,
  font_size : Double,
  font : Font,
) -> Unit {
  // Calculating the glyphs bbox is very expensive but not always necessary,
  // so omit if not needed.
  let bbox = if self.bbox_important || !(fill.paint is Color(_)) {
    let bbox = get_glyphs_bbox(glyphs, x, y, font_size, font)
    self.expand_bbox(bbox)
    bbox
  } else {
    unit_rect
  }
  self.content_set_fill_properties(sc, bbox, fill)
}

///|
/// krilla's `stroke_action` closure of `draw_glyphs`.
fn ContentBuilder::glyphs_stroke_action(
  self : ContentBuilder,
  sc : SerializeContext,
  stroke : Stroke,
  glyphs : ArrayView[Glyph],
  x : Double,
  y : Double,
  font_size : Double,
  font : Font,
) -> Unit {
  let bbox = if self.bbox_important || !(stroke.paint is Color(_)) {
    let bbox = get_glyphs_bbox(glyphs, x, y, font_size, font)
    self.expand_bbox(bbox)
    bbox
  } else {
    unit_rect
  }
  self.content_set_stroke_properties(sc, bbox, stroke)
}

///|
/// krilla's `set_fill_opacity` closure of `draw_glyphs`.
fn ContentBuilder::set_glyphs_fill_opacity(
  self : ContentBuilder,
  fill : Fill,
) -> Unit {
  // PDF viewers don't show patterns with fill/stroke opacities
  // consistently. Because of this, the opacity is accounted for in the
  // pattern itself.
  if !(fill.paint is Pattern(_)) {
    self.set_fill_opacity(paint_opacity(fill.paint, fill.opacity))
  }
}

///|
/// krilla's `set_stroke_opacity` closure of `draw_glyphs`.
fn ContentBuilder::set_glyphs_stroke_opacity(
  self : ContentBuilder,
  stroke : Stroke,
) -> Unit {
  if !(stroke.paint is Pattern(_)) {
    let opacity = paint_opacity(stroke.paint, stroke.opacity)
    self.set_stroke_opacity(opacity)
    self.set_fill_opacity(opacity)
  }
}

///|
fn ContentBuilder::draw_glyphs(
  self : ContentBuilder,
  sc : SerializeContext,
  start : Point,
  fill : Fill?,
  stroke : Stroke?,
  context_color : Int32,
  glyphs : ArrayView[Glyph],
  font : Font,
  text : String,
  font_size : Double,
) -> Unit {
  // Gradients without stops paint nothing.
  let fill = match fill {
    Some(f) if paint_is_empty(f.paint) => None
    _ => fill
  }
  let stroke = match stroke {
    Some(s) if paint_is_empty(s.paint) => None
    _ => stroke
  }
  if fill is None && stroke is None {
    return
  }
  // Clamp the cluster ranges to the text, so that all later uses (codepoint
  // mappings, `/ActualText`, reversed-text checks) stay in bounds.
  let glyphs = clamp_clusters(glyphs, text)
  let x = start.x
  let y = start.y
  self.graphics_states.save_state()
  // (The fill and the stroke are handed on in place of krilla's `action`
  // closure, which calls `fill_action` and `stroke_action` for them.)
  let mode = match fill {
    Some(f) => {
      self.set_glyphs_fill_opacity(f)
      match stroke {
        Some(s) => {
          self.set_glyphs_stroke_opacity(s)
          FillStrokeMode
        }
        None => FillMode
      }
    }
    None => {
      if stroke is Some(s) {
        self.set_glyphs_stroke_opacity(s)
      }
      StrokeMode
    }
  }
  self.fill_stroke_glyph_run(
    sc, x, y, mode, fill, stroke, context_color, glyphs, font, text, font_size,
  )
  self.graphics_states.restore_state()
}

///|
fn ContentBuilder::fill_stroke_glyph_run(
  self : ContentBuilder,
  sc : SerializeContext,
  x : Double,
  y : Double,
  mode : RenderMode,
  fill : Fill?,
  stroke : Stroke?,
  context_color : Int32,
  glyphs : ArrayView[Glyph],
  font : Font,
  text : String,
  font_size : Double,
) -> Unit {
  if glyphs.is_empty() {
    return
  }
  // krilla's `apply_isolated_op` with a `prep` that does nothing, written
  // out: the operation as a closure is an allocation per glyph run.
  self.begin_isolated_op()
  self.write_isolated_state(sc)
  let cur = TextCursor::{ x, y, }
  // When the glyph ranges are monotonically decreasing, the glyphs are in
  // reverse order and we should write `/ReversedChars` marked content.
  let mut reversed = glyphs.length() > 1
  if reversed {
    for i in 0..<(glyphs.length() - 1) {
      if glyphs[i].text_start < glyphs[i + 1].text_end {
        reversed = false
        break
      }
    }
  }
  // krilla's `action`.
  if fill is Some(f) {
    self.glyphs_fill_action(sc, f, glyphs, x, y, font_size, font)
  }
  if stroke is Some(s) {
    self.glyphs_stroke_action(sc, s, glyphs, x, y, font_size, font)
  }
  self.content.op("BT")
  let fc = sc.register_font_container(font)
  let do_text_span = reversed ||
    use_text_spanner(sc, glyphs, text, context_color, fc)
  if do_text_span {
    // Separate into distinct glyph runs that either are encoded using
    // actual text, or are not.
    let spanned = glyph_spans(
      sc,
      glyphs,
      text,
      reversed,
      sc.settings.validators().requires_codepoint_mappings(),
      context_color,
      fc,
    )
    let mut cur = cur
    for fragment in spanned {
      cur = self.fill_stroke_glyph_span(
        sc,
        cur,
        fragment.glyphs,
        fragment.actual_text,
        mode,
        context_color,
        fc,
        text,
        font_size,
        reversed,
      )
    }
  } else {
    self.fill_stroke_glyph_span(
      sc,
      cur,
      glyphs,
      None,
      mode,
      context_color,
      fc,
      text,
      font_size,
      reversed,
    )
    |> ignore
  }
  self.content.op("ET")
  self.end_isolated_op()
}

///|
/// Draws the glyphs of a span (krilla's `GlyphSpan`: the glyphs and, for a
/// spanned one, the actual text) and returns where the next span starts.
fn ContentBuilder::fill_stroke_glyph_span(
  self : ContentBuilder,
  sc : SerializeContext,
  cur : TextCursor,
  glyphs : ArrayView[Glyph],
  actual_text : String?,
  mode : RenderMode,
  context_color : Int32,
  fc : FontContainer,
  text : String,
  font_size : Double,
  reversed : Bool,
) -> TextCursor {
  let mut cur_x = cur.x
  let mut cur_y = cur.y
  if actual_text is Some(t) {
    self.content.name("Span")
    self.content.obj(Dict([("ActualText", TextStr(t))]))
    self.content.op("BDC")
  }
  if reversed {
    self.content.name("ReversedChars")
    self.content.op("BMC")
  }
  // Segment into glyph runs that can be encoded in one go using a PDF text
  // showing operator (i.e. no y shift, same Type3 font, etc.)
  let mut slice = glyphs
  while !slice.is_empty() {
    let count = glyph_group_len(sc, slice, context_color, fc)
    let group = slice[0:count]
    slice = slice[count:]
    let first = group[0]
    let fid = fc.add_glyph(sc, first.glyph_id, context_color).fid
    // Type 3 fonts are always filled.
    let mode = if fid >= 0 { FillMode } else { mode }
    self.content.raw(
      match mode {
        FillMode => "0"
        FillStrokeMode => "2"
        StrokeMode => "1"
      },
    )
    self.content.op(" Tr")
    cur_x = self.encode_consecutive_glyph_run(
      sc,
      cur_x,
      cur_y - first.y_offset * font_size,
      fid,
      context_color,
      fc,
      font_size,
      group,
      text,
    )
    cur_y = cur_y - first.y_advance * font_size
  }
  if reversed {
    self.content.op("EMC")
  }
  if actual_text is Some(_) {
    self.content.op("EMC")
  }
  { x: cur_x, y: cur_y, }
}

///|
fn ContentBuilder::encode_consecutive_glyph_run(
  self : ContentBuilder,
  sc : SerializeContext,
  cur_x : Double,
  cur_y : Double,
  fid : Int32,
  context_color : Int32,
  fc : FontContainer,
  size : Double,
  glyphs : ArrayView[Glyph],
  text : String,
) -> Double {
  let font_name = self.rd.register(Font, fc.font_ref(fid))
  self.content.name(font_name)
  self.content.num(size)
  self.content.op("Tf")
  self.content.transform_text(
    Transform::from_row(1.0, 0.0, 0.0, -1.0, cur_x, cur_y),
  )
  let font = fc.font
  let last_resort = font.postscript_name == Some("LastResort")
  for g in glyphs {
    if g.glyph_id == 0 || last_resort {
      sc.register_validation_error(
        ContainsNotDefGlyph(font, g.location, glyph_text(text, g)),
      )
    }
  }
  // If it's just a single glyph and without an x_offset, there is no need
  // for individual positioning, so we can use `Tj` instead of `TJ`. The
  // reason we're doing this is because Acrobat's copy-paste is a bit buggy
  // if `/ActualText` is used at the end of a line, but only if `TJ` is used.
  // With `Tj`, it's fine.
  if glyphs.length() == 1 && glyphs[0].x_offset.abs() <= 0.001 {
    return self.encode_single_glyph(
      sc,
      cur_x,
      fid,
      context_color,
      fc,
      size,
      glyphs[0],
    )
  }
  self.encode_glyphs_with_individual_positioning(
    sc, cur_x, fid, context_color, fc, size, glyphs,
  )
}

///|
fn ContentBuilder::encode_single_glyph(
  self : ContentBuilder,
  sc : SerializeContext,
  cur_x : Double,
  fid : Int32,
  context_color : Int32,
  fc : FontContainer,
  size : Double,
  glyph : Glyph,
) -> Double {
  let code = fc.add_glyph(sc, glyph.glyph_id, context_color).code
  let encoded = self.scratch
  encoded.clear()
  write_code(encoded, fid, code)
  self.content.show(encoded)
  cur_x + glyph.x_advance * size
}

///|
/// Not upstream in two ways. The items of the `TJ` array are written as
/// they come (pdf-writer's `show_positioned().items()`), not collected as
/// objects first; `items` counts them. And the advance width of a glyph is
/// asked of the font container, which keeps it
/// (`FontContainer::advance_width`), where krilla asks the font.
fn ContentBuilder::encode_glyphs_with_individual_positioning(
  self : ContentBuilder,
  sc : SerializeContext,
  cur_x : Double,
  fid : Int32,
  context_color : Int32,
  fc : FontContainer,
  size : Double,
  glyphs : ArrayView[Glyph],
) -> Double {
  let mut cur_x = cur_x
  let font = fc.font
  let upem = fc.units_per_em(fid)
  let encoded = self.scratch
  encoded.clear()
  let mut adjustment = 0.0
  self.content.begin_positioned()
  let mut items = 0
  for g in glyphs {
    let code = fc.add_glyph(sc, g.glyph_id, context_color).code
    // (krilla's `scale` is a multiplication by `upem`.)
    let x_advance = g.x_advance * upem
    let x_offset = g.x_offset * upem
    adjustment += x_offset
    // Make sure we don't write miniscule adjustments.
    if adjustment.abs() > 0.001 {
      if encoded.len > 0 {
        self.content.positioned_show(items, encoded)
        items += 1
        encoded.clear()
      }
      // Adjustments are always in 1000 units, even for Type 3 fonts.
      self.content.positioned_adjust(
        items,
        -(adjustment / upem * pdf_units_per_em),
      )
      items += 1
      adjustment = 0.0
    }
    write_code(encoded, fid, code)
    let advance = fc.advance_width(g.glyph_id)
    // (Not NaN: the advance is kept.)
    if advance == advance {
      adjustment += x_advance - advance / font.units_per_em * upem
    } else if font.advance_width(g.glyph_id) is Some(n) {
      adjustment += x_advance - n / font.units_per_em * upem
    }
    adjustment -= x_offset
    // cur_x/cur_y and glyph metrics are in user space units.
    cur_x = cur_x + g.x_advance * size
  }
  if encoded.len > 0 {
    self.content.positioned_show(items, encoded)
  }
  self.content.end_positioned()
  cur_x
}

///|
fn Content::transform_text(self : Content, ts : Transform) -> Unit {
  self.num(ts.sx)
  self.num(ts.ky)
  self.num(ts.kx)
  self.num(ts.sy)
  self.num(ts.tx)
  self.num(ts.ty)
  self.op("Tm")
}
