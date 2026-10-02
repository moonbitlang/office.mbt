// Drawing onto a surface (port of krilla's `surface` and `stream`
// modules).
//
// The coordinate system of a surface has its origin in the top-left corner
// with the y-axis pointing down. Every `push_*` must be matched by a `pop`.

///|
priv enum PushInstruction {
  PushTransform
  PushOpacity(Double)
  PushClipPath
  PushBlendMode
  PushMask(Mask)
  PushIsolated
}

///|
/// The content of a surface: identifies how the finished stream is used.
priv enum SurfaceKind {
  /// The surface of a page (with its tagging state).
  PageSurface(Page)
  /// A sub-surface whose stream is returned by `finish_stream`.
  StreamSurface
}

///|
/// A drawing surface.
pub struct Surface {
  priv sc : SerializeContext
  priv mut fill : Fill?
  priv mut stroke : Stroke?
  priv root_builder : ContentBuilder
  priv sub_builders : Array[ContentBuilder]
  priv push_instructions : Array[PushInstruction]
  /// The next marked content ID, if tagging is enabled.
  priv mut mcid : Int?
  priv kind : SurfaceKind
}

///|
fn Surface::get_mut(self : Surface) -> ContentBuilder {
  if self.sub_builders.is_empty() {
    self.root_builder
  } else {
    self.sub_builders[self.sub_builders.length() - 1]
  }
}

///|
/// Create a sub-surface for drawing a stream (for tiling patterns and
/// masks); finish it with `finish_stream`.
pub fn Surface::stream_surface(self : Surface) -> Surface {
  {
    sc: self.sc,
    fill: None,
    stroke: None,
    root_builder: ContentBuilder::new(Transform::identity(), true),
    sub_builders: [],
    push_instructions: [],
    mcid: None,
    kind: StreamSurface,
  }
}

///|
/// Finish a stream sub-surface.
pub fn Surface::finish_stream(self : Surface) -> Stream {
  if !self.sub_builders.is_empty() || !self.push_instructions.is_empty() {
    abort("unbalanced push/pop on stream surface")
  }
  self.root_builder.finish()
}

///|
pub fn Surface::set_fill(self : Surface, fill : Fill?) -> Unit {
  self.fill = fill
}

///|
pub fn Surface::set_stroke(self : Surface, stroke : Stroke?) -> Unit {
  self.stroke = stroke
}

///|
fn Surface::has_complex_fill_or_stroke(self : Surface) -> Bool {
  let complex_stroke = match self.stroke {
    Some(s) => s.opacity != 1.0 || paint_has_translucent_stops(s.paint)
    None => false
  }
  let complex_fill = match self.fill {
    Some(f) => paint_has_translucent_stops(f.paint)
    None => false
  }
  complex_fill || complex_stroke
}

///|
/// Draw a path with the current fill and/or stroke (black fill if neither
/// is set).
pub fn Surface::draw_path(self : Surface, path : Path) -> Unit {
  if self.fill is Some(_) || self.stroke is Some(_) {
    if self.has_complex_fill_or_stroke() {
      self.get_mut().draw_path(self.sc, path, self.fill, None)
      self.get_mut().draw_path(self.sc, path, None, self.stroke)
    } else {
      self.get_mut().draw_path(self.sc, path, self.fill, self.stroke)
    }
  } else {
    self.get_mut().draw_path(self.sc, path, Some(Fill::default()), None)
  }
}

///|
/// Start a tagged content section and return its identifier.
pub fn Surface::start_tagged(self : Surface, tag : ContentTag) -> Identifier {
  guard self.kind is PageSurface(page) && self.mcid is Some(mcid) else {
    return Dummy
  }
  let sc = self.sc
  match tag {
    Artifact(artifact) => {
      if (artifact.kind == Header || artifact.kind == Footer) &&
        sc.settings.pdf_version() <
        HeaderFooterArtifactSubtypes.minimum_pdf_version() {
        sc.register_validation_error(
          RequiresNewerPdfVersion(HeaderFooterArtifactSubtypes, sc.location),
        )
      }
      if artifact.requires_properties(sc.settings.pdf_version()) {
        self.get_mut().start_marked_content_with_properties(sc, None, tag)
      } else {
        self.get_mut().start_marked_content(tag.name())
      }
      Dummy
    }
    _ => {
      self.get_mut().start_marked_content_with_properties(sc, Some(mcid), tag)
      self.mcid = Some(mcid + 1)
      PageContent(page.page_index, mcid)
    }
  }
}

///|
/// End the current tagged section.
pub fn Surface::end_tagged(self : Surface) -> Unit {
  if self.mcid is Some(_) {
    self.get_mut().end_marked_content()
  }
}

///|
/// Draw a sequence of glyphs with the current fill and/or stroke.
pub fn Surface::draw_glyphs(
  self : Surface,
  start : Point,
  glyphs : ArrayView[Glyph],
  font : Font,
  text : String,
  font_size : Double,
) -> Unit {
  let sc = self.sc
  match (self.fill, self.stroke) {
    (Some(f), Some(s)) =>
      if self.has_complex_fill_or_stroke() {
        // Fill as text and stroke separately (krilla outlines the glyphs;
        // here the stroke is drawn as stroked text).
        self
        .get_mut()
        .draw_glyphs(sc, start, Some(f), None, glyphs, font, text, font_size)
        self
        .get_mut()
        .draw_glyphs(sc, start, None, Some(s), glyphs, font, text, font_size)
      } else {
        self
        .get_mut()
        .draw_glyphs(sc, start, Some(f), Some(s), glyphs, font, text, font_size)
      }
    (None, Some(s)) =>
      self
      .get_mut()
      .draw_glyphs(sc, start, None, Some(s), glyphs, font, text, font_size)
    (Some(f), None) =>
      self
      .get_mut()
      .draw_glyphs(sc, start, Some(f), None, glyphs, font, text, font_size)
    (None, None) =>
      self
      .get_mut()
      .draw_glyphs(
        sc,
        start,
        Some(Fill::default()),
        None,
        glyphs,
        font,
        text,
        font_size,
      )
  }
}

///|
/// Set the location assumed for subsequent operations.
pub fn Surface::set_location(self : Surface, location : Location) -> Unit {
  self.sc.set_location(location)
}

///|
pub fn Surface::reset_location(self : Surface) -> Unit {
  self.sc.reset_location()
}

///|
/// The current transformation matrix.
pub fn Surface::ctm(self : Surface) -> Transform {
  self.get_mut().cur_transform()
}

///|
/// Concatenate a transform to the current transformation matrix.
pub fn Surface::push_transform(self : Surface, transform : Transform) -> Unit {
  self.push_instructions.push(PushTransform)
  self.get_mut().save_graphics_state()
  self.get_mut().concat_transform(transform)
}

///|
/// Push a blend mode (a PDF blend mode name).
pub fn Surface::push_blend_mode(self : Surface, mode : String) -> Unit {
  self.push_instructions.push(PushBlendMode)
  self.get_mut().save_graphics_state()
  self.get_mut().set_blend_mode(mode)
}

///|
/// Push a clip path.
pub fn Surface::push_clip_path(
  self : Surface,
  path : Path,
  rule : FillRule,
) -> Unit {
  self.push_instructions.push(PushClipPath)
  self.get_mut().push_clip_path(path, rule)
}

///|
/// Push a mask.
pub fn Surface::push_mask(
  self : Surface,
  stream : Stream,
  luminosity : Bool,
) -> Unit {
  self.push_instructions.push(
    PushMask({ stream, luminosity, custom_bbox: None, }),
  )
  self.sub_builders.push(ContentBuilder::new(Transform::identity(), true))
}

///|
/// Push an opacity.
pub fn Surface::push_opacity(self : Surface, opacity : Double) -> Unit {
  self.push_instructions.push(PushOpacity(opacity))
  if opacity != 1.0 {
    self.sub_builders.push(ContentBuilder::new(Transform::identity(), true))
  }
}

///|
/// Push an isolated layer.
pub fn Surface::push_isolated(self : Surface) -> Unit {
  self.push_instructions.push(PushIsolated)
  self.sub_builders.push(ContentBuilder::new(Transform::identity(), true))
}

///|
/// Pop the last `push` instruction.
pub fn Surface::pop(self : Surface) -> Unit {
  guard self.push_instructions.pop() is Some(instr) else {
    abort("pop without push")
  }
  match instr {
    PushTransform | PushBlendMode => self.get_mut().restore_graphics_state()
    PushOpacity(o) =>
      if o != 1.0 {
        let stream = self.sub_builders.pop().unwrap().finish()
        self.get_mut().draw_opacified(self.sc, o, stream)
      }
    PushClipPath => self.get_mut().pop_clip_path()
    PushMask(mask) => {
      let stream = self.sub_builders.pop().unwrap().finish()
      self.get_mut().draw_masked(self.sc, mask, stream)
    }
    PushIsolated => {
      let stream = self.sub_builders.pop().unwrap().finish()
      self.get_mut().draw_isolated(self.sc, stream)
    }
  }
}

///|
/// Draw a raster image scaled to the given size.
pub fn Surface::draw_image(self : Surface, image : Image, size : Size) -> Unit {
  self.get_mut().draw_image(self.sc, image, size)
}

///|
/// Draw a stream (e.g. a pattern tile or an imported form) as a form
/// XObject.
pub fn Surface::draw_stream(self : Surface, stream : Stream) -> Unit {
  self
  .get_mut()
  .draw_xobject(
    self.sc,
    XObject::new(stream, false, false, None),
    ExtGState::new(),
  )
}
