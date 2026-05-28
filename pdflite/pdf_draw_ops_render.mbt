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
