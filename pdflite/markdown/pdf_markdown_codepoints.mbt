///|
fn pdf_markdown_last_codepoint(output : Array[Int]) -> Int? {
  if output.length() == 0 {
    None
  } else {
    Some(output[output.length() - 1])
  }
}

///|
fn pdf_markdown_trim_trailing_spaces(output : Array[Int]) -> Unit {
  while output.length() > 0 && output[output.length() - 1] == 0x20 {
    ignore(output.pop())
  }
}

///|
fn pdf_markdown_trim_space_before_terminal_hyphen(output : Array[Int]) -> Unit {
  if output.length() >= 2 &&
    output[output.length() - 1] == 0x2D &&
    output[output.length() - 2] == 0x20 {
    output[output.length() - 2] = 0x2D
    ignore(output.pop())
  }
}

///|
fn pdf_markdown_push_line_break(output : Array[Int]) -> Unit {
  pdf_markdown_trim_trailing_spaces(output)
  pdf_markdown_trim_space_before_terminal_hyphen(output)
  match pdf_markdown_last_codepoint(output) {
    None | Some(0x0A) => ()
    Some(_) => output.push(0x0A)
  }
}

///|
fn pdf_markdown_push_word_space(output : Array[Int]) -> Unit {
  match pdf_markdown_last_codepoint(output) {
    None | Some(0x0A) | Some(0x20) => ()
    Some(_) => output.push(0x20)
  }
}

///|
fn pdf_markdown_tj_adjustment_is_word_space(value : Double) -> Bool {
  value <= -200.0
}

///|
fn pdf_markdown_glyph_has_unreliable_notdef_control(
  glyph : @pdflite.PdfTextGlyph,
) -> Bool {
  if glyph.glyphname == pdf_markdown_notdef_name() {
    for codepoint in glyph.codepoints {
      if pdf_markdown_is_non_text_control(codepoint) {
        break true
      }
    } nobreak {
      false
    }
  } else {
    false
  }
}

///|
fn pdf_markdown_glyph_run_has_unreliable_notdef_control(
  glyphs : ArrayView[@pdflite.PdfTextGlyph],
) -> Bool {
  for glyph in glyphs {
    if pdf_markdown_glyph_has_unreliable_notdef_control(glyph) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_markdown_codepoints_of_glyphs(
  glyphs : ArrayView[@pdflite.PdfTextGlyph],
) -> Array[Int] {
  let output : Array[Int] = []
  if !pdf_markdown_glyph_run_has_unreliable_notdef_control(glyphs) {
    for glyph in glyphs {
      for codepoint in glyph.codepoints {
        output.push(codepoint)
      }
    }
  }
  output
}

///|
fn pdf_markdown_extracted_codepoints(
  extractor : @pdflite.PdfTextExtractor?,
  text : @core.PdfBytes,
) -> Array[Int] raise {
  let output : Array[Int] = []
  match extractor {
    Some(extractor) =>
      for
        codepoint in pdf_markdown_codepoints_of_glyphs(
          extractor.glyphnames_and_codepoints_of_text(text),
        ) {
        output.push(codepoint)
      }
    None => ()
  }
  output
}

///|
fn pdf_markdown_push_extracted_text(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor?,
  text : @core.PdfBytes,
) -> Unit raise {
  pdf_markdown_append_codepoints(
    output,
    pdf_markdown_extracted_codepoints(extractor, text),
  )
}

///|
fn pdf_markdown_append_codepoints(
  output : Array[Int],
  codepoints : ArrayView[Int],
) -> Unit {
  for codepoint in codepoints {
    output.push(codepoint)
  }
}

///|
fn pdf_markdown_is_space(codepoint : Int) -> Bool {
  codepoint == 0x09 || codepoint == 0x0C || codepoint == 0x20
}

///|
fn pdf_markdown_is_non_text_control(codepoint : Int) -> Bool {
  (
    codepoint >= 0 &&
    codepoint < 0x20 &&
    !pdf_markdown_is_space(codepoint) &&
    codepoint != 0x0A &&
    codepoint != 0x0D
  ) ||
  (codepoint >= 0x7F && codepoint <= 0x9F)
}

///|
let pdf_markdown_replacement_codepoint : Int = 0xFFFD

///|
fn pdf_markdown_push_replacement(output : Array[Int]) -> Unit {
  if pdf_markdown_last_codepoint(output) !=
    Some(pdf_markdown_replacement_codepoint) {
    output.push(pdf_markdown_replacement_codepoint)
  }
}

///|
fn pdf_markdown_normalize_codepoints(codepoints : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = []
  let mut pending_space = false
  for codepoint in codepoints {
    match codepoint {
      0x0A | 0x0D => {
        pdf_markdown_push_line_break(output)
        pending_space = false
      }
      _ =>
        if pdf_markdown_is_space(codepoint) {
          if output.length() > 0 {
            pending_space = true
          }
        } else if pdf_markdown_is_non_text_control(codepoint) {
          if pending_space &&
            output.length() > 0 &&
            pdf_markdown_last_codepoint(output) != Some(0x0A) {
            output.push(0x20)
          }
          pdf_markdown_push_replacement(output)
          pending_space = false
        } else {
          if pending_space &&
            output.length() > 0 &&
            pdf_markdown_last_codepoint(output) != Some(0x0A) {
            output.push(0x20)
          }
          output.push(codepoint)
          pending_space = false
        }
    }
  }
  pdf_markdown_trim_trailing_spaces(output)
  while pdf_markdown_last_codepoint(output) == Some(0x0A) {
    ignore(output.pop())
  }
  output
}

///|
fn pdf_markdown_string_of_codepoints(
  codepoints : ArrayView[Int],
) -> String raise {
  let normalized = pdf_markdown_normalize_codepoints(codepoints)
  let bytes = @pdflite.pdf_utf8_of_codepoints(normalized)
  @utf8.decode_lossy(bytes)
}
