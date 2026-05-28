///|
/// Source-level cpdf draw operation.
///
/// This mirrors the operation shape from `cpdfdraw.ml`. The first rendering
/// slice converts path, graphics-state, colour, matrix, and paint operations to
/// `PdfContentOp`; structure and page-level operations are represented here
/// and will be rendered by later cpdfdraw slices.
pub(all) enum PdfDrawOp {
  PdfDrawRect(Double, Double, Double, Double)
  PdfDrawBezier(Double, Double, Double, Double, Double, Double)
  PdfDrawBezier23(Double, Double, Double, Double)
  PdfDrawBezier13(Double, Double, Double, Double)
  PdfDrawTo(Double, Double)
  PdfDrawLine(Double, Double)
  PdfDrawClosePath
  PdfDrawSetFill(PdfDrawColour)
  PdfDrawSetStroke(PdfDrawColour)
  PdfDrawSetLineThickness(Double)
  PdfDrawSetLineCap(Int)
  PdfDrawSetLineJoin(Int)
  PdfDrawSetMiterLimit(Double)
  PdfDrawSetDashPattern(Array[Double], Double)
  PdfDrawMatrix(TransformMatrix)
  PdfDrawQq(Array[PdfDrawOp])
  PdfDrawFill
  PdfDrawFillEvenOdd
  PdfDrawStroke
  PdfDrawFillStroke
  PdfDrawFillStrokeEvenOdd
  PdfDrawClip
  PdfDrawClipEvenOdd
  PdfDrawFormXObject(Double, Double, Double, Double, String, Array[PdfDrawOp])
  PdfDrawUse(String)
  PdfDrawImageXObject(String, PdfObject)
  PdfDrawImage(String)
  PdfDrawNewPage
  PdfDrawOpacity(Double)
  PdfDrawSOpacity(Double)
  PdfDrawFontPack(String, PdfFontPack, Array[Int])
  PdfDrawFont(String, Double)
  PdfDrawTextSection(Array[PdfDrawOp])
  PdfDrawText(String)
  PdfDrawSpecialText(String)
  PdfDrawPara(Double?, PdfDrawJustification, Double, Array[String])
  PdfDrawNewline
  PdfDrawLeading(Double)
  PdfDrawCharSpace(Double)
  PdfDrawWordSpace(Double)
  PdfDrawTextScale(Double)
  PdfDrawRenderMode(Int)
  PdfDrawRise(Double)
  PdfDrawTag(String)
  PdfDrawEndTag
  PdfDrawSTag(String)
  PdfDrawEndSTag
  PdfDrawBeginArtifact
  PdfDrawEndArtifact
  PdfDrawNamespace(String)
  PdfDrawEltInfo(String, PdfObject)
  PdfDrawEndEltInfo(String)
  PdfDrawAutoTag(Bool)
} derive(Debug, Eq, ToJson)

///|
fn pdf_draw_colour_fill_ops(colour : PdfDrawColour) -> Array[PdfContentOp] {
  match colour {
    PdfDrawNoCol => []
    PdfDrawRGB(r, g, b) => [Op_rg(r, g, b)]
    PdfDrawGrey(g) => [Op_g(g)]
    PdfDrawCYMK(c, m, y, k) => [Op_k(c, m, y, k)]
  }
}

///|
fn pdf_draw_colour_stroke_ops(colour : PdfDrawColour) -> Array[PdfContentOp] {
  match colour {
    PdfDrawNoCol => []
    PdfDrawRGB(r, g, b) => [Op_RG(r, g, b)]
    PdfDrawGrey(g) => [Op_G(g)]
    PdfDrawCYMK(c, m, y, k) => [Op_K(c, m, y, k)]
  }
}

///|
/// Convert a cpdf content colour into the draw colour variant.
pub fn PdfContentColour::to_draw_colour(
  self : PdfContentColour,
) -> PdfDrawColour {
  match self {
    PdfContentGrey(grey) => PdfDrawGrey(grey)
    PdfContentRGB(red, green, blue) => PdfDrawRGB(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      PdfDrawCYMK(cyan, magenta, yellow, black)
  }
}

///|
/// Parse a cpdf draw-control colour argument.
///
/// This ports `cpdfdrawcontrol.ml`'s `parse_colour`/`col_of_string` path while
/// preserving the draw-layer `NoCol` sentinel separately from content colours.
pub fn pdf_parse_draw_colour(text : String) -> PdfDrawColour raise PdfError {
  pdf_parse_content_colour(text).to_draw_colour()
}

///|
/// Parse a cpdf draw colour, returning `PdfDrawNoCol` on malformed input.
pub fn pdf_draw_colour_of_string(text : String) -> PdfDrawColour {
  pdf_parse_draw_colour(text) catch {
    _ => PdfDrawNoCol
  }
}

///|
fn pdf_draw_content_unsupported(
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  raise SoftError("Cpdfdraw: unsupported draw operation " + op.debug_name())
}

///|
fn pdf_draw_form_xobject_stream(
  bbox : (Double, Double, Double, Double),
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> PdfObject raise PdfError {
  let data = pdf_content_bytes_of_ops(ops)
  let (a, b, c, d) = bbox
  pdf_stream(
    PdfDictionary([
      (pdf_draw_length_key(), PdfInteger(data.length())),
      (pdf_draw_subtype_key(), PdfNameObject(pdf_draw_form_key())),
      (pdf_draw_resources_key(), resources),
      (
        pdf_draw_bbox_key(),
        PdfArray([PdfReal(a), PdfReal(b), PdfReal(c), PdfReal(d)]),
      ),
    ]),
    StreamGot(data),
  )
}

///|
fn PdfDrawRenderState::tag_ops(
  self : PdfDrawRenderState,
  tag : String,
) -> Array[PdfContentOp] {
  let mcid = self.fresh_mcid()
  if self.structure_tree_enabled {
    self.structure_data.push(
      PdfDrawStructureMCID("/" + tag, self.structure_page_number, mcid),
    )
  }
  [
    Op_BDC(
      pdf_draw_name("/" + tag),
      PdfDictionary([(pdf_draw_mcid_key(), PdfInteger(mcid))]),
    ),
  ]
}

///|
fn PdfDrawRenderState::structure_tagged_ops(
  self : PdfDrawRenderState,
  tag : String,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let mcid = self.fresh_mcid()
  self.structure_data.push(
    PdfDrawStructureMCID(tag, self.structure_page_number, mcid),
  )
  let output : Array[PdfContentOp] = [
    Op_BDC(
      pdf_draw_name(tag),
      PdfDictionary([(pdf_draw_mcid_key(), PdfInteger(mcid))]),
    ),
  ]
  for op in ops {
    output.push(op)
  }
  output.push(Op_EMC)
  output
}

///|
fn PdfDrawSpecialTextContext::process(
  self : PdfDrawSpecialTextContext,
  text : String,
) -> String {
  pdf_addtext_process_text_with_time(
    self.time,
    text,
    pdf_addtext_replacement_pairs(self.replacement_values),
  )
}

///|
fn PdfDrawOp::to_content_ops_internal(
  self : PdfDrawOp,
  state : PdfDrawRenderState?,
  document : PdfDocument?,
  special_text_context : PdfDrawSpecialTextContext?,
) -> Array[PdfContentOp] raise PdfError {
  match self {
    PdfDrawQq(ops) => {
      let output : Array[PdfContentOp] = [Op_q]
      for op in ops {
        for
          content_op in op.to_content_ops_internal(
            state, document, special_text_context,
          ) {
          output.push(content_op)
        }
      }
      output.push(Op_Q)
      output
    }
    PdfDrawTextSection(ops) => {
      let output : Array[PdfContentOp] = [Op_BT]
      for op in ops {
        for
          content_op in op.to_content_ops_internal(
            state, document, special_text_context,
          ) {
          output.push(content_op)
        }
      }
      output.push(Op_ET)
      output
    }
    PdfDrawSetFill(colour) => pdf_draw_colour_fill_ops(colour)
    PdfDrawSetStroke(colour) => pdf_draw_colour_stroke_ops(colour)
    PdfDrawSetLineThickness(width) => [Op_w(width)]
    PdfDrawSetLineCap(cap) => [Op_J(cap)]
    PdfDrawSetLineJoin(join) => [Op_j(join)]
    PdfDrawSetMiterLimit(limit) => [Op_M(limit)]
    PdfDrawSetDashPattern(dashes, phase) => [Op_d(dashes, phase)]
    PdfDrawMatrix(matrix) => [Op_cm(matrix)]
    PdfDrawRect(x, y, w, h) => [Op_re(x, y, w, h)]
    PdfDrawBezier(x1, y1, x2, y2, x3, y3) => [Op_c(x1, y1, x2, y2, x3, y3)]
    PdfDrawBezier23(x2, y2, x3, y3) => [Op_v(x2, y2, x3, y3)]
    PdfDrawBezier13(x1, y1, x3, y3) => [Op_y(x1, y1, x3, y3)]
    PdfDrawTo(x, y) => [Op_m(x, y)]
    PdfDrawLine(x, y) => [Op_l(x, y)]
    PdfDrawClosePath => [Op_h]
    PdfDrawFill => [Op_f]
    PdfDrawFillEvenOdd => [Op_fstar]
    PdfDrawStroke => [Op_S]
    PdfDrawFillStroke => [Op_B]
    PdfDrawFillStrokeEvenOdd => [Op_Bstar]
    PdfDrawClip => [Op_W, Op_n]
    PdfDrawClipEvenOdd => [Op_Wstar, Op_n]
    PdfDrawFormXObject(a, b, c, d, source_name, ops) =>
      match (state, document) {
        (Some(state), Some(document)) => {
          let form_state = state.nested_form_state()
          let content_ops = pdf_drawops_to_content_ops_internal(
            Some(form_state),
            Some(document),
            special_text_context,
            ops,
          )
          let form_object = pdf_draw_form_xobject_stream(
            (a, b, c, d),
            form_state.resources(),
            content_ops,
          )
          state.adopt_resource_number(form_state)
          let object_number = document.add_object(form_object)
          let _ = state.register_form_xobject(source_name, object_number)
          []
        }
        _ => pdf_draw_content_unsupported(self)
      }
    PdfDrawUse(source_name) =>
      match state {
        Some(state) => [Op_Do(state.form_resource_name(source_name))]
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawImage(source_name) =>
      match state {
        Some(state) => {
          let ops = [Op_Do(state.image_resource_name(source_name))]
          if state.structure_tree_enabled && state.auto_tag {
            state.structure_tagged_ops("/Figure", ops)
          } else {
            ops
          }
        }
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawImageXObject(source_name, object) =>
      match (state, document) {
        (Some(state), Some(document)) => {
          let object_number = document.add_object(object)
          let _ = state.register_xobject(source_name, "/I", object_number)
          []
        }
        _ => pdf_draw_content_unsupported(self)
      }
    PdfDrawFontPack(identifier, fontpack, codepoints) =>
      match (state, document) {
        (Some(state), Some(document)) => {
          ignore(codepoints)
          state.register_fontpack_resources(identifier, fontpack, document)
          []
        }
        _ => pdf_draw_content_unsupported(self)
      }
    PdfDrawFont(identifier, size) =>
      match state {
        Some(state) => {
          state.set_current_font(identifier, size)
          []
        }
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawText(text) =>
      match state {
        Some(state) => {
          let ops = state.text_ops(text)
          if state.structure_tree_enabled && state.auto_tag {
            state.structure_tagged_ops("/P", ops)
          } else {
            ops
          }
        }
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawSpecialText(text) =>
      match (state, special_text_context) {
        (Some(state), Some(context)) => {
          let ops = state.text_ops(context.process(text))
          if state.structure_tree_enabled && state.auto_tag {
            state.structure_tagged_ops("/P", ops)
          } else {
            ops
          }
        }
        _ => pdf_draw_content_unsupported(self)
      }
    PdfDrawPara(indent, justification, width, paragraphs) =>
      match state {
        Some(state) =>
          state.paragraph_ops(indent, justification, width, paragraphs)
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawOpacity(value) =>
      match state {
        Some(state) =>
          [Op_gs(state.extgstate(pdf_draw_fill_alpha_key(), value))]
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawSOpacity(value) =>
      match state {
        Some(state) =>
          [Op_gs(state.extgstate(pdf_draw_stroke_alpha_key(), value))]
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawLeading(leading) => [Op_TL(leading)]
    PdfDrawCharSpace(spacing) => [Op_Tc(spacing)]
    PdfDrawWordSpace(spacing) => [Op_Tw(spacing)]
    PdfDrawTextScale(scale) => [Op_Tz(scale)]
    PdfDrawRenderMode(mode) => [Op_Tr(mode)]
    PdfDrawRise(rise) => [Op_Ts(rise)]
    PdfDrawNewline => [Op_Tstar]
    PdfDrawTag(tag) =>
      match state {
        Some(state) => state.tag_ops(tag)
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawEndTag => [Op_EMC]
    PdfDrawBeginArtifact => [Op_BMC(pdf_draw_begin_artifact())]
    PdfDrawEndArtifact => [Op_BMC(pdf_draw_end_artifact())]
    PdfDrawSTag(name) => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureBeginTree("/" + name))
        _ => ()
      }
      []
    }
    PdfDrawEndSTag => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureEndTree)
        _ => ()
      }
      []
    }
    PdfDrawNamespace(namespace_uri) => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureNamespace(namespace_uri))
        _ => ()
      }
      []
    }
    PdfDrawEltInfo(key, value) => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureElementInfo(key, value))
        _ => ()
      }
      []
    }
    PdfDrawEndEltInfo(key) => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureEndElementInfo(key))
        _ => ()
      }
      []
    }
    PdfDrawAutoTag(value) => {
      match state {
        Some(state) => state.auto_tag = value
        None => ()
      }
      []
    }
    _ => pdf_draw_content_unsupported(self)
  }
}

///|
/// Return the cpdf diagnostic spelling for one draw operation.
pub fn PdfDrawOp::debug_name(self : PdfDrawOp) -> String {
  match self {
    PdfDrawQq(ops) => "Qq (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawFormXObject(_, _, _, _, _, ops) =>
      "FormXObject (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawTextSection(ops) =>
      "TextSection (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawRect(_, _, _, _) => "Rect"
    PdfDrawBezier(_, _, _, _, _, _) => "Bezier"
    PdfDrawBezier23(_, _, _, _) => "Bezier23"
    PdfDrawBezier13(_, _, _, _) => "Bezier13"
    PdfDrawTo(_, _) => "To"
    PdfDrawLine(_, _) => "Line"
    PdfDrawClosePath => "ClosePath"
    PdfDrawSetFill(_) => "SetFill"
    PdfDrawSetStroke(_) => "SetStroke"
    PdfDrawSetLineThickness(_) => "SetLineThickness"
    PdfDrawSetLineCap(_) => "SetLineCap"
    PdfDrawSetLineJoin(_) => "SetLineJoin"
    PdfDrawSetMiterLimit(_) => "SetMiterLimit"
    PdfDrawSetDashPattern(_, _) => "SetDashPattern"
    PdfDrawMatrix(_) => "SetMatrix"
    PdfDrawFill => "Fill"
    PdfDrawFillEvenOdd => "FillEvenOdd"
    PdfDrawStroke => "Stroke"
    PdfDrawFillStroke => "FillStroke"
    PdfDrawFillStrokeEvenOdd => "FillStrokeEvenOdd"
    PdfDrawClip => "Clip"
    PdfDrawClipEvenOdd => "ClipEvenOdd"
    PdfDrawUse(_) => "Use"
    PdfDrawImageXObject(_, _) => "ImageXObject"
    PdfDrawImage(_) => "Image"
    PdfDrawNewPage => "NewPage"
    PdfDrawOpacity(_) => "Opacity"
    PdfDrawSOpacity(_) => "SOpacity"
    PdfDrawFontPack(name, _, _) => "FontPack " + name + " "
    PdfDrawFont(font, _) => "Font " + font + " "
    PdfDrawText(_) => "Text"
    PdfDrawSpecialText(_) => "SpecialText"
    PdfDrawPara(_, _, _, _) => "Para"
    PdfDrawNewline => "Newline"
    PdfDrawLeading(_) => "Leading"
    PdfDrawCharSpace(_) => "CharSpace"
    PdfDrawWordSpace(_) => "WordSpace"
    PdfDrawTextScale(_) => "TextScale"
    PdfDrawRenderMode(_) => "RenderMode"
    PdfDrawRise(_) => "Rise"
    PdfDrawEndTag => "EndTag"
    PdfDrawTag(name) => "Tag " + name
    PdfDrawEndSTag => "EndSTag"
    PdfDrawSTag(name) => "Tag " + name
    PdfDrawBeginArtifact => "BeginArtifact"
    PdfDrawEndArtifact => "EndArtifact"
    PdfDrawNamespace(name) => "Namespace " + name
    PdfDrawEltInfo(_, _) => "EltInfo"
    PdfDrawEndEltInfo(_) => "EndEltInfo"
    PdfDrawAutoTag(_) => "AutoTag"
  }
}

///|
/// Return cpdf's space-prefixed diagnostic string for a list of draw ops.
pub fn pdf_string_of_drawops(ops : ArrayView[PdfDrawOp]) -> String {
  let mut output = ""
  for op in ops {
    output = output + " " + op.debug_name()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDrawOp::debug_name`.
pub fn pdf_string_of_drawop(op : PdfDrawOp) -> String {
  op.debug_name()
}

///|
/// Convert one cpdf draw operation to flat PDF content operators.
///
/// The currently ported rendering subset covers the direct operator mappings in
/// the front of `cpdfdraw.ml`'s `ops_of_drawop`: graphics state, matrix, path,
/// colour, paint, clip, `q`/`Q` grouping, resource-backed XObjects, fontpack
/// text, and paragraph layout. Later slices will fill in tagged-content and
/// page-level rendering.
pub fn PdfDrawOp::to_content_ops(
  self : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(None, None, None)
}

///|
/// Convert one cpdf draw operation using resource allocation state.
pub fn PdfDrawOp::to_content_ops_with_state(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), None, None)
}

///|
/// Convert one cpdf draw operation using resource state and special-text data.
pub fn PdfDrawOp::to_content_ops_with_context(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), None, Some(context))
}

///|
/// Convert one cpdf draw operation using resource state and a document for
/// indirect object allocation.
pub fn PdfDrawOp::to_content_ops_with_document(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  document : PdfDocument,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), Some(document), None)
}

///|
/// Convert one cpdf draw operation using document resources and special-text data.
pub fn PdfDrawOp::to_content_ops_with_document_context(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), Some(document), Some(context))
}

///|
fn pdf_drawops_to_content_ops_internal(
  state : PdfDrawRenderState?,
  document : PdfDocument?,
  context : PdfDrawSpecialTextContext?,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = Array::new(capacity=ops.length())
  for op in ops {
    for content_op in op.to_content_ops_internal(state, document, context) {
      output.push(content_op)
    }
  }
  output
}

///|
/// Convert a sequence of cpdf draw operations to flat PDF content operators.
pub fn pdf_drawops_to_content_ops(
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(None, None, None, ops)
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops`.
pub fn pdf_drawop_to_content_ops(
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops()
}

///|
/// Convert a sequence of cpdf draw operations using resource allocation state.
pub fn pdf_drawops_to_content_ops_with_state(
  state : PdfDrawRenderState,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(Some(state), None, None, ops)
}

///|
/// Convert a sequence of cpdf draw operations using state and special-text data.
pub fn pdf_drawops_to_content_ops_with_context(
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(Some(state), None, Some(context), ops)
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_state`.
pub fn pdf_drawop_to_content_ops_with_state(
  state : PdfDrawRenderState,
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops_with_state(state)
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_context`.
pub fn pdf_drawop_to_content_ops_with_context(
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops_with_context(state, context)
}

///|
/// Convert a sequence of cpdf draw operations using resource state and a
/// document for indirect object allocation.
pub fn pdf_drawops_to_content_ops_with_document(
  state : PdfDrawRenderState,
  document : PdfDocument,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(Some(state), Some(document), None, ops)
}

///|
/// Convert a sequence of cpdf draw operations using document resources and
/// special-text data.
pub fn pdf_drawops_to_content_ops_with_document_context(
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(
    Some(state),
    Some(document),
    Some(context),
    ops,
  )
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_document`.
pub fn pdf_drawop_to_content_ops_with_document(
  state : PdfDrawRenderState,
  document : PdfDocument,
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops_with_document(state, document)
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_document_context`.
pub fn pdf_drawop_to_content_ops_with_document_context(
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops_with_document_context(state, document, context)
}

///|
fn pdf_draw_resource_name_number(name : PdfName) -> Int? {
  let bytes = name.bytes()
  let mut start = bytes.length()
  while start > 0 {
    let byte = bytes[start - 1].to_int()
    if byte >= 48 && byte <= 57 {
      start -= 1
    } else {
      break
    }
  }
  if start == bytes.length() {
    None
  } else {
    let mut value = 0
    for index in start..<bytes.length() {
      value = value * 10 + bytes[index].to_int() - 48
    }
    Some(value)
  }
}

///|
fn PdfDocument::pdf_draw_page_resource_numbers(
  self : PdfDocument,
  resources : PdfObject,
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=3)
  for
    key in [
      pdf_draw_xobject_key(),
      pdf_draw_extgstate_key(),
      pdf_draw_font_key(),
    ] {
    match self.lookup_direct(key, resources) {
      Some(PdfDictionary(entries)) =>
        for entry in entries {
          match pdf_draw_resource_name_number(entry.0) {
            Some(number) => output.push(number)
            None => ()
          }
        }
      _ => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_draw_minimum_resource_number(
  self : PdfDocument,
  selected_pages : @number_set.PdfNumberSet,
) -> Int raise PdfError {
  let pages = self.pages_of_pagetree()
  let mut maximum = -1
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      for number in self.pdf_draw_page_resource_numbers(pages[index].resources) {
        if number > maximum {
          maximum = number
        }
      }
    }
  }
  if maximum < 0 {
    0
  } else {
    maximum + 1
  }
}

///|
fn pdf_draw_contains_special_text(op : PdfDrawOp) -> Bool {
  match op {
    PdfDrawSpecialText(_) => true
    PdfDrawQq(ops)
    | PdfDrawTextSection(ops)
    | PdfDrawFormXObject(_, _, _, _, _, ops) =>
      pdf_drawops_contain_special_text(ops)
    _ => false
  }
}

///|
fn pdf_drawops_contain_special_text(ops : ArrayView[PdfDrawOp]) -> Bool {
  for op in ops {
    if pdf_draw_contains_special_text(op) {
      return true
    }
  }
  false
}

///|
fn pdf_draw_fixup_manual_artifacts(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = Array::new(capacity=ops.length())
  for op in ops {
    match op {
      Op_BMC(name) if name == pdf_draw_begin_artifact() =>
        output.push(pdf_content_begin_artifact())
      Op_BMC(name) if name == pdf_draw_end_artifact() =>
        output.push(pdf_content_end_artifact())
      _ => output.push(op)
    }
  }
  output
}

///|
fn pdf_draw_artifact_ops(
  ops : ArrayView[PdfContentOp],
  add_artifacts : Bool,
) -> Array[PdfContentOp] {
  if add_artifacts {
    pdf_content_add_artifacts(ops)
  } else {
    pdf_draw_fixup_manual_artifacts(ops)
  }
}

///|
fn pdf_draw_double_trailing_new_page(
  drawops : ArrayView[PdfDrawOp],
) -> Array[PdfDrawOp] {
  let output = [ for op in drawops => op ]
  if output.length() > 0 && output[output.length() - 1] == PdfDrawNewPage {
    output.push(PdfDrawNewPage)
  }
  output
}

///|
fn pdf_draw_split_on_new_page(
  drawops : ArrayView[PdfDrawOp],
) -> Array[Array[PdfDrawOp]] {
  let chunks : Array[Array[PdfDrawOp]] = [[]]
  for op in drawops {
    if op == PdfDrawNewPage {
      chunks.push([])
    } else {
      chunks[chunks.length() - 1].push(op)
    }
  }
  if chunks.length() > 1 && chunks[chunks.length() - 1].length() == 0 {
    ignore(chunks.pop())
  }
  chunks
}

///|
fn PdfDocument::pdf_draw_has_fresh_structure_tree(self : PdfDocument) -> Bool {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_structure_root_key(),
      pdf_draw_struct_tree_root_key(),
    ]) {
    Some(PdfDictionary([(key, PdfNameObject(value))])) =>
      key == pdf_draw_type_key() && value == pdf_draw_struct_tree_root_key()
    _ => false
  }
}

///|
fn pdf_draw_single_page_ops(
  document : PdfDocument,
  state : PdfDrawRenderState,
  drawops : ArrayView[PdfDrawOp],
  page_number : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : PdfStrftimeTime?,
) -> Array[PdfContentOp] raise PdfError {
  let context = document.draw_special_text_context(
    page_number,
    filename~,
    bates~,
    bates_pad~,
    time~,
  )
  pdf_drawops_to_content_ops_with_document_context(
    state, document, context, drawops,
  )
}

///|
fn PdfDocument::pdf_draw_render_page_ops(
  self : PdfDocument,
  state : PdfDrawRenderState,
  selected_pages : @number_set.PdfNumberSet,
  drawops : ArrayView[PdfDrawOp],
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : PdfStrftimeTime?,
) -> Array[Array[PdfContentOp]] raise PdfError {
  let pages = self.pages_of_pagetree()
  let per_page : Array[Array[PdfContentOp]] = [ for _ in pages => [] ]
  if pdf_drawops_contain_special_text(drawops) {
    for index in 0..<pages.length() {
      let page_number = index + 1
      if selected_pages.contains(page_number) {
        state.set_structure_page_number(page_number)
        per_page[index] = pdf_draw_single_page_ops(
          self, state, drawops, page_number, filename, bates, bates_pad, time,
        )
      }
    }
  } else {
    let content_ops = pdf_drawops_to_content_ops_with_document(
      state, self, drawops,
    )
    for index in 0..<pages.length() {
      let page_number = index + 1
      if selected_pages.contains(page_number) {
        per_page[index] = content_ops
      }
    }
  }
  per_page
}

///|
fn PdfDocument::pdf_draw_apply_chunk(
  self : PdfDocument,
  state : PdfDrawRenderState,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree : Bool,
  fast : Bool,
  underneath : Bool,
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : PdfStrftimeTime?,
  add_artifacts : Bool,
) -> PdfDocument raise PdfError {
  state.set_structure_tree_enabled(struct_tree)
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  state.set_minimum_resource_number(
    self.pdf_draw_minimum_resource_number(selected_pages),
  )
  let per_page = self.pdf_draw_render_page_ops(
    state, selected_pages, drawops, filename, bates, bates_pad, time,
  )
  let draw_resources = state.resources()
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      let content_ops = pdf_draw_artifact_ops(
        per_page[index],
        add_artifacts || struct_tree,
      )
      let page = {
        ..page,
        resources: self.combine_pdf_resources(page.resources, draw_resources),
      }
      rewritten.push(
        if underneath {
          self.prepend_operators(page, content_ops, fast~)
        } else {
          self.postpend_operators(page, content_ops, fast~)
        },
      )
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
fn pdf_draw_next_range(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> (PdfDocument, Array[Int]) raise PdfError {
  let end_page = document.endpage()
  match page_numbers {
    [page_number] if end_page > page_number => (document, [page_number + 1])
    _ => (document.pad_after([end_page]), [end_page + 1])
  }
}

///|
let pdf_draw_standard_namespace : String = "http://iso.org/pdf/ssn"

///|
priv enum PdfDrawStructureNode {
  PdfDrawStructureNodeMCID(Int)
  PdfDrawStructureNodeItem(PdfDrawStructureItem)
}

///|
priv struct PdfDrawStructureItem {
  kind : String
  namespace_uri : String
  page_object_number : Int?
  alt : Array[(String, PdfObject)]
  children : Array[PdfDrawStructureNode]
}

///|
priv struct PdfDrawStructureBuildContext {
  mut namespace_uri : String
  element_info : Array[(String, PdfObject)]
}

///|
fn pdf_draw_structure_context_new() -> PdfDrawStructureBuildContext {
  { namespace_uri: pdf_draw_standard_namespace, element_info: [] }
}

///|
fn PdfDrawStructureBuildContext::alt_copy(
  self : PdfDrawStructureBuildContext,
) -> Array[(String, PdfObject)] {
  [
    for entry in self.element_info => entry
  ]
}

///|
fn PdfDrawStructureBuildContext::set_element_info(
  self : PdfDrawStructureBuildContext,
  key : String,
  value : PdfObject,
) -> Unit {
  for index in 0..<self.element_info.length() {
    if self.element_info[index].0 == key {
      self.element_info[index] = (key, value)
      return
    }
  }
  self.element_info.push((key, value))
}

///|
fn PdfDrawStructureBuildContext::remove_element_info(
  self : PdfDrawStructureBuildContext,
  key : String,
) -> Unit {
  let output : Array[(String, PdfObject)] = Array::new(
    capacity=self.element_info.length(),
  )
  for entry in self.element_info {
    if entry.0 != key {
      output.push(entry)
    }
  }
  self.element_info.clear()
  for entry in output {
    self.element_info.push(entry)
  }
}

///|
fn pdf_draw_structure_page_object_number(
  page_object_numbers : ArrayView[Int],
  page_number : Int,
) -> Int? {
  if page_number >= 1 && page_number <= page_object_numbers.length() {
    Some(page_object_numbers[page_number - 1])
  } else {
    None
  }
}

///|
fn pdf_draw_make_structure_tree_items(
  data : ArrayView[PdfDrawStructureData],
  index : Ref[Int],
  context : PdfDrawStructureBuildContext,
  page_object_numbers : ArrayView[Int],
  expect_end_tree : Bool,
) -> Array[PdfDrawStructureNode] raise PdfError {
  let output : Array[PdfDrawStructureNode] = Array::new(
    capacity=data.length() - index.val,
  )
  while index.val < data.length() {
    match data[index.val] {
      PdfDrawStructureMCID(kind, page_number, mcid) => {
        output.push(
          PdfDrawStructureNodeItem({
            kind,
            namespace_uri: context.namespace_uri,
            page_object_number: pdf_draw_structure_page_object_number(
              page_object_numbers, page_number,
            ),
            alt: context.alt_copy(),
            children: [PdfDrawStructureNodeMCID(mcid)],
          }),
        )
        index.val += 1
      }
      PdfDrawStructureBeginTree(kind) => {
        let namespace_uri = context.namespace_uri
        let alt = context.alt_copy()
        index.val += 1
        let children = pdf_draw_make_structure_tree_items(
          data, index, context, page_object_numbers, true,
        )
        output.push(
          PdfDrawStructureNodeItem({
            kind,
            namespace_uri,
            page_object_number: None,
            alt,
            children,
          }),
        )
      }
      PdfDrawStructureEndTree =>
        if expect_end_tree {
          index.val += 1
          return output
        } else {
          raise SoftError("Too many -end-tags")
        }
      PdfDrawStructureNamespace(namespace_uri) => {
        context.namespace_uri = namespace_uri
        index.val += 1
      }
      PdfDrawStructureElementInfo(key, value) => {
        context.set_element_info(key, value)
        index.val += 1
      }
      PdfDrawStructureEndElementInfo(key) => {
        context.remove_element_info(key)
        index.val += 1
      }
    }
  }
  if expect_end_tree {
    raise SoftError("not enough -end-stag")
  } else {
    output
  }
}

///|
fn PdfDocument::pdf_draw_make_structure_tree(
  self : PdfDocument,
  data : ArrayView[PdfDrawStructureData],
) -> Array[PdfDrawStructureNode] raise PdfError {
  let index : Ref[Int] = { val: 0 }
  pdf_draw_make_structure_tree_items(
    data,
    index,
    pdf_draw_structure_context_new(),
    self.page_reference_numbers(),
    false,
  )
}

///|
priv struct PdfDrawNamespaceMap {
  entries : Array[(String, Int)]
}

///|
fn pdf_draw_namespace_map_new() -> PdfDrawNamespaceMap {
  { entries: [] }
}

///|
fn PdfDrawNamespaceMap::object_number(
  self : PdfDrawNamespaceMap,
  document : PdfDocument,
  namespace_uri : String,
) -> Int? {
  if namespace_uri == pdf_draw_standard_namespace {
    None
  } else {
    for entry in self.entries {
      if entry.0 == namespace_uri {
        return Some(entry.1)
      }
    }
    let number = document.add_object(
      PdfDictionary([
        (pdf_draw_ns_key(), PdfString(@ascii.encode(namespace_uri))),
      ]),
    )
    self.entries.push((namespace_uri, number))
    Some(number)
  }
}

///|
priv struct PdfDrawParentMap {
  entries : Array[(Int, Array[Int])]
}

///|
fn pdf_draw_parent_map_new() -> PdfDrawParentMap {
  { entries: [] }
}

///|
fn PdfDrawParentMap::add(
  self : PdfDrawParentMap,
  page_object_number : Int,
  structure_object_number : Int,
) -> Unit {
  for index in 0..<self.entries.length() {
    if self.entries[index].0 == page_object_number {
      self.entries[index].1.push(structure_object_number)
      return
    }
  }
  self.entries.push((page_object_number, [structure_object_number]))
}

///|
fn PdfDrawParentMap::number_tree_entries(
  self : PdfDrawParentMap,
) -> Array[(Int, PdfObject)] {
  [
    for entry in self.entries => {
      (
        entry.0,
        PdfArray([ for object_number in entry.1 => PdfIndirect(object_number) ]),
      )
    }
  ]
}

///|
fn PdfDocument::pdf_draw_write_structure_node(
  self : PdfDocument,
  parent_object_number : Int,
  namespaces : PdfDrawNamespaceMap,
  parent_map : PdfDrawParentMap,
  node : PdfDrawStructureNode,
) -> PdfObject raise PdfError {
  match node {
    PdfDrawStructureNodeMCID(mcid) => PdfInteger(mcid)
    PdfDrawStructureNodeItem(item) => {
      let object_number = self.add_object(PdfNull)
      match item.page_object_number {
        Some(page_object_number) =>
          parent_map.add(page_object_number, object_number)
        None => ()
      }
      let entries : Array[(PdfName, PdfObject)] = Array::new(
        capacity=item.alt.length() + 4,
      )
      for entry in item.alt {
        entries.push((pdf_draw_name("/" + entry.0), entry.1))
      }
      match item.page_object_number {
        Some(page_object_number) =>
          entries.push((pdf_draw_pg_key(), PdfIndirect(page_object_number)))
        None => ()
      }
      match namespaces.object_number(self, item.namespace_uri) {
        Some(namespace_object_number) =>
          entries.push(
            (pdf_draw_ns_key(), PdfIndirect(namespace_object_number)),
          )
        None => ()
      }
      entries.push((pdf_draw_s_key(), PdfNameObject(pdf_draw_name(item.kind))))
      entries.push((pdf_draw_p_key(), PdfIndirect(parent_object_number)))
      let children : Array[PdfObject] = Array::new(
        capacity=item.children.length(),
      )
      for child in item.children {
        children.push(
          self.pdf_draw_write_structure_node(
            object_number, namespaces, parent_map, child,
          ),
        )
      }
      entries.push((pdf_draw_k_key(), PdfArray(children)))
      self.add_object_given_number(object_number, PdfDictionary(entries))
      PdfIndirect(object_number)
    }
  }
}

///|
fn PdfDocument::pdf_draw_write_structure_tree(
  self : PdfDocument,
  data : ArrayView[PdfDrawStructureData],
  role_map : String,
) -> Unit raise PdfError {
  let tree = self.pdf_draw_make_structure_tree(data)
  let namespaces = pdf_draw_namespace_map_new()
  let parent_map = pdf_draw_parent_map_new()
  let root_object_number = self.add_object(PdfNull)
  let children : Array[PdfObject] = Array::new(capacity=tree.length())
  for node in tree {
    children.push(
      self.pdf_draw_write_structure_node(
        root_object_number, namespaces, parent_map, node,
      ),
    )
  }
  for entry in parent_map.entries {
    let page_object = self.lookup_object_or_null(entry.0)
    self.add_object_given_number(
      entry.0,
      page_object.add_dict_entry(
        pdf_draw_struct_parents_key(),
        PdfInteger(entry.0),
      ),
    )
  }
  let parent_tree_number = self.add_object(
    self.build_number_tree(parent_map.number_tree_entries()),
  )
  let root_entries : Array[(PdfName, PdfObject)] = [
    (pdf_draw_type_key(), PdfNameObject(pdf_draw_struct_tree_root_key())),
    (pdf_draw_parent_tree_key(), PdfIndirect(parent_tree_number)),
    (pdf_draw_k_key(), PdfArray(children)),
  ]
  if role_map != "" {
    root_entries.push(
      (
        pdf_draw_role_map_key(),
        pdf_parse_object_from_bytes(@ascii.encode("<<" + role_map + ">>")),
      ),
    )
  }
  if namespaces.entries.length() > 0 {
    root_entries.push(
      (
        pdf_draw_namespaces_key(),
        PdfArray([ for entry in namespaces.entries => PdfIndirect(entry.1) ]),
      ),
    )
  }
  self.add_object_given_number(root_object_number, PdfDictionary(root_entries))
  self.replace_chain(
    [pdf_structure_root_key(), pdf_draw_struct_tree_root_key()],
    PdfIndirect(root_object_number),
  )
}

///|
/// Draw cpdf draw operations on selected pages.
///
/// This ports the page orchestration from `cpdfdraw.ml`: draw operations are
/// split around `PdfDrawNewPage`, selected page ranges are advanced or padded
/// between chunks, resources are merged into page resources, manual artifact
/// back-channel markers are fixed before writing content, and `struct_tree`
/// writes a fresh structure tree from rendered MCIDs only when the document has
/// cpdf's fresh `/StructTreeRoot` placeholder. If a real structure tree is
/// already present, or no fresh placeholder exists, requested structure mode
/// artifacts the drawn content instead of replacing the tree. When `role_map`
/// is not empty, it is parsed as the body of a PDF role-map dictionary and
/// attached to the generated `/StructTreeRoot`.
pub fn PdfDocument::draw(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree? : Bool = false,
  fast? : Bool = false,
  underneath? : Bool = false,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  time? : PdfStrftimeTime? = None,
  add_artifacts? : Bool = false,
  role_map? : String = "",
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(page_numbers, self.endpage(), "draw")
  let write_structure_tree = struct_tree &&
    self.pdf_draw_has_fresh_structure_tree()
  let effective_add_artifacts = add_artifacts ||
    (struct_tree && !write_structure_tree)
  let state = pdf_draw_render_state_new()
  state.set_structure_tree_enabled(write_structure_tree)
  let chunks = pdf_draw_split_on_new_page(
    pdf_draw_double_trailing_new_page(drawops),
  )
  let mut document = self
  let mut current_pages = [ for page_number in page_numbers => page_number ]
  for index in 0..<chunks.length() {
    state.reset_for_page_chunk()
    if chunks[index].length() > 0 {
      if current_pages.length() > 0 {
        state.set_structure_page_number(current_pages[0])
      } else {
        state.set_structure_page_number(0)
      }
      document = document.pdf_draw_apply_chunk(
        state,
        current_pages,
        chunks[index],
        write_structure_tree,
        fast,
        underneath,
        filename,
        bates,
        bates_pad,
        time,
        effective_add_artifacts,
      )
    }
    if index + 1 < chunks.length() {
      let next = pdf_draw_next_range(document, current_pages)
      document = next.0
      current_pages = next.1
    }
  }
  if write_structure_tree {
    document.pdf_draw_write_structure_tree(state.structure_data, role_map)
  }
  document
}

///|
/// Compatibility wrapper for `PdfDocument::draw`.
pub fn pdf_draw(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree? : Bool = false,
  fast? : Bool = false,
  underneath? : Bool = false,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  time? : PdfStrftimeTime? = None,
  add_artifacts? : Bool = false,
  role_map? : String = "",
) -> PdfDocument raise PdfError {
  document.draw(
    page_numbers,
    drawops,
    struct_tree~,
    fast~,
    underneath~,
    filename~,
    bates~,
    bates_pad~,
    time~,
    add_artifacts~,
    role_map~,
  )
}
