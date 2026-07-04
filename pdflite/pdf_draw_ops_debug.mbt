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
