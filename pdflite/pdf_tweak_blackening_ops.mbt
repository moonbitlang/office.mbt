///|
fn pdf_tweak_black_text_text_op(op : PdfContentOp) -> Bool {
  match op {
    Op_Tj(_)
    | Op_TJ(_)
    | Op_quote(_)
    | Op_double_quote(_, _, _)
    | Op_Td(_, _)
    | Op_TD(_, _)
    | Op_Tm(_)
    | Op_Tstar
    | Op_Tc(_)
    | Op_Tw(_)
    | Op_Tz(_)
    | Op_TL(_)
    | Op_Tf(_, _)
    | Op_Tr(_)
    | Op_Ts(_) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_text_colour_op(op : PdfContentOp) -> Bool {
  match op {
    Op_G(_)
    | Op_g(_)
    | Op_RG(_, _, _)
    | Op_rg(_, _, _)
    | Op_K(_, _, _, _)
    | Op_k(_, _, _, _)
    | Op_SC(_)
    | Op_sc(_)
    | Op_SCN(_)
    | Op_scn(_)
    | Op_SCNName(_, _)
    | Op_scnName(_, _)
    | Op_CS(_)
    | Op_cs(_)
    | Op_sh(_)
    | Op_gs(_) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_stroke_op(op : PdfContentOp) -> Bool {
  match op {
    Op_SC(_)
    | Op_SCN(_)
    | Op_SCNName(_, _)
    | Op_G(_)
    | Op_RG(_, _, _)
    | Op_K(_, _, _, _) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_fill_op(op : PdfContentOp) -> Bool {
  match op {
    Op_sc(_)
    | Op_scn(_)
    | Op_scnName(_, _)
    | Op_g(_)
    | Op_rg(_, _, _)
    | Op_k(_, _, _, _) => true
    _ => false
  }
}

///|
/// Rewrite text content so text is painted with `colour`.
///
/// Colour and graphics-state operators inside text blocks are moved after the
/// text block, while non-text drawing operators inside the text block are
/// copied after `ET`, matching `cpdftweak.ml`'s `blacktext_ops`.
pub fn pdf_black_text_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let removed : Array[PdfContentOp] = []
  let mut text_level = 0
  for op in ops {
    match op {
      Op_BT => {
        text_level += 1
        output.push(op)
        output.push(colour.pdf_tweak_fill_op())
      }
      Op_ET => {
        text_level -= 1
        output.push(op)
        for removed_op in removed {
          output.push(removed_op)
        }
        removed.clear()
      }
      _ =>
        if text_level > 0 && pdf_tweak_black_text_colour_op(op) {
          removed.push(op)
        } else {
          if text_level > 0 && !pdf_tweak_black_text_text_op(op) {
            removed.push(op)
          }
          output.push(op)
        }
    }
  }
  output
}

///|
/// Rewrite stroke colour operators to `colour`.
pub fn pdf_black_lines_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_CS(_) => output.push(Op_CS(pdf_tweak_device_rgb_key()))
      _ if pdf_tweak_black_stroke_op(op) =>
        output.push(colour.pdf_tweak_stroke_op())
      _ => output.push(op)
    }
  }
  output
}

///|
/// Rewrite fill colour operators to `colour`.
pub fn pdf_black_fills_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_cs(_) => output.push(Op_cs(pdf_tweak_device_rgb_key()))
      _ if pdf_tweak_black_fill_op(op) =>
        output.push(colour.pdf_tweak_fill_op())
      _ => output.push(op)
    }
  }
  output
}
