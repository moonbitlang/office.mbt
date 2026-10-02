// Drawing glyph runs (port of the text parts of krilla's `content` module
// and of `text::group`).

///|
fn glyph_text(text : String, g : Glyph) -> String {
  let start = @math.maximum(0.0, g.text_start.to_double()).to_int()
  let end = @math.minimum(text.length().to_double(), g.text_end.to_double()).to_int()
  if start >= end {
    ""
  } else {
    text.unsafe_substring(start~, end~)
  }
}

///|
/// Whether a run of glyphs needs to be segmented into spans with
/// `/ActualText` (krilla `use_text_spanner`). Also registers the codepoints
/// of glyphs as long as no span is needed.
fn use_text_spanner(
  glyphs : ArrayView[Glyph],
  text : String,
  fc : FontContainer,
) -> Bool {
  if glyphs.is_empty() {
    return false
  }
  let mut do_text_span = false
  let check_single = (glyph : Glyph) => {
    if !do_text_span {
      let cid = fc.cid_font.add_glyph(glyph.glyph_id)
      let t = glyph_text(text, glyph)
      match fc.cid_font.get_codepoints(cid) {
        Some(c) => if c != t { do_text_span = true }
        None => fc.cid_font.set_codepoints(cid, t, glyph.location)
      }
    }
  }
  for i in 0..<(glyphs.length() - 1) {
    let prev = glyphs[i]
    let next = glyphs[i + 1]
    // If two glyphs are part of the same cluster, we definitely need a text
    // span.
    if prev.text_start == next.text_start && prev.text_end == next.text_end {
      do_text_span = true
    }
    check_single(prev)
  }
  check_single(glyphs[glyphs.length() - 1])
  do_text_span
}

///|
/// A segment of a glyph run, possibly with an actual text.
priv struct GlyphSpan {
  glyphs : ArrayView[Glyph]
  actual_text : String?
}

///|
/// Segment a glyph run into spans that either need an `/ActualText` or not
/// (krilla `GlyphSpanner`).
fn glyph_spans(
  slice : ArrayView[Glyph],
  text : String,
  reversed : Bool,
  forbid_invalid_codepoints : Bool,
  fc : FontContainer,
) -> Array[GlyphSpan] {
  let out = []
  let func = (g : Glyph, previous_range : (Int, Int)?) => {
    let cid = fc.cid_font.add_glyph(g.glyph_id)
    let range = (g.text_start, g.text_end)
    let t = glyph_text(text, g)
    let codepoints = fc.cid_font.get_codepoints(cid)
    // Check if the glyph has already been assigned codepoints that don't
    // match the one we are seeing right now.
    let incompatible = match codepoints {
      Some(c) => c != t
      None => false
    }
    // Only set the codepoint if there isn't a previous, different mapping,
    // and if we are not already building a spanned run.
    let same_prev = match previous_range {
      Some(p) => p == range
      None => false
    }
    if !incompatible &&
      (!same_prev || forbid_invalid_codepoints) &&
      codepoints != Some(t) {
      fc.cid_font.set_codepoints(cid, t, g.location)
    }
    (range, incompatible)
  }
  let mut slice = slice
  while !slice.is_empty() {
    let mut use_span : Bool? = None
    let mut count = 1
    let (first_range, first_incompatible) = func(slice[0], None)
    let mut prev_range = first_range
    let mut i = 1
    while i < slice.length() {
      let (next_range, next_incompatible) = func(slice[i], Some(prev_range))
      let mut stop = false
      match use_span {
        None =>
          if prev_range == next_range {
            use_span = Some(true)
          } else {
            use_span = Some(first_incompatible)
            if first_incompatible || next_incompatible {
              stop = true
            }
          }
        Some(true) => if prev_range != next_range { stop = true }
        Some(false) =>
          if prev_range == next_range {
            count -= 1
            stop = true
          } else if next_incompatible {
            stop = true
          }
      }
      if stop {
        break
      }
      prev_range = next_range
      count += 1
      // `/ReversedChars` show strings shall not contain interior space
      // glyphs.
      if reversed &&
        count > 1 &&
        text.unsafe_substring(start=prev_range.0, end=prev_range.1) == " " {
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
      Some(text.unsafe_substring(start=first_range.0, end=first_range.1))
    } else {
      None
    }
    out.push({ glyphs: head, actual_text, })
  }
  out
}

///|
/// Segment glyphs into groups that can be shown with one operator (same y
/// offset, no y advance).
fn glyph_groups(slice : ArrayView[Glyph]) -> Array[ArrayView[Glyph]] {
  let out = []
  let mut slice = slice
  while !slice.is_empty() {
    let first = slice[0]
    let mut count = 1
    while count < slice.length() {
      let next = slice[count]
      if first.y_offset != next.y_offset ||
        first.y_advance != 0.0 ||
        next.y_advance != 0.0 {
        break
      }
      count += 1
    }
    out.push(slice[0:count])
    slice = slice[count:]
  }
  out
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
    bl = @math.minimum(bl, x + g.x_offset * size)
    br = @math.maximum(br, x + g.x_offset * size)
    bt = @math.minimum(bt, y - g.y_offset * size)
    bb = @math.maximum(bb, y - g.y_offset * size)
  }
  { left: bl, top: bt, right: br, bottom: bb, }
}

///|
/// Text rendering modes.
priv enum RenderMode {
  FillMode
  StrokeMode
  FillStrokeMode
} derive(Eq)

///|
fn ContentBuilder::draw_glyphs(
  self : ContentBuilder,
  sc : SerializeContext,
  start : Point,
  fill : Fill?,
  stroke : Stroke?,
  glyphs : ArrayView[Glyph],
  font : Font,
  text : String,
  font_size : Double,
) -> Unit {
  if fill is None && stroke is None {
    return
  }
  let (x, y) = (start.x, start.y)
  self.graphics_states.save_state()
  let bbox_important = self.bbox_important
  let fill_action = (sb : ContentBuilder, fill : Fill) => {
    let bbox = if bbox_important || !(fill.paint is Color(_)) {
      let bbox = get_glyphs_bbox(glyphs, x, y, font_size, font)
      sb.expand_bbox(bbox)
      bbox
    } else {
      { left: 0.0, top: 0.0, right: 1.0, bottom: 1.0, }
    }
    sb.content_set_fill_properties(sc, bbox, fill)
  }
  let stroke_action = (sb : ContentBuilder, stroke : Stroke) => {
    let bbox = if bbox_important || !(stroke.paint is Color(_)) {
      let bbox = get_glyphs_bbox(glyphs, x, y, font_size, font)
      sb.expand_bbox(bbox)
      bbox
    } else {
      { left: 0.0, top: 0.0, right: 1.0, bottom: 1.0, }
    }
    sb.content_set_stroke_properties(sc, bbox, stroke)
  }
  let set_fill_opacity = (sb : ContentBuilder, fill : Fill) => {
    if !(fill.paint is Pattern(_)) {
      sb.set_fill_opacity(fill.opacity)
    }
  }
  let set_stroke_opacity = (sb : ContentBuilder, stroke : Stroke) => {
    if !(stroke.paint is Pattern(_)) {
      sb.set_stroke_opacity(stroke.opacity)
      sb.set_fill_opacity(stroke.opacity)
    }
  }
  match (fill, stroke) {
    (Some(f), Some(s)) => {
      set_fill_opacity(self, f)
      set_stroke_opacity(self, s)
      self.fill_stroke_glyph_run(
        sc,
        x,
        y,
        FillStrokeMode,
        sb => {
          fill_action(sb, f)
          stroke_action(sb, s)
        },
        glyphs,
        font,
        text,
        font_size,
      )
    }
    (Some(f), None) => {
      set_fill_opacity(self, f)
      self.fill_stroke_glyph_run(
        sc,
        x,
        y,
        FillMode,
        sb => fill_action(sb, f),
        glyphs,
        font,
        text,
        font_size,
      )
    }
    (None, Some(s)) => {
      set_stroke_opacity(self, s)
      self.fill_stroke_glyph_run(
        sc,
        x,
        y,
        StrokeMode,
        sb => stroke_action(sb, s),
        glyphs,
        font,
        text,
        font_size,
      )
    }
    (None, None) => ()
  }
  self.graphics_states.restore_state()
}

///|
fn ContentBuilder::fill_stroke_glyph_run(
  self : ContentBuilder,
  sc : SerializeContext,
  x : Double,
  y : Double,
  mode : RenderMode,
  action : (ContentBuilder) -> Unit,
  glyphs : ArrayView[Glyph],
  font : Font,
  text : String,
  font_size : Double,
) -> Unit {
  if glyphs.is_empty() {
    return
  }
  self.apply_isolated_op(sc, _ => (), sb => {
    let cur_x = Ref::new(x)
    let cur_y = Ref::new(y)
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
    action(sb)
    sb.content.op("BT")
    let fc = sc.register_font_container(font)
    let do_text_span = reversed || use_text_spanner(glyphs, text, fc)
    if do_text_span {
      let spans = glyph_spans(
        glyphs,
        text,
        reversed,
        sc.settings.validators().requires_codepoint_mappings(),
        fc,
      )
      for span in spans {
        sb.fill_stroke_glyph_span(
          sc, cur_x, cur_y, span, mode, fc, text, font_size, reversed,
        )
      }
    } else {
      sb.fill_stroke_glyph_span(
        sc,
        cur_x,
        cur_y,
        { glyphs, actual_text: None, },
        mode,
        fc,
        text,
        font_size,
        reversed,
      )
    }
    sb.content.op("ET")
  })
}

///|
fn ContentBuilder::fill_stroke_glyph_span(
  self : ContentBuilder,
  sc : SerializeContext,
  cur_x : Ref[Double],
  cur_y : Ref[Double],
  span : GlyphSpan,
  mode : RenderMode,
  fc : FontContainer,
  text : String,
  font_size : Double,
  reversed : Bool,
) -> Unit {
  if span.actual_text is Some(t) {
    self.content.name("Span")
    self.content.obj(Dict([("ActualText", TextStr(t))]))
    self.content.op("BDC")
  }
  if reversed {
    self.content.name("ReversedChars")
    self.content.op("BMC")
  }
  for group in glyph_groups(span.glyphs) {
    let first = group[0]
    self.content.raw(
      match mode {
        FillMode => "0"
        FillStrokeMode => "2"
        StrokeMode => "1"
      },
    )
    self.content.op(" Tr")
    self.encode_consecutive_glyph_run(
      sc,
      cur_x,
      cur_y.val - first.y_offset * font_size,
      fc,
      font_size,
      group,
      text,
    )
    cur_y.val = cur_y.val - first.y_advance * font_size
  }
  if reversed {
    self.content.op("EMC")
  }
  if span.actual_text is Some(_) {
    self.content.op("EMC")
  }
}

///|
fn ContentBuilder::encode_consecutive_glyph_run(
  self : ContentBuilder,
  sc : SerializeContext,
  cur_x : Ref[Double],
  cur_y : Double,
  fc : FontContainer,
  size : Double,
  glyphs : ArrayView[Glyph],
  text : String,
) -> Unit {
  let font_name = self.rd.register(Font, fc.ref_)
  self.content.name(font_name)
  self.content.num(size)
  self.content.op("Tf")
  self.content.transform_text(
    Transform::from_row(1.0, 0.0, 0.0, -1.0, cur_x.val, cur_y),
  )
  let font = fc.font
  for g in glyphs {
    if g.glyph_id == 0 || font.postscript_name == Some("LastResort") {
      sc.register_validation_error(
        ContainsNotDefGlyph(font, g.location, glyph_text(text, g)),
      )
    }
  }
  // A single glyph without an x offset is shown with `Tj`.
  if glyphs.length() == 1 && glyphs[0].x_offset.abs() <= 0.001 {
    let g = glyphs[0]
    let cid = fc.cid_font.add_glyph(g.glyph_id)
    self.content.obj(Str(encode_cid(cid)))
    self.content.op("Tj")
    cur_x.val = cur_x.val + g.x_advance * size
    return
  }
  // Individual positioning with `TJ`.
  let items : Array[Obj] = []
  let encoded = @buffer.new()
  let mut adjustment = 0.0
  for g in glyphs {
    let cid = fc.cid_font.add_glyph(g.glyph_id)
    let scale = (v : Double) => v * pdf_units_per_em
    let x_advance = scale(g.x_advance)
    let font_advance = match font.advance_width(g.glyph_id) {
      Some(n) => Some(scale(n / font.units_per_em))
      None => None
    }
    let x_offset = scale(g.x_offset)
    adjustment += x_offset
    // Make sure we don't write miniscule adjustments.
    if adjustment.abs() > 0.001 {
      if encoded.length() > 0 {
        items.push(Str(encoded.to_bytes()))
        encoded.reset()
      }
      items.push(Real(-(adjustment / pdf_units_per_em * pdf_units_per_em)))
      adjustment = 0.0
    }
    encoded.write_bytes(encode_cid(cid))
    if font_advance is Some(fa) {
      adjustment += x_advance - fa
    }
    adjustment -= x_offset
    cur_x.val = cur_x.val + g.x_advance * size
  }
  if encoded.length() > 0 {
    items.push(Str(encoded.to_bytes()))
  }
  self.content.obj(Arr(items))
  self.content.op("TJ")
}

///|
fn encode_cid(cid : Int) -> Bytes {
  Bytes::from_array([((cid >> 8) & 0xFF).to_byte(), (cid & 0xFF).to_byte()])
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
