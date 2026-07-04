///|
fn pdf_truetype_hmtx_widths(
  data : BytesView,
  hmtx : @truetype.PdfTrueTypeTableRecord,
  count : Int,
) -> Array[Int] raise @core.PdfError {
  let widths : Array[Int] = []
  for index in 0..<count {
    let offset = hmtx.offset + index * 4
    widths.push(pdf_truetype_required_u16(data, offset, "hmtx table"))
  }
  widths
}

///|
fn pdf_truetype_max_pdf_width(
  units_per_em : Int,
  widths : ArrayView[Int],
) -> Int {
  let mut max_width = 0
  for width in widths {
    if width > max_width {
      max_width = width
    }
  }
  pdf_truetype_pdf_unit(units_per_em, max_width)
}

///|
fn pdf_truetype_flags(symbolic : Bool, italic_angle : Int) -> Int {
  let italic = if italic_angle != 0 { 1 } else { 0 }
  let symbolic_bit = if symbolic { 1 } else { 0 }
  let nonsymbolic_bit = if symbolic { 0 } else { 1 }
  (italic << 6) | (symbolic_bit << 2) | (nonsymbolic_bit << 5)
}

///|
/// Return the descriptor metrics read from the TrueType `OS/2` and `post`
/// tables by `Cpdftruetype.parse`.
///
/// The source parser requires `OS/2` for normal embedding, scales its signed
/// metrics to PDF units, reads the high word of the `post` italic-angle fixed
/// value when available, and derives both symbolic and non-symbolic font flags.
pub fn pdf_truetype_descriptor_metrics(
  data : BytesView,
) -> @truetype.PdfTrueTypeDescriptorMetrics raise @core.PdfError {
  let head = pdf_truetype_required_table(data, "head")
  let units_per_em = pdf_truetype_required_u16(
    data,
    head.offset + 18,
    "head table",
  )
  let os2 = match pdf_truetype_table(data, "OS/2") {
    Some(record) => record
    None => raise SoftError("No os/2 table found in truetype font")
  }
  let version = pdf_truetype_required_u16(data, os2.offset, "OS/2 table")
  let avgwidth = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, os2.offset + 2, "OS/2 table"),
  )
  let (ascent, descent) = if os2.length > 68 {
    (
      pdf_truetype_pdf_unit(
        units_per_em,
        pdf_truetype_required_i16(data, os2.offset + 68, "OS/2 table"),
      ),
      pdf_truetype_pdf_unit(
        units_per_em,
        pdf_truetype_required_i16(data, os2.offset + 70, "OS/2 table"),
      ),
    )
  } else {
    (0, 0)
  }
  let (xheight, capheight) = if version < 2 {
    (0, 0)
  } else {
    (
      pdf_truetype_pdf_unit(
        units_per_em,
        pdf_truetype_required_i16(data, os2.offset + 86, "OS/2 table"),
      ),
      pdf_truetype_pdf_unit(
        units_per_em,
        pdf_truetype_required_i16(data, os2.offset + 88, "OS/2 table"),
      ),
    )
  }
  let italicangle = match pdf_truetype_table(data, "post") {
    Some(post) => pdf_truetype_required_u16(data, post.offset + 4, "post table")
    None => 0
  }
  {
    ascent,
    descent,
    capheight,
    xheight,
    avgwidth,
    italicangle,
    nonsymbolic_flags: pdf_truetype_flags(false, italicangle),
    symbolic_flags: pdf_truetype_flags(true, italicangle),
  }
}

///|
/// Return the TrueType metrics needed by `Cpdftruetype.parse`.
///
/// This ports the table reads used before font subsetting proper: `/head`
/// provides units, PDF-unit bounding box, and `indexToLocFormat`; `/maxp`
/// provides `numGlyphs`; optional `/hhea` provides `numOfLongHorMetrics`; and
/// `/hmtx` provides the raw advance widths used for cpdf's width calculations.
pub fn pdf_truetype_metrics(
  data : BytesView,
) -> @truetype.PdfTrueTypeMetrics raise @core.PdfError {
  let head = pdf_truetype_required_table(data, "head")
  let maxp = pdf_truetype_required_table(data, "maxp")
  let hmtx = pdf_truetype_required_table(data, "hmtx")
  let units_per_em = pdf_truetype_required_u16(
    data,
    head.offset + 18,
    "head table",
  )
  let minx = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, head.offset + 36, "head table"),
  )
  let miny = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, head.offset + 38, "head table"),
  )
  let maxx = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, head.offset + 40, "head table"),
  )
  let maxy = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, head.offset + 42, "head table"),
  )
  let index_to_loc_format = pdf_truetype_required_i16(
    data,
    head.offset + 50,
    "head table",
  )
  let num_glyphs = pdf_truetype_required_u16(
    data,
    maxp.offset + 4,
    "maxp table",
  )
  let num_of_long_hor_metrics = match pdf_truetype_table(data, "hhea") {
    Some(hhea) =>
      pdf_truetype_required_u16(data, hhea.offset + 34, "hhea table")
    None => 0
  }
  let advance_widths = pdf_truetype_hmtx_widths(
    data, hmtx, num_of_long_hor_metrics,
  )
  {
    units_per_em,
    minx,
    miny,
    maxx,
    maxy,
    index_to_loc_format,
    num_glyphs,
    num_of_long_hor_metrics,
    advance_widths,
    max_width: pdf_truetype_max_pdf_width(units_per_em, advance_widths),
  }
}
