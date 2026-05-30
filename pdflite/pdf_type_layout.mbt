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
  let output = Array::make(text.length(), b'\x00')
  let mut output_position = 0
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
    if output_position == 0 || word_width < remaining_space {
      for byte in word {
        output[output_position] = byte
        output_position += 1
      }
      if word_end < text.length() {
        output[output_position] = b' '
        output_position += 1
        let space_width = pdf_type_width_of_bytes(widths, pdf_type_ascii(" "))
        remaining_space = remaining_space - word_width - space_width
        position = word_end + 1
      } else {
        remaining_space = remaining_space - word_width
        position = word_end
      }
    } else {
      return (
        Bytes::from_array(output[:output_position]),
        true,
        text[word_start:].to_owned(),
      )
    }
  }
  (
    Bytes::from_array(output[:output_position]),
    false,
    text[position:].to_owned(),
  )
}

///|
/// Lay out cpdftype elements into wrapped lines for the requested paper width.
///
/// The `rmargin` parameter is accepted for parity with CamlPDF but intentionally
/// ignored: the source computes the maximum x position as `page_width - lmargin`.
pub fn pdf_type_layout(
  lmargin : Double,
  rmargin : Double,
  paper : @geometry.PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] raise PdfError {
  ignore(rmargin)
  let xpos_max = @geometry.unit_points(paper.width(), paper.unit()) - lmargin
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
  paper : @geometry.PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  let max_ypos = @geometry.unit_points(paper.height(), paper.unit()) - bmargin
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

///|
fn pdf_type_number_tags(
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  let output : Array[PdfTypeElement] = []
  let mut tag_number = 0
  for element in elements {
    match element {
      PdfTypeTag(name, _) => {
        output.push(PdfTypeTag(name, tag_number))
        tag_number += 1
      }
      other => output.push(other)
    }
  }
  output
}
