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
