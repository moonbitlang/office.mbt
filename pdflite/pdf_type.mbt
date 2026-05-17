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

///|
/// Split one byte-encoded text run so at least one word is emitted.
///
/// This follows CamlPDF's `cpdftype.ml` behavior: words are split only on ASCII
/// space, the first word is kept even when it exceeds `space_left`, and a space
/// separator is retained after every non-final word in the emitted prefix.
pub fn pdf_type_split_text(
  space_left : Double,
  widths : ArrayView[Double],
  text : BytesView,
) -> (PdfBytes, Bool, PdfBytes) raise PdfError {
  let output : Array[Byte] = []
  let mut position = 0
  let mut remaining_space = space_left
  while position < text.length() {
    let word_start = position
    while position < text.length() && text[position] != b' ' {
      position += 1
    }
    let word_end = position
    let word = text[word_start:word_end]
    let word_width = pdf_type_width_of_bytes(widths, word)
    if output.length() == 0 || word_width < remaining_space {
      for byte in word {
        output.push(byte)
      }
      if word_end < text.length() {
        output.push(b' ')
        let space_width = pdf_type_width_of_bytes(
          widths,
          pdf_type_ascii(" ")[:],
        )
        remaining_space = remaining_space - word_width - space_width
        position = word_end + 1
      } else {
        remaining_space = remaining_space - word_width
        position = word_end
      }
    } else {
      return (Bytes::from_array(output), true, text[word_start:].to_owned())
    }
  }
  (Bytes::from_array(output), false, text[position:].to_owned())
}

///|
/// Lay out cpdftype elements into wrapped lines for the requested paper width.
///
/// The `rmargin` parameter is accepted for parity with CamlPDF but intentionally
/// ignored: the source computes the maximum x position as `page_width - lmargin`.
pub fn pdf_type_layout(
  lmargin : Double,
  rmargin : Double,
  paper : PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] raise PdfError {
  ignore(rmargin)
  let xpos_max = unit_points(paper.width(), paper.unit()) - lmargin
  let mut xpos = lmargin
  let mut widths : Array[Double] = []
  let output : Array[PdfTypeElement] = []
  for element in elements {
    match element {
      PdfTypeFont(name, font, font_size) => {
        widths = pdf_type_font_widths(font, font_size)
        output.push(PdfTypeFont(name, font, font_size))
      }
      PdfTypeText(text) =>
        if text.length() > 0 {
          let mut current_text = text
          while current_text.length() > 0 {
            let (this_line, needs_newline, rest) = pdf_type_split_text(
              xpos_max - xpos,
              widths,
              current_text,
            )
            output.push(PdfTypeText(this_line))
            xpos = xpos + pdf_type_width_of_bytes(widths, this_line)
            if needs_newline {
              output.push(PdfTypeNewLine)
              xpos = lmargin
            }
            current_text = rest
          }
        }
      PdfTypeHGlue(length) => {
        xpos = xpos + length
        output.push(PdfTypeHGlue(length))
        if xpos >= xpos_max {
          output.push(PdfTypeNewLine)
          xpos = lmargin
        }
      }
      PdfTypeNewLine => {
        xpos = lmargin
        output.push(PdfTypeNewLine)
      }
      other => output.push(other)
    }
  }
  output
}

///|
fn pdf_type_push_page_break(
  output : Array[PdfTypeElement],
  current_tag : (String, Int)?,
) -> Unit {
  match current_tag {
    Some(_) => output.push(PdfTypeEndTag)
    None => ()
  }
  output.push(PdfTypeNewPage)
  match current_tag {
    Some((tag, number)) => output.push(PdfTypeTag(tag, number))
    None => ()
  }
}

///|
/// Insert page breaks into a laid-out cpdftype stream.
///
/// Active structure tags are closed before an inserted `PdfTypeNewPage` and
/// reopened immediately after it, matching CamlPDF's pagination helper.
pub fn pdf_type_paginate(
  tmargin : Double,
  bmargin : Double,
  paper : PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  let max_ypos = unit_points(paper.height(), paper.unit()) - bmargin
  let output : Array[PdfTypeElement] = []
  let mut ypos = tmargin
  let mut font_size = 0.0
  let mut current_tag : (String, Int)? = None
  for element in elements {
    match element {
      PdfTypeVGlue(length) => {
        ypos = ypos + length
        output.push(PdfTypeVGlue(length))
        if ypos > max_ypos {
          ypos = tmargin + font_size
          pdf_type_push_page_break(output, current_tag)
        }
      }
      PdfTypeNewLine => {
        ypos = ypos + font_size * 1.3
        output.push(PdfTypeNewLine)
        if ypos > max_ypos {
          ypos = tmargin + font_size
          pdf_type_push_page_break(output, current_tag)
        }
      }
      PdfTypeFont(name, font, size) => {
        font_size = size
        output.push(PdfTypeFont(name, font, size))
      }
      PdfTypeNewPage => {
        ypos = tmargin + font_size
        pdf_type_push_page_break(output, current_tag)
      }
      PdfTypeBeginDocument => {
        ypos = tmargin + font_size
        output.push(PdfTypeBeginDocument)
      }
      PdfTypeTag(tag, number) => {
        current_tag = Some((tag, number))
        output.push(PdfTypeTag(tag, number))
      }
      PdfTypeEndTag => {
        current_tag = None
        output.push(PdfTypeEndTag)
      }
      other => output.push(other)
    }
  }
  output
}
