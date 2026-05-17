///|
/// Element stream consumed by the cpdftype layout pipeline.
///
/// `PdfTypeText` stores raw one-byte PDF charcodes, matching the OCaml
/// `char list` representation rather than Unicode text.
pub(all) enum PdfTypeElement {
  PdfTypeText(PdfBytes)
  PdfTypeHGlue(Double)
  PdfTypeVGlue(Double)
  PdfTypeNewLine
  PdfTypeNewPage
  PdfTypeFont(String, PdfFont, Double)
  PdfTypeBeginDest(PdfDestination, String?)
  PdfTypeEndDest
  PdfTypeBeginDocument
  PdfTypeTag(String, Int)
  PdfTypeEndTag
} derive(Debug, Eq, ToJson)

///|
fn pdf_type_ascii(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_type_ocaml_string_of_float(value : Double) -> String {
  if value.is_nan() {
    "nan"
  } else if value.is_pos_inf() {
    "inf"
  } else if value.is_neg_inf() {
    "-inf"
  } else {
    let text = value.to_string()
    if !text.contains(".") && !text.contains("e") && !text.contains("E") {
      text + "."
    } else {
      text
    }
  }
}

///|
/// Render one cpdftype element using the CamlPDF debug spelling.
pub fn pdf_string_of_type_element(element : PdfTypeElement) -> PdfBytes {
  match element {
    PdfTypeText(text) => text
    PdfTypeHGlue(length) =>
      pdf_type_ascii("HGLUE" + pdf_type_ocaml_string_of_float(length))
    PdfTypeVGlue(_) => pdf_type_ascii("VGLUE")
    PdfTypeNewLine => pdf_type_ascii("NewLine")
    PdfTypeNewPage => pdf_type_ascii("NewPage")
    PdfTypeFont(_, _, _) => pdf_type_ascii("Font")
    PdfTypeBeginDest(_, _) => pdf_type_ascii("BeginDest")
    PdfTypeEndDest => pdf_type_ascii("EndDest")
    PdfTypeBeginDocument => pdf_type_ascii("BeginDocument")
    PdfTypeTag(name, number) =>
      pdf_type_ascii("Tag " + name + " " + number.to_string())
    PdfTypeEndTag => pdf_type_ascii("EndTag")
  }
}

///|
/// Render a cpdftype element stream using CamlPDF's leading-newline format.
pub fn pdf_string_of_type(elements : ArrayView[PdfTypeElement]) -> PdfBytes {
  let output : Array[Byte] = []
  for element in elements {
    output.push(10)
    for byte in pdf_string_of_type_element(element) {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
/// Build a cpdftype-style width table for one-byte PDF text charcodes.
///
/// Widths are returned in user units for the requested font size. This ports the
/// standalone `cpdftype.ml` `font_widths` behavior for standard fonts and simple
/// fonts with explicit metrics. CID fonts and simple fonts without metrics raise
/// `PdfError::FontWidthExpected`.
pub fn pdf_type_font_widths(
  font : PdfFont,
  font_size : Double,
) -> Array[Double] raise PdfError {
  match font {
    PdfFontStandard(data) =>
      [
        for code in 0..<256 => {
          let bytes : FixedArray[Byte] = [code.to_byte()]
          font_size *
          data.text_width(Bytes::from_array(bytes)).to_double() /
          1000.0
        }
      ]
    PdfFontSimple(simple) =>
      match simple.fontmetrics {
        Some(metrics) => [ for width in metrics => font_size * width / 1000.0 ]
        None => raise FontWidthExpected
      }
    PdfFontCIDKeyed(_) => raise FontWidthExpected
  }
}

///|
/// Sum a cpdftype width table for byte-encoded text.
///
/// Each input byte is used directly as a charcode index. A width table shorter
/// than the largest charcode raises `PdfError::FontWidthExpected`.
pub fn pdf_type_width_of_bytes(
  widths : ArrayView[Double],
  text : BytesView,
) -> Double raise PdfError {
  let mut width = 0.0
  for byte in text {
    let code = byte.to_int()
    if code >= widths.length() {
      raise FontWidthExpected
    }
    width += widths[code]
  }
  width
}
