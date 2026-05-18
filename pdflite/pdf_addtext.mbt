///|
/// Text rotation values used by cpdf's add-text positioning helpers.
pub(all) enum PdfAddTextRotation {
  PdfAddTextRot0
  PdfAddTextRot90
  PdfAddTextRot180
  PdfAddTextRot270
} derive(Debug, Eq, ToJson)

///|
/// Text justification values used by cpdf's add-text positioning helpers.
pub(all) enum PdfAddTextJustification {
  PdfAddTextLeftJustify
  PdfAddTextCentreJustify
  PdfAddTextRightJustify
} derive(Debug, Eq, ToJson)

///|
/// A URL span parsed from cpdf add-text `%URL[text|url]` markup.
///
/// `start` and `end` are byte offsets in the visible output line, matching
/// OCaml cpdf's `String.length` accounting.
pub(all) struct PdfAddTextUrl {
  url : String
  start : Int
  end : Int
} derive(Debug, Eq, ToJson)

///|
/// One add-text line after stripping `%URL[text|url]` markup.
pub(all) struct PdfAddTextUrlLine {
  text : String
  urls : Array[PdfAddTextUrl]
} derive(Debug, Eq, ToJson)

///|
/// Transformed geometry for one add-text URL annotation.
pub(all) struct PdfAddTextUrlAnnotationGeometry {
  p0 : Point2
  p1 : Point2
  p2 : Point2
  p3 : Point2
  rectangle : PdfRectangle
} derive(Debug, Eq, ToJson)

///|
/// Values used to build cpdf add-text replacement callbacks.
pub(all) struct PdfAddTextReplacementValues {
  page_number : Int
  end_page : Int
  filename : String
  page_label : String
  end_label : String
  bates : Int
  bates_pad : Int?
  bookmarks : Array[String]
} derive(Debug, Eq, ToJson)

///|
let pdf_addtext_cpdf_stamp_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/CPDFSTAMP"),
)

///|
let pdf_addtext_extgstate_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/ExtGState"),
)

///|
let pdf_addtext_font_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Font"),
)

///|
let pdf_addtext_annots_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Annots"),
)

///|
let pdf_addtext_ca_key_name : PdfName = pdf_name_of_bytes(@ascii.encode("/ca"))

///|
let pdf_addtext_ca_stroke_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/CA"),
)

///|
fn pdf_addtext_cpdf_stamp() -> PdfName {
  pdf_addtext_cpdf_stamp_name
}

///|
fn pdf_addtext_extgstate_key() -> PdfName {
  pdf_addtext_extgstate_key_name
}

///|
fn pdf_addtext_font_key() -> PdfName {
  pdf_addtext_font_key_name
}

///|
fn pdf_addtext_annots_key() -> PdfName {
  pdf_addtext_annots_key_name
}

///|
fn pdf_addtext_ca_key() -> PdfName {
  pdf_addtext_ca_key_name
}

///|
fn pdf_addtext_ca_stroke_key() -> PdfName {
  pdf_addtext_ca_stroke_key_name
}

///|
fn pdf_addtext_page_selected(
  page_numbers : ArrayView[Int],
  page_number : Int,
) -> Bool {
  for selected in page_numbers {
    if selected == page_number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_addtext_validate_page_numbers(
  page_numbers : ArrayView[Int],
  end_page : Int,
  context : String,
) -> Unit raise PdfError {
  for page_number in page_numbers {
    if page_number < 1 || page_number > end_page {
      raise BadPageSpecification(
        context + ": range contains pages not present in pdf",
      )
    }
  }
}

///|
fn PdfDocument::pdf_addtext_opacity_resources(
  self : PdfDocument,
  resources : PdfObject,
  opacity : Double,
) -> (PdfObject, PdfName?) raise PdfError {
  if opacity < 1.0 {
    let extgstate = match
      self.lookup_direct(pdf_addtext_extgstate_key(), resources) {
      Some(dictionary) => dictionary
      None => PdfDictionary([])
    }
    let name = extgstate.unique_key("gs")
    let opacity_dictionary = PdfDictionary([
      (pdf_addtext_ca_key(), PdfReal(opacity)),
      (pdf_addtext_ca_stroke_key(), PdfReal(opacity)),
    ])
    (
      resources.add_dict_entry(
        pdf_addtext_extgstate_key(),
        extgstate.add_dict_entry(name, opacity_dictionary),
      ),
      Some(name),
    )
  } else {
    (resources, None)
  }
}

///|
/// Build the cpdf add-text fill colour operator.
pub fn pdf_addtext_colour_op(colour : PdfContentColour) -> PdfContentOp {
  colour.pdf_tweak_fill_op()
}

///|
/// Build the cpdf add-text stroke colour operator.
pub fn pdf_addtext_colour_op_stroke(colour : PdfContentColour) -> PdfContentOp {
  colour.pdf_tweak_stroke_op()
}

///|
/// Convert UTF-8 add-text input to PDF charcode bytes for `font`.
///
/// Codepoints not representable by the font are skipped, matching cpdf's
/// `option_map` behavior in `charcodes_of_utf8`.
pub fn pdf_addtext_charcodes_of_utf8(
  font : PdfFont,
  text : String,
) -> PdfBytes raise PdfError {
  let extractor = pdf_charcode_extractor_of_font_real(font)
  let output : Array[Byte] = []
  for codepoint in pdf_codepoints_of_utf8(@utf8.encode(text)) {
    match extractor(codepoint) {
      Some(charcode) => output.push(pdf_byte_of_int(charcode))
      None => ()
    }
  }
  Bytes::from_array(output)
}

///|
/// Measure cpdf add-text charcode bytes with simple-font metrics.
///
/// This mirrors cpdf's narrow `width_of_text` helper: only simple fonts with
/// explicit `fontmetrics` are measured, and any missing metric makes the whole
/// result `0`.
pub fn pdf_addtext_width_of_text(font : PdfFont, text : BytesView) -> Double {
  match font {
    PdfFontSimple({ fontmetrics: Some(metrics), .. }) => {
      let mut width = 0.0
      for byte in text {
        let code = byte.to_int()
        if code >= metrics.length() {
          return 0.0
        }
        width += metrics[code]
      }
      width
    }
    _ => 0.0
  }
}

///|
/// Measure add-text bytes with the selected parsed font at `font_size`.
pub fn pdf_addtext_width_of_selected_font(
  font : PdfFont,
  font_size : Double,
  text : BytesView,
) -> Double {
  let raw_width = match font {
    PdfFontStandard({ font, .. }) =>
      font.text_width(PdfImplicitInFontFile, text).to_double()
    _ => pdf_addtext_width_of_text(font, text)
  }
  raw_width * font_size / 1000.0
}

///|
/// Measure UTF-8 add-text with a cpdf font pack at `font_size`.
pub fn pdf_addtext_width_of_fontpack(
  fontpack : PdfFontPack,
  font_size : Double,
  text : String,
) -> Double raise PdfError {
  let width_tables : Array[Array[Double]] = []
  for font in fontpack.fonts {
    width_tables.push(pdf_type_font_widths(font, font_size))
  }
  let mut width = 0.0
  for codepoint in pdf_codepoints_of_utf8(@utf8.encode(text)) {
    match fontpack.get_char(codepoint) {
      Some((charcode, font_index, _)) => {
        let widths = width_tables[font_index]
        if charcode < 0 || charcode >= widths.length() {
          raise FontWidthExpected
        }
        width += widths[charcode]
      }
      None => ()
    }
  }
  width
}

///|
/// Return the widest add-text line width.
pub fn pdf_addtext_longest_width(
  widths : ArrayView[Double],
) -> Double raise PdfError {
  if widths.length() == 0 {
    raise SoftError("empty add-text width list")
  }
  let mut longest = widths[0]
  for index in 1..<widths.length() {
    if widths[index] > longest {
      longest = widths[index]
    }
  }
  longest
}

///|
/// Build cpdf add-rectangle content operators after placement is resolved.
pub fn pdf_addtext_rectangle_ops(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  colour : PdfContentColour,
  outline : Bool,
  line_width : Double,
  extgstate_name : PdfName?,
) -> Array[PdfContentOp] {
  let ops = [
    pdf_content_begin_artifact(),
    Op_q,
    Op_BMC(pdf_addtext_cpdf_stamp()),
    pdf_addtext_colour_op(colour),
    pdf_addtext_colour_op_stroke(colour),
  ]
  if outline {
    ops.push(Op_w(line_width))
  }
  match extgstate_name {
    Some(name) => ops.push(Op_gs(name))
    None => ()
  }
  ops.push(Op_re(x, y, width, height))
  ops.push(if outline { Op_s } else { Op_f })
  ops.push(Op_EMC)
  ops.push(Op_Q)
  ops.push(pdf_content_end_artifact())
  ops
}

///|
fn pdf_addtext_fontpack_text_ops(
  fontpack : PdfFontPack,
  unique_fontnames : ArrayView[PdfName],
  font_size : Double,
  text : String,
) -> Array[PdfContentOp] raise PdfError {
  let triples : Array[(Int, Int, PdfFont)] = []
  for codepoint in pdf_codepoints_of_utf8(@utf8.encode(text)) {
    match fontpack.get_char(codepoint) {
      Some(triple) => triples.push(triple)
      None => ()
    }
  }
  let ops : Array[PdfContentOp] = []
  for run in pdf_fontpack_collate_runs(triples) {
    guard run.length() > 0 else { continue }
    let font_index = run[0].1
    if font_index < 0 || font_index >= unique_fontnames.length() {
      raise SoftError("bad add-text fontpack font name list")
    }
    let bytes : Array[Byte] = []
    for triple in run {
      bytes.push(pdf_byte_of_int(triple.0))
    }
    ops.push(Op_Tf(unique_fontnames[font_index], font_size))
    ops.push(Op_Tj(Bytes::from_array(bytes)))
  }
  ops
}

///|
fn pdf_addtext_simple_text_ops(
  font : PdfFont?,
  unique_fontname : PdfName,
  font_size : Double,
  text : String,
) -> Array[PdfContentOp] raise PdfError {
  let bytes = match font {
    Some(font) => pdf_addtext_charcodes_of_utf8(font, text)
    None => @utf8.encode(text)
  }
  [Op_Tf(unique_fontname, font_size), Op_Tj(bytes)]
}

///|
fn pdf_addtext_font_text_ops(
  font : PdfFont?,
  fontpack : PdfFontPack?,
  unique_fontname : PdfName,
  unique_fontnames : ArrayView[PdfName],
  font_size : Double,
  text : String,
) -> Array[PdfContentOp] raise PdfError {
  match fontpack {
    Some(fontpack) =>
      pdf_addtext_fontpack_text_ops(fontpack, unique_fontnames, font_size, text)
    None => pdf_addtext_simple_text_ops(font, unique_fontname, font_size, text)
  }
}

///|
fn pdf_addtext_text_matrix(
  x : Double,
  y : Double,
  base_rotation : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  text_rotation : Double,
  rotation_h_offset : Double,
  rotation_v_offset : Double,
) -> TransformMatrix {
  transform_matrix_of_transform([
    Translate(
      x - horizontal_offset + rotation_h_offset,
      y - vertical_offset + rotation_v_offset,
    ),
    Rotate(point2(0.0, 0.0), base_rotation + text_rotation),
  ])
}

///|
/// Build cpdf add-text text-stamp content operators after placement is resolved.
///
/// This ports the source-level `cpdfaddtext.ml` `ops` helper, including
/// `/CPDFSTAMP` artifact wrapping, placement matrix, outline rendering mode,
/// colour operators, optional opacity graphics state, simple-font charcode
/// conversion, and fontpack run switching.
pub fn pdf_addtext_text_ops(
  font : PdfFont?,
  fontpack : PdfFontPack?,
  x : Double,
  y : Double,
  base_rotation : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  outline : Bool,
  line_width : Double,
  unique_fontname : PdfName,
  unique_fontnames : ArrayView[PdfName],
  extgstate_name : PdfName?,
  colour : PdfContentColour,
  font_size : Double,
  text : String,
  text_rotation : Double,
  rotation_h_offset : Double,
  rotation_v_offset : Double,
) -> Array[PdfContentOp] raise PdfError {
  let textops = pdf_addtext_font_text_ops(
    font, fontpack, unique_fontname, unique_fontnames, font_size, text,
  )
  let ops = [
    pdf_content_begin_artifact(),
    Op_q,
    Op_BMC(pdf_addtext_cpdf_stamp()),
    Op_cm(
      pdf_addtext_text_matrix(
        x, y, base_rotation, horizontal_offset, vertical_offset, text_rotation, rotation_h_offset,
        rotation_v_offset,
      ),
    ),
    Op_BT,
  ]
  if outline {
    ops.push(Op_w(line_width))
    ops.push(Op_Tr(1))
  } else {
    ops.push(Op_Tr(0))
  }
  ops.push(pdf_addtext_colour_op(colour))
  ops.push(pdf_addtext_colour_op_stroke(colour))
  match extgstate_name {
    Some(name) => ops.push(Op_gs(name))
    None => ()
  }
  for op in textops {
    ops.push(op)
  }
  ops.push(Op_ET)
  ops.push(Op_EMC)
  ops.push(Op_Q)
  ops.push(pdf_content_end_artifact())
  ops
}

///|
fn pdf_addtext_degrees_to_radians(degrees : Double) -> Double {
  degrees * @math.PI / 180.0
}

///|
/// Convert cpdf add-text's explicit rotation enum to content rotation radians.
pub fn pdf_addtext_rotation_radians(rotation : PdfAddTextRotation) -> Double {
  match rotation {
    PdfAddTextRot0 => 0.0
    PdfAddTextRot90 => pdf_addtext_degrees_to_radians(270.0)
    PdfAddTextRot180 => pdf_addtext_degrees_to_radians(180.0)
    PdfAddTextRot270 => pdf_addtext_degrees_to_radians(90.0)
  }
}

///|
/// Return cpdf's rotation-dependent text origin offset.
pub fn pdf_addtext_rotation_offsets(
  position : PdfPosition,
  rotation : PdfAddTextRotation,
  text_width : Double,
) -> (Double, Double) {
  match position {
    PdfPositionTopLeft(_, _) =>
      match rotation {
        PdfAddTextRot0 | PdfAddTextRot90 => (0.0, 0.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (0.0, -text_width)
      }
    PdfPositionTop(_) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width / 2.0, 0.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width / 2.0, -text_width)
      }
    PdfPositionTopRight(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 | PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width, -text_width)
      }
    PdfPositionRight(_) | PdfPositionPosRight(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width, text_width / 2.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width, -text_width / 2.0)
      }
    PdfPositionBottomRight(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width, text_width)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width, 0.0)
      }
    PdfPositionBottom(_) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width / 2.0, text_width)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width / 2.0, 0.0)
      }
    PdfPositionBottomLeft(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (0.0, text_width)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (0.0, 0.0)
      }
    PdfPositionLeft(_) | PdfPositionPosLeft(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (0.0, text_width / 2.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (0.0, -text_width / 2.0)
      }
    PdfPositionCentre | PdfPositionPosCentre(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width / 2.0, text_width / 2.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width / 2.0, -(text_width / 2.0))
      }
    PdfPositionDiagonal | PdfPositionReverseDiagonal => (0.0, 0.0)
  }
}

///|
/// Adjust cpdf add-text offsets for diagonal and reverse-diagonal placement.
pub fn pdf_addtext_diagonal_offsets(
  bounds : PdfRectangle,
  position : PdfPosition,
  rotation : PdfAddTextRotation,
  text_width : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  base_rotation : Double,
) -> (Double, Double) {
  match position {
    PdfPositionDiagonal | PdfPositionReverseDiagonal => {
      let rotate = if rotation == PdfAddTextRot180 {
        base_rotation + @math.PI
      } else {
        base_rotation
      }
      let horizontal = -(@math.cos(@math.PI / 2.0 - rotate) * vertical_offset)
      let vertical = @math.sin(@math.PI / 2.0 - rotate) * vertical_offset
      if rotation == PdfAddTextRot180 {
        let angle = @math.atan(
          (bounds.max_y - bounds.min_y) / (bounds.max_x - bounds.min_x),
        )
        let dx = @math.cos(angle) * text_width
        let dy = @math.sin(angle) * text_width
        match position {
          PdfPositionDiagonal => (horizontal - dx, vertical - dy)
          PdfPositionReverseDiagonal => (horizontal - dx, vertical + dy)
          _ => (horizontal, vertical)
        }
      } else {
        (horizontal, vertical)
      }
    }
    _ => (horizontal_offset, vertical_offset)
  }
}

///|
/// Return cpdf's initial `(horizontal, vertical)` offset for a multi-line
/// add-text paragraph.
pub fn pdf_addtext_initial_line_offsets(
  position : PdfPosition,
  line_count : Int,
  line_spacing : Double,
  font_size : Double,
) -> (Double, Double) {
  let line_delta = (line_count - 1).to_double()
  let paragraph_height = line_spacing * font_size * line_delta
  let vertical = match position {
    PdfPositionBottomLeft(_, _)
    | PdfPositionBottom(_)
    | PdfPositionBottomRight(_, _) => -paragraph_height
    PdfPositionLeft(_) | PdfPositionRight(_) => -(paragraph_height / 2.0)
    PdfPositionDiagonal | PdfPositionReverseDiagonal =>
      -(paragraph_height / 2.0)
    _ => 0.0
  }
  (0.0, vertical)
}

///|
/// Return cpdf's per-line `(horizontal, vertical)` advance for add-text.
pub fn pdf_addtext_line_advance(
  rotation : PdfAddTextRotation,
  line_spacing : Double,
  font_size : Double,
) -> (Double, Double) {
  let advance = line_spacing * font_size
  match rotation {
    PdfAddTextRot90 | PdfAddTextRot270 => (advance, 0.0)
    PdfAddTextRot0 | PdfAddTextRot180 => (0.0, advance)
  }
}

///|
fn pdf_addtext_rotation_adjustment_offsets(
  rotation : PdfAddTextRotation,
  adjustment : Double,
) -> (Double, Double) {
  match rotation {
    PdfAddTextRot0 => (0.0, adjustment)
    PdfAddTextRot90 => (adjustment, 0.0)
    PdfAddTextRot180 => (0.0, -adjustment)
    PdfAddTextRot270 => (-adjustment, 0.0)
  }
}

///|
/// Return cpdf's `(horizontal, vertical)` baseline shift for midline/topline
/// add-text placement.
pub fn pdf_addtext_baseline_offsets(
  font : PdfFont?,
  font_size : Double,
  position : PdfPosition,
  rotation : PdfAddTextRotation,
  midline : Bool,
  topline : Bool,
) -> (Double, Double) {
  if midline {
    match font {
      Some(PdfFontStandard({ font, .. })) =>
        pdf_addtext_rotation_adjustment_offsets(
          rotation,
          font_size *
          pdf_standard14_baseline_adjustment(font).to_double() /
          1000.0,
        )
      Some(PdfFontSimple({ fontdescriptor: Some(descriptor), .. })) =>
        pdf_addtext_rotation_adjustment_offsets(
          rotation,
          font_size * descriptor.capheight / 2.0 / 1000.0,
        )
      _ => (0.0, 0.0)
    }
  } else if topline {
    match font {
      Some(PdfFontStandard({ font, .. })) => {
        let adjustment = font_size *
          pdf_standard14_baseline_adjustment(font).to_double() *
          2.0 /
          1000.0
        match position {
          PdfPositionDiagonal | PdfPositionReverseDiagonal => (0.0, adjustment)
          _ => pdf_addtext_rotation_adjustment_offsets(rotation, adjustment)
        }
      }
      Some(PdfFontSimple({ fontdescriptor: Some(descriptor), .. })) => {
        let adjustment = font_size * descriptor.capheight / 1000.0
        match position {
          PdfPositionDiagonal | PdfPositionReverseDiagonal => (0.0, adjustment)
          _ => pdf_addtext_rotation_adjustment_offsets(rotation, adjustment)
        }
      }
      _ => (0.0, 0.0)
    }
  } else {
    (0.0, 0.0)
  }
}

///|
/// Return the text encoding cpdf add-text uses for the selected font.
pub fn pdf_addtext_effective_encoding(font : PdfFont?) -> PdfEncoding {
  match font {
    Some(PdfFontStandard({ encoding, .. })) => encoding
    Some(PdfFontSimple({ encoding, .. })) => encoding
    _ => PdfWinAnsiEncoding
  }
}

///|
/// Allocate cpdf add-text font resource names for the selected font and
/// optional font pack.
pub fn pdf_addtext_allocate_font_names(
  fontdict : PdfObject,
  fontpack : PdfFontPack?,
) -> (PdfName, PdfObject, Array[PdfName]) raise PdfError {
  let unique_fontname = fontdict.unique_key("F")
  let mut updated = fontdict
  let unique_fontnames : Array[PdfName] = []
  match fontpack {
    Some(pack) =>
      for _ in pack.fonts {
        let key = updated.unique_key("F")
        updated = updated.add_dict_entry(key, PdfNull)
        unique_fontnames.push(key)
      }
    None => ()
  }
  (unique_fontname, updated, unique_fontnames)
}

///|
/// Replace cpdf add-text fontpack placeholders with embedded font references.
pub fn pdf_addtext_fontpack_resource_dictionary(
  fontdict : PdfObject,
  unique_fontnames : ArrayView[PdfName],
  font_objects : ArrayView[Int],
) -> PdfObject raise PdfError {
  if font_objects.length() != unique_fontnames.length() {
    raise SoftError("bad add-text fontpack resource list")
  }
  let mut updated = fontdict
  for index in 0..<font_objects.length() {
    updated = updated.add_dict_entry(
      unique_fontnames[index],
      PdfIndirect(font_objects[index]),
    )
  }
  updated
}

///|
/// Install one selected add-text font resource into a page resource dictionary.
pub fn pdf_addtext_install_font_resource(
  resources : PdfObject,
  fontdict : PdfObject,
  unique_fontname : PdfName,
  font_object : PdfObject?,
) -> PdfObject raise PdfError {
  match font_object {
    Some(font_object) =>
      resources.add_dict_entry(
        pdf_addtext_font_key(),
        fontdict.add_dict_entry(unique_fontname, font_object),
      )
    None => resources
  }
}

///|
/// Install cpdf add-text fontpack resources into a page resource dictionary.
pub fn pdf_addtext_install_fontpack_resources(
  resources : PdfObject,
  fontdict : PdfObject,
  unique_fontnames : ArrayView[PdfName],
  font_objects : ArrayView[Int],
) -> PdfObject raise PdfError {
  resources.add_dict_entry(
    pdf_addtext_font_key(),
    pdf_addtext_fontpack_resource_dictionary(
      fontdict, unique_fontnames, font_objects,
    ),
  )
}

///|
fn pdf_addtext_font_not_found(fontname : PdfName) -> PdfError {
  SoftError(
    "addtext: font " + @ascii.decode_lossy(fontname.bytes()) + " not found",
  )
}

///|
/// Resolve an existing page font for cpdf add-text.
///
/// The requested name is first treated as a `/Font` resource key. If that is
/// absent, the page font dictionary is scanned for an entry whose `/BaseFont`
/// matches the requested name; the returned `PdfName` is the resource key to
/// use in emitted text operators.
pub fn PdfDocument::addtext_existing_font_resource(
  self : PdfDocument,
  page : PdfPage,
  fontname : PdfName,
) -> (PdfName, PdfObject) raise PdfError {
  let fontdict = match
    self.lookup_direct(pdf_addtext_font_key(), page.resources) {
    Some(fontdict) => fontdict
    None => raise SoftError("addtext: font dictionary not present")
  }
  match self.lookup_direct(fontname, fontdict) {
    Some(font) => (fontname, font)
    None =>
      match fontdict {
        PdfDictionary(entries) =>
          for entry in entries {
            match self.lookup_direct(pdf_text_base_font_key_name, entry.1) {
              Some(PdfNameObject(basefont)) if basefont == fontname =>
                break (entry.0, entry.1)
              _ => ()
            }
          } nobreak {
            raise pdf_addtext_font_not_found(fontname)
          }
        _ => raise pdf_addtext_font_not_found(fontname)
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_existing_font_resource`.
pub fn pdf_addtext_existing_font_resource(
  document : PdfDocument,
  page : PdfPage,
  fontname : PdfName,
) -> (PdfName, PdfObject) raise PdfError {
  document.addtext_existing_font_resource(page, fontname)
}

///|
/// Measure add-text bytes using an existing page font resource.
pub fn PdfDocument::addtext_width_of_existing_font_resource(
  self : PdfDocument,
  page : PdfPage,
  fontname : PdfName,
  font_size : Double,
  text : BytesView,
) -> (PdfName, Double) raise PdfError {
  let (resource_name, font_object) = self.addtext_existing_font_resource(
    page, fontname,
  )
  let font = self.read_font(font_object)
  (resource_name, pdf_addtext_width_of_selected_font(font, font_size, text))
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_width_of_existing_font_resource`.
pub fn pdf_addtext_width_of_existing_font_resource(
  document : PdfDocument,
  page : PdfPage,
  fontname : PdfName,
  font_size : Double,
  text : BytesView,
) -> (PdfName, Double) raise PdfError {
  document.addtext_width_of_existing_font_resource(
    page, fontname, font_size, text,
  )
}

///|
fn pdf_addtext_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
/// Build cpdf's URL link annotation object for add-text markup.
pub fn pdf_addtext_url_annotation(
  p0 : Point2,
  p1 : Point2,
  p2 : Point2,
  p3 : Point2,
  rectangle : PdfRectangle,
  url : String,
  url_border : Bool,
) -> PdfObject {
  PdfDictionary([
    (pdf_addtext_name("/Subtype"), PdfNameObject(pdf_addtext_name("/Link"))),
    (
      pdf_addtext_name("/QuadPoints"),
      PdfArray([
        PdfReal(p0.x),
        PdfReal(p0.y),
        PdfReal(p3.x),
        PdfReal(p3.y),
        PdfReal(p1.x),
        PdfReal(p1.y),
        PdfReal(p2.x),
        PdfReal(p2.y),
      ]),
    ),
    (
      pdf_addtext_name("/Rect"),
      PdfArray([
        PdfReal(rectangle.min_x),
        PdfReal(rectangle.min_y),
        PdfReal(rectangle.max_x),
        PdfReal(rectangle.max_y),
      ]),
    ),
    (
      pdf_addtext_name("/BS"),
      PdfDictionary([
        (pdf_addtext_name("/W"), PdfInteger(if url_border { 1 } else { 0 })),
      ]),
    ),
    (
      pdf_addtext_name("/A"),
      PdfDictionary([
        (pdf_addtext_name("/URI"), PdfString(@utf8.encode(url))),
        (pdf_addtext_name("/Type"), PdfNameObject(pdf_addtext_name("/Action"))),
        (pdf_addtext_name("/S"), PdfNameObject(pdf_addtext_name("/URI"))),
      ]),
    ),
  ])
}

///|
fn pdf_addtext_bounds_of_points(
  p0 : Point2,
  p1 : Point2,
  p2 : Point2,
  p3 : Point2,
) -> PdfRectangle {
  {
    min_x: double_min(double_min(p0.x, p1.x), double_min(p2.x, p3.x)),
    min_y: double_min(double_min(p0.y, p1.y), double_min(p2.y, p3.y)),
    max_x: double_max(double_max(p0.x, p1.x), double_max(p2.x, p3.x)),
    max_y: double_max(double_max(p0.y, p1.y), double_max(p2.y, p3.y)),
  }
}

///|
/// Return cpdf's add-text URL annotation height for a font selection.
pub fn pdf_addtext_url_annotation_height(
  font : PdfFont?,
  fontname : String,
  font_size : Double,
) -> Double {
  match pdf_addtext_cap_height(font, fontname) {
    Some(cap_height) => cap_height * font_size / 1000.0
    None => font_size
  }
}

///|
/// Calculate the transformed quad points and bounds for an add-text URL span.
pub fn pdf_addtext_url_annotation_geometry(
  origin : Point2,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
  rotation : Double,
  rotation_offset : Point2,
  page_rotation : Double,
  start_width : Double,
  end_width : Double,
  height : Double,
) -> PdfAddTextUrlAnnotationGeometry {
  let base_x = origin.x - horizontal_offset - justification_offset
  let base_y = origin.y - vertical_offset
  let min_x = base_x + start_width
  let min_y = base_y
  let max_x = base_x + end_width
  let max_y = base_y + height
  let matrix = transform_matrix_of_transform([
    Translate(rotation_offset.x, rotation_offset.y),
    Rotate(point2(base_x, base_y), rotation + page_rotation),
  ])
  let p0 = matrix.apply(point2(min_x, min_y))
  let p1 = matrix.apply(point2(max_x, max_y))
  let p2 = matrix.apply(point2(min_x, max_y))
  let p3 = matrix.apply(point2(max_x, min_y))
  { p0, p1, p2, p3, rectangle: pdf_addtext_bounds_of_points(p0, p1, p2, p3) }
}

///|
fn pdf_addtext_url_annotation_prefix(
  text : String,
  position : Int,
) -> String raise PdfError {
  let bytes = @utf8.encode(text)
  if position < 0 || position > bytes.length() {
    raise SoftError("bad add-text URL byte offset")
  }
  @utf8.decode(bytes[:position]) catch {
    _ => raise SoftError("bad add-text URL byte offset")
  }
}

///|
fn pdf_addtext_url_annotation_widths_with_measure(
  text : String,
  url : PdfAddTextUrl,
  measure : (String) -> Double raise PdfError,
) -> (Double, Double) raise PdfError {
  (
    measure(pdf_addtext_url_annotation_prefix(text, url.start)),
    measure(pdf_addtext_url_annotation_prefix(text, url.end)),
  )
}

///|
/// Measure cpdf's start and end prefix widths for an add-text URL span.
pub fn pdf_addtext_url_annotation_widths(
  text : String,
  url : PdfAddTextUrl,
  measure : (String) -> Double,
) -> (Double, Double) raise PdfError {
  pdf_addtext_url_annotation_widths_with_measure(text, url, fn(prefix) {
    measure(prefix)
  })
}

///|
/// Build indirect URL link annotations for one cpdf add-text line.
///
/// This mirrors cpdf's add-text annotation pass: each parsed URL span is
/// measured against the visible line, converted to transformed quad points, and
/// written as a new indirect annotation object.
pub fn PdfDocument::addtext_url_annotation_references(
  self : PdfDocument,
  text : String,
  urls : ArrayView[PdfAddTextUrl],
  measure : (String) -> Double raise PdfError,
  origin : Point2,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
  rotation : Double,
  rotation_offset : Point2,
  page_rotation : Double,
  font : PdfFont?,
  fontname : String,
  font_size : Double,
  url_border : Bool,
) -> Array[PdfObject] raise PdfError {
  let height = pdf_addtext_url_annotation_height(font, fontname, font_size)
  let annotations : Array[PdfObject] = []
  for url in urls {
    let (start_width, end_width) = pdf_addtext_url_annotation_widths_with_measure(
      text, url, measure,
    )
    let geometry = pdf_addtext_url_annotation_geometry(
      origin, horizontal_offset, vertical_offset, justification_offset, rotation,
      rotation_offset, page_rotation, start_width, end_width, height,
    )
    let object_number = self.add_object(
      pdf_addtext_url_annotation(
        geometry.p0,
        geometry.p1,
        geometry.p2,
        geometry.p3,
        geometry.rectangle,
        url.url,
        url_border,
      ),
    )
    annotations.push(PdfIndirect(object_number))
  }
  annotations
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_url_annotation_references`.
pub fn pdf_addtext_url_annotation_references(
  document : PdfDocument,
  text : String,
  urls : ArrayView[PdfAddTextUrl],
  measure : (String) -> Double raise PdfError,
  origin : Point2,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
  rotation : Double,
  rotation_offset : Point2,
  page_rotation : Double,
  font : PdfFont?,
  fontname : String,
  font_size : Double,
  url_border : Bool,
) -> Array[PdfObject] raise PdfError {
  document.addtext_url_annotation_references(
    text, urls, measure, origin, horizontal_offset, vertical_offset, justification_offset,
    rotation, rotation_offset, page_rotation, font, fontname, font_size, url_border,
  )
}

///|
/// Return a page rest dictionary with cpdf add-text annotations prepended.
///
/// Empty new annotation lists leave `rest` unchanged. Existing `/Annots`
/// arrays are resolved through `document`; missing or malformed values are
/// treated as empty, matching cpdf's add-text page update.
pub fn PdfDocument::addtext_page_rest_with_annotations(
  self : PdfDocument,
  rest : PdfObject,
  annotations : ArrayView[PdfObject],
) -> PdfObject raise PdfError {
  if annotations.length() == 0 {
    rest
  } else {
    let updated : Array[PdfObject] = [
      for annotation in annotations => annotation
    ]
    match self.lookup_direct(pdf_addtext_annots_key(), rest) {
      Some(PdfArray(existing)) =>
        for annotation in existing {
          updated.push(annotation)
        }
      _ => ()
    }
    rest.add_dict_entry(pdf_addtext_annots_key(), PdfArray(updated))
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_page_rest_with_annotations`.
pub fn pdf_addtext_page_rest_with_annotations(
  document : PdfDocument,
  rest : PdfObject,
  annotations : ArrayView[PdfObject],
) -> PdfObject raise PdfError {
  document.addtext_page_rest_with_annotations(rest, annotations)
}

///|
/// Calculate the cpdf add-rectangle lower-left origin after placement.
pub fn pdf_addtext_rectangle_origin(
  bounds : PdfRectangle,
  position : PdfPosition,
  width : Double,
  height : Double,
) -> (Double, Double) {
  let placed = pdf_calculate_position(false, width, bounds, position)
  let y = match position {
    PdfPositionTop(_) | PdfPositionTopLeft(_, _) | PdfPositionTopRight(_, _) =>
      placed.y - height
    PdfPositionCentre | PdfPositionPosCentre(_, _) => placed.y - height / 2.0
    _ => placed.y
  }
  (placed.x, y)
}

///|
fn PdfDocument::pdf_addtext_rectangle_bounds(
  self : PdfDocument,
  page : PdfPage,
  relative_to_box : PdfName,
) -> PdfRectangle raise PdfError {
  if relative_to_box == pdf_page_mediabox_key() {
    self.parse_rectangle(page.mediabox)
  } else {
    match self.lookup_direct(relative_to_box, page.rest) {
      Some(box_object) => self.parse_rectangle(box_object)
      None => self.parse_rectangle(page.mediabox)
    }
  }
}

///|
fn PdfDocument::pdf_addtext_rectangle_dimensions(
  self : PdfDocument,
  page : PdfPage,
  coord : String,
) -> (Double, Double) raise PdfError {
  match self.parse_units_string(page, coord) {
    [width, height] => (width, height)
    _ => raise SoftError("bad coordinate specification")
  }
}

///|
fn PdfDocument::pdf_addtext_rectangle_page(
  self : PdfDocument,
  page : PdfPage,
  coord : String,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box : PdfName,
  outline : Bool,
  line_width : Double,
  opacity : Double,
  underneath : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
  let (resources, extgstate_name) = self.pdf_addtext_opacity_resources(
    page.resources,
    opacity,
  )
  let bounds = self.pdf_addtext_rectangle_bounds(page, relative_to_box)
  let (width, height) = self.pdf_addtext_rectangle_dimensions(page, coord)
  let (x, y) = pdf_addtext_rectangle_origin(bounds, position, width, height)
  let ops = pdf_addtext_rectangle_ops(
    x, y, width, height, colour, outline, line_width, extgstate_name,
  )
  let page = { ..page, resources, }
  if underneath {
    self.prepend_operators(page, ops, fast~)
  } else {
    self.postpend_operators(page, ops, fast~)
  }
}

///|
/// Add a cpdf-style rectangle stamp to selected one-based pages.
///
/// The rectangle dimensions are parsed with cpdf coordinate syntax, placed
/// relative to `relative_to_box`, wrapped as `/CPDFSTAMP` artifact content, and
/// appended unless `underneath` is set.
pub fn PdfDocument::addtext_rectangle(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  coord : String,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  outline? : Bool = false,
  line_width? : Double = 1.0,
  opacity? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_addtext_validate_page_numbers(
    page_numbers,
    pages.length(),
    "addtext_rectangle",
  )
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_addtext_page_selected(page_numbers, page_number) {
      rewritten.push(
        self.pdf_addtext_rectangle_page(
          page, coord, colour, position, relative_to_box, outline, line_width, opacity,
          underneath, fast,
        ),
      )
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_rectangle`.
pub fn pdf_addtext_rectangle(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  coord : String,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  outline? : Bool = false,
  line_width? : Double = 1.0,
  opacity? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.addtext_rectangle(
    page_numbers,
    coord,
    colour,
    position,
    relative_to_box~,
    outline~,
    line_width~,
    opacity~,
    underneath~,
    fast~,
  )
}

///|
fn pdf_addtext_vertical_justification(
  rotation : PdfAddTextRotation,
  justification : PdfAddTextJustification,
) -> PdfAddTextJustification {
  match justification {
    PdfAddTextCentreJustify => PdfAddTextCentreJustify
    PdfAddTextLeftJustify =>
      if rotation == PdfAddTextRot270 {
        PdfAddTextRightJustify
      } else {
        PdfAddTextLeftJustify
      }
    PdfAddTextRightJustify =>
      if rotation == PdfAddTextRot270 {
        PdfAddTextLeftJustify
      } else {
        PdfAddTextRightJustify
      }
  }
}

///|
fn pdf_addtext_horizontal_justification(
  rotation : PdfAddTextRotation,
  justification : PdfAddTextJustification,
) -> PdfAddTextJustification {
  match justification {
    PdfAddTextCentreJustify => PdfAddTextCentreJustify
    PdfAddTextLeftJustify =>
      if rotation == PdfAddTextRot180 {
        PdfAddTextRightJustify
      } else {
        PdfAddTextLeftJustify
      }
    PdfAddTextRightJustify =>
      if rotation == PdfAddTextRot180 {
        PdfAddTextLeftJustify
      } else {
        PdfAddTextRightJustify
      }
  }
}

///|
fn pdf_addtext_vertical_justification_offset(
  delta : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  match justification {
    PdfAddTextLeftJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta / 2.0
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _) => delta
      }
    PdfAddTextRightJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_) => -delta
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => -(delta / 2.0)
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
      }
    PdfAddTextCentreJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_) => -(delta / 2.0)
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _) => delta / 2.0
      }
  }
}

///|
fn pdf_addtext_horizontal_justification_offset(
  delta : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  match justification {
    PdfAddTextLeftJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre => delta / 2.0
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta
      }
    PdfAddTextRightJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _) => -delta
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre => -(delta / 2.0)
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
      }
    PdfAddTextCentreJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _) => -(delta / 2.0)
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta / 2.0
      }
  }
}

///|
/// Return cpdf's add-text justification offset for the current line.
///
/// `longest_width` is the maximum rendered width among the expanded text lines,
/// and `width` is the current line width.
pub fn pdf_addtext_justification_offset(
  rotation : PdfAddTextRotation,
  longest_width : Double,
  width : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  let delta = longest_width - width
  match rotation {
    PdfAddTextRot90 | PdfAddTextRot270 =>
      pdf_addtext_vertical_justification_offset(
        delta,
        position,
        pdf_addtext_vertical_justification(rotation, justification),
      )
    PdfAddTextRot0 | PdfAddTextRot180 =>
      pdf_addtext_horizontal_justification_offset(
        delta,
        position,
        pdf_addtext_horizontal_justification(rotation, justification),
      )
  }
}

///|
/// Apply cpdf's scalar justification offset to `(horizontal, vertical)`.
pub fn pdf_addtext_apply_justification_offset(
  rotation : PdfAddTextRotation,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
) -> (Double, Double) {
  match rotation {
    PdfAddTextRot90 | PdfAddTextRot270 =>
      (horizontal_offset, vertical_offset - justification_offset)
    PdfAddTextRot0 | PdfAddTextRot180 =>
      (horizontal_offset + justification_offset, vertical_offset)
  }
}

///|
fn pdf_addtext_bytes_match_at(
  bytes : BytesView,
  index : Int,
  pattern : BytesView,
) -> Bool {
  if pattern.length() == 0 || index + pattern.length() > bytes.length() {
    false
  } else {
    for offset in 0..<pattern.length() {
      if bytes[index + offset].to_int() != pattern[offset].to_int() {
        return false
      }
    }
    true
  }
}

///|
fn pdf_addtext_replace_all_lazy(
  text : String,
  search : String,
  replacement : () -> String,
) -> String {
  let search_bytes = @utf8.encode(search)
  if search_bytes.length() == 0 {
    text
  } else {
    let text_bytes = @utf8.encode(text)
    let output : Array[Byte] = []
    let mut index = 0
    while index < text_bytes.length() {
      if pdf_addtext_bytes_match_at(text_bytes, index, search_bytes) {
        for byte in @utf8.encode(replacement()) {
          output.push(byte)
        }
        index += search_bytes.length()
      } else {
        output.push(text_bytes[index])
        index += 1
      }
    }
    @utf8.decode_lossy(Bytes::from_array(output))
  }
}

///|
/// Apply cpdf add-text replacements, then run the cpdf strftime pass.
///
/// Replacement callbacks are only evaluated for markers that occur in `text`,
/// matching cpdf's `string_replace_all_lazy` helper.
pub fn pdf_addtext_process_text_with_time(
  time : PdfStrftimeTime,
  text : String,
  replacements : ArrayView[(String, () -> String)],
) -> String {
  let mut output = text
  for replacement in replacements {
    output = pdf_addtext_replace_all_lazy(output, replacement.0, replacement.1)
  }
  pdf_strftime_with_time(time, output)
}

///|
fn pdf_addtext_decode_lossy(bytes : Array[Byte]) -> String {
  @utf8.decode_lossy(Bytes::from_array(bytes))
}

///|
/// Split add-text input at cpdf's literal `\n` line marker.
///
/// A doubled backslash before `n` is preserved as text, matching cpdf's
/// `split_at_newline` helper.
pub fn pdf_addtext_split_at_newline(text : String) -> Array[String] {
  let bytes = @utf8.encode(text)
  let lines : Array[String] = []
  let mut current : Array[Byte] = []
  let mut index = 0
  while index < bytes.length() {
    if index + 2 < bytes.length() &&
      bytes[index].to_int() == 92 &&
      bytes[index + 1].to_int() == 92 &&
      bytes[index + 2].to_int() == 110 {
      current.push(bytes[index])
      current.push(bytes[index + 1])
      current.push(bytes[index + 2])
      index += 3
    } else if index + 1 < bytes.length() &&
      bytes[index].to_int() == 92 &&
      bytes[index + 1].to_int() == 110 {
      lines.push(pdf_addtext_decode_lossy(current))
      current = []
      index += 2
    } else {
      current.push(bytes[index])
      index += 1
    }
  }
  lines.push(pdf_addtext_decode_lossy(current))
  lines
}

///|
fn pdf_addtext_is_octal_digit(byte : Byte) -> Bool {
  let value = byte.to_int()
  value >= 48 && value <= 55
}

///|
fn pdf_addtext_octal_value(a : Byte, b : Byte, c : Byte) -> Int {
  (a.to_int() - 48) * 64 + (b.to_int() - 48) * 8 + c.to_int() - 48
}

///|
/// Decode cpdf add-text backslash escapes after line splitting.
///
/// Three-digit octal escapes emit one byte, doubled backslashes emit one
/// backslash, and other non-newline escapes drop the backslash.
pub fn pdf_addtext_unescape_string(text : String) -> String raise PdfError {
  let bytes = @utf8.encode(text)
  let output : Array[Byte] = []
  let mut index = 0
  while index < bytes.length() {
    if bytes[index].to_int() == 92 {
      if index + 3 < bytes.length() &&
        pdf_addtext_is_octal_digit(bytes[index + 1]) &&
        pdf_addtext_is_octal_digit(bytes[index + 2]) &&
        pdf_addtext_is_octal_digit(bytes[index + 3]) {
        let value = pdf_addtext_octal_value(
          bytes[index + 1],
          bytes[index + 2],
          bytes[index + 3],
        )
        if value > 255 {
          raise SoftError("bad add-text octal escape")
        }
        output.push(value.to_byte())
        index += 4
      } else if index + 1 < bytes.length() && bytes[index + 1].to_int() == 92 {
        output.push((92).to_byte())
        index += 2
      } else if index + 1 < bytes.length() && bytes[index + 1].to_int() != 110 {
        output.push(bytes[index + 1])
        index += 2
      } else {
        output.push(bytes[index])
        index += 1
      }
    } else {
      output.push(bytes[index])
      index += 1
    }
  }
  pdf_addtext_decode_lossy(output)
}

///|
/// Split and unescape add-text lines, reversing them for upside-down rotations.
pub fn pdf_addtext_lines_for_rotation(
  text : String,
  rotation : PdfAddTextRotation,
) -> Array[String] raise PdfError {
  let lines = pdf_addtext_split_at_newline(text).map(line => {
    pdf_addtext_unescape_string(line)
  })
  match rotation {
    PdfAddTextRot180 | PdfAddTextRot270 => lines.rev()
    PdfAddTextRot0 | PdfAddTextRot90 => lines
  }
}

///|
fn pdf_addtext_roman_upper(number : Int) -> String {
  @ascii.decode_lossy(pdf_page_label_roman_upper(number))
}

///|
fn pdf_addtext_roman_lower(number : Int) -> String {
  @ascii.decode_lossy(
    pdf_page_label_lowercase(pdf_page_label_roman_upper(number)),
  )
}

///|
/// Format cpdf add-text's `%Bates` replacement for one page.
pub fn pdf_addtext_bates_number(
  bates : Int,
  page_number : Int,
  bates_pad : Int?,
) -> String {
  let number_text = (bates + page_number - 1).to_string()
  match bates_pad {
    None => number_text
    Some(width) =>
      if number_text.length() >= width {
        number_text
      } else {
        let mut output = number_text
        for _ in 0..<(width - number_text.length()) {
          output = "0" + output
        }
        output
      }
  }
}

///|
fn pdf_addtext_bookmark_replacement(
  values : PdfAddTextReplacementValues,
  level : Int,
) -> String {
  if level >= 0 && level < values.bookmarks.length() {
    values.bookmarks[level]
  } else {
    ""
  }
}

///|
/// Build cpdf add-text replacement callbacks for page-local fields.
///
/// Page labels and bookmark strings are supplied by the caller; this helper
/// preserves cpdf's marker names and Bates/roman/page-number formatting.
pub fn pdf_addtext_replacement_pairs(
  values : PdfAddTextReplacementValues,
) -> Array[(String, () -> String)] {
  [
    ("%PageDiv2", fn() { ((values.page_number + 1) / 2).to_string() }),
    ("%Page", fn() { values.page_number.to_string() }),
    ("%Roman", fn() { pdf_addtext_roman_upper(values.page_number) }),
    ("%roman", fn() { pdf_addtext_roman_lower(values.page_number) }),
    ("%filename", fn() { values.filename }),
    ("%Label", fn() { values.page_label }),
    ("%EndPage", fn() { values.end_page.to_string() }),
    ("%EndLabel", fn() { values.end_label }),
    ("%Bookmark0", fn() { pdf_addtext_bookmark_replacement(values, 0) }),
    ("%Bookmark1", fn() { pdf_addtext_bookmark_replacement(values, 1) }),
    ("%Bookmark2", fn() { pdf_addtext_bookmark_replacement(values, 2) }),
    ("%Bookmark3", fn() { pdf_addtext_bookmark_replacement(values, 3) }),
    ("%Bookmark4", fn() { pdf_addtext_bookmark_replacement(values, 4) }),
    (
      "%Bates",
      fn() {
        pdf_addtext_bates_number(
          values.bates,
          values.page_number,
          values.bates_pad,
        )
      },
    ),
  ]
}

///|
fn pdf_addtext_pdfdocstring_to_string(
  bytes : BytesView,
) -> String raise PdfError {
  @utf8.decode(pdf_utf8_of_pdfdocstring(bytes)) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_addtext_page_label_prefix(label : PdfPageLabel) -> String raise PdfError {
  match label.label_prefix {
    Some(prefix) => pdf_addtext_pdfdocstring_to_string(prefix)
    None => ""
  }
}

///|
fn pdf_addtext_page_label_number(label : PdfPageLabel) -> String {
  @ascii.decode_lossy(
    pdf_page_label_number_bytes(label.start_value, label.label_style),
  )
}

///|
/// Return cpdf add-text's visible page label for a 1-based page number.
///
/// Documents without page labels fall back to decimal page numbers.
pub fn PdfDocument::addtext_page_label(
  self : PdfDocument,
  page_number : Int,
) -> String raise PdfError {
  let labels = pdf_page_label_complete(self.read_page_labels())
  match pdf_page_label_of_page_number(page_number, labels) {
    Some(label) =>
      pdf_addtext_page_label_prefix(label) +
      pdf_addtext_page_label_number(label)
    None => page_number.to_string()
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_page_label`.
pub fn pdf_addtext_page_label(
  document : PdfDocument,
  page_number : Int,
) -> String raise PdfError {
  document.addtext_page_label(page_number)
}

///|
fn pdf_addtext_bookmark_text(bookmark : PdfBookmark) -> String raise PdfError {
  pdf_addtext_pdfdocstring_to_string(bookmark.text)
}

///|
/// Return cpdf add-text's current bookmark text at `level` for `page_number`.
///
/// The search is constrained to the current bookmark branch so section
/// bookmarks from a previous chapter do not leak into a later chapter.
pub fn PdfDocument::addtext_bookmark_for_page(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  level : Int,
  page_number : Int,
) -> String raise PdfError {
  let before : Array[PdfBookmark] = []
  for bookmark in bookmarks {
    if self.page_number_of_target(bookmark.target) <= page_number {
      before.push(bookmark)
    } else {
      break
    }
  }
  let branch : Array[PdfBookmark] = []
  let mut before_index = before.length()
  while before_index > 0 {
    before_index -= 1
    let bookmark = before[before_index]
    if bookmark.level >= level {
      branch.push(bookmark)
    } else {
      break
    }
  }
  let pickfrom : Array[PdfBookmark] = []
  let mut branch_index = branch.length()
  while branch_index > 0 {
    branch_index -= 1
    let bookmark = branch[branch_index]
    if bookmark.level == level {
      pickfrom.push(bookmark)
    }
  }
  let mut fallback : PdfBookmark? = None
  for bookmark in pickfrom {
    if self.page_number_of_target(bookmark.target) == page_number {
      return pdf_addtext_bookmark_text(bookmark)
    }
    fallback = Some(bookmark)
  }
  match fallback {
    Some(bookmark) => pdf_addtext_bookmark_text(bookmark)
    None => ""
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_bookmark_for_page`.
pub fn pdf_addtext_bookmark_for_page(
  document : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  level : Int,
  page_number : Int,
) -> String raise PdfError {
  document.addtext_bookmark_for_page(bookmarks, level, page_number)
}

///|
/// Build cpdf add-text replacement values from document-local state.
pub fn PdfDocument::addtext_replacement_values(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  page_number : Int,
  end_page : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
) -> PdfAddTextReplacementValues raise PdfError {
  let bookmark_values : Array[String] = []
  for level in 0..<5 {
    bookmark_values.push(
      self.addtext_bookmark_for_page(bookmarks, level, page_number),
    )
  }
  {
    page_number,
    end_page,
    filename,
    page_label: self.addtext_page_label(page_number),
    end_label: self.addtext_page_label(end_page),
    bates,
    bates_pad,
    bookmarks: bookmark_values,
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_replacement_values`.
pub fn pdf_addtext_replacement_values(
  document : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  page_number : Int,
  end_page : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
) -> PdfAddTextReplacementValues raise PdfError {
  document.addtext_replacement_values(
    bookmarks, page_number, end_page, filename, bates, bates_pad,
  )
}

///|
fn pdf_addtext_afm_header_value(data : PdfAfmData, key : String) -> String? {
  let key_bytes = @ascii.encode(key)
  for entry in data.headers {
    if pdf_afm_view_equals(entry.0, key_bytes) {
      return Some(@ascii.decode_lossy(entry.1))
    }
  }
  None
}

///|
fn pdf_addtext_parse_double(text : String) -> Double? {
  let parsed : Result[Double, Error] = try? @strconv.from_str(text)
  match parsed {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn pdf_addtext_standard_cap_height(fontname : String) -> Double? {
  match pdf_standard_font_of_name("/" + fontname) {
    Some(font) => {
      let data = font.afm_data()
      match pdf_addtext_afm_header_value(data, "CapHeight") {
        Some(value) =>
          match pdf_addtext_parse_double(value) {
            Some(parsed) => Some(parsed)
            None => Some(0.0)
          }
        None => Some(0.0)
      }
    }
    None => None
  }
}

///|
/// Return the cap height used by cpdf add-text URL link rectangles.
///
/// Explicit simple-font descriptors win. Otherwise `fontname` is resolved as a
/// Standard 14 font name without a leading slash, matching cpdf's fallback.
pub fn pdf_addtext_cap_height(font : PdfFont?, fontname : String) -> Double? {
  match font {
    Some(PdfFontSimple({ fontdescriptor: Some(descriptor), .. })) =>
      Some(descriptor.capheight)
    _ => pdf_addtext_standard_cap_height(fontname)
  }
}

///|
fn pdf_addtext_find_byte(bytes : BytesView, start : Int, value : Int) -> Int? {
  let mut index = start
  while index < bytes.length() {
    if bytes[index].to_int() == value {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn pdf_addtext_require_byte(
  bytes : BytesView,
  start : Int,
  value : Int,
) -> Int raise PdfError {
  match pdf_addtext_find_byte(bytes, start, value) {
    Some(index) => index
    None => raise SoftError("bad URL syntax in text")
  }
}

///|
fn pdf_addtext_is_url_marker(bytes : BytesView, index : Int) -> Bool {
  index + 4 < bytes.length() &&
  bytes[index].to_int() == 37 &&
  bytes[index + 1].to_int() == 85 &&
  bytes[index + 2].to_int() == 82 &&
  bytes[index + 3].to_int() == 76 &&
  bytes[index + 4].to_int() == 91
}

///|
fn pdf_addtext_utf8_string(bytes : BytesView) -> String raise PdfError {
  @utf8.decode(bytes) catch {
    _ => raise InvalidUTF8
  }
}

///|
/// Strip cpdf add-text `%URL[text|url]` markup from one line.
///
/// The returned URL spans use byte offsets in the stripped visible text, as in
/// cpdf's `get_urls_line` helper.
pub fn pdf_addtext_get_urls_line(
  line : String,
) -> PdfAddTextUrlLine raise PdfError {
  let bytes = @utf8.encode(line)
  let output : Array[Byte] = []
  let urls : Array[PdfAddTextUrl] = []
  let mut index = 0
  let mut position = 0
  while index < bytes.length() {
    if pdf_addtext_is_url_marker(bytes, index) {
      let text_start = index + 5
      let pipe = pdf_addtext_require_byte(bytes, text_start, 124)
      let close = pdf_addtext_require_byte(bytes, pipe + 1, 93)
      for byte in bytes[text_start:pipe] {
        output.push(byte)
      }
      let url = pdf_addtext_utf8_string(bytes[pipe + 1:close])
      let start = position
      let end = position + pipe - text_start
      urls.push({ url, start, end })
      position = end
      index = close + 1
    } else {
      output.push(bytes[index])
      position += 1
      index += 1
    }
  }
  { text: pdf_addtext_utf8_string(Bytes::from_array(output)), urls }
}

///|
/// Expand add-text lines and strip URL markup before line measurement.
///
/// This mirrors cpdf's `expand_lines` behavior after callers have supplied the
/// document-specific replacement callbacks.
pub fn pdf_addtext_expand_lines_with_time(
  time : PdfStrftimeTime,
  lines : ArrayView[String],
  replacements : ArrayView[(String, () -> String)],
) -> Array[String] raise PdfError {
  let output : Array[String] = []
  for line in lines {
    let processed = pdf_addtext_process_text_with_time(time, line, replacements)
    output.push(pdf_addtext_get_urls_line(processed).text)
  }
  output
}

///|
fn pdf_addtext_codepoints_contains(
  codepoints : ArrayView[Int],
  codepoint : Int,
) -> Bool {
  for existing in codepoints {
    if existing == codepoint {
      return true
    }
  }
  false
}

///|
/// Return the unique Unicode codepoints used by expanded add-text lines.
///
/// This mirrors cpdf's pre-embedding `used` scan after replacement expansion
/// and URL stripping. The returned order is first occurrence for deterministic
/// callers and tests.
pub fn pdf_addtext_used_codepoints(
  lines : ArrayView[String],
) -> Array[Int] raise PdfError {
  let used : Array[Int] = []
  for line in lines {
    for codepoint in pdf_codepoints_of_utf8(@utf8.encode(line)) {
      if !pdf_addtext_codepoints_contains(used, codepoint) {
        used.push(codepoint)
      }
    }
  }
  used
}
