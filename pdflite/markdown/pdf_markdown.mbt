///|
fn pdf_markdown_name(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_markdown_font_key_name : @pdflite.PdfName = pdf_markdown_name("/Font")

///|
let pdf_markdown_xobject_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/XObject",
)

///|
let pdf_markdown_subtype_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/Subtype",
)

///|
let pdf_markdown_form_name : @pdflite.PdfName = pdf_markdown_name("/Form")

///|
let pdf_markdown_resources_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/Resources",
)

///|
fn pdf_markdown_font_key() -> @pdflite.PdfName {
  pdf_markdown_font_key_name
}

///|
fn pdf_markdown_xobject_key() -> @pdflite.PdfName {
  pdf_markdown_xobject_key_name
}

///|
fn pdf_markdown_subtype_key() -> @pdflite.PdfName {
  pdf_markdown_subtype_key_name
}

///|
fn pdf_markdown_form() -> @pdflite.PdfName {
  pdf_markdown_form_name
}

///|
fn pdf_markdown_resources_key() -> @pdflite.PdfName {
  pdf_markdown_resources_key_name
}

///|
fn pdf_markdown_font_resource_entry(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match document.lookup_direct(pdf_markdown_font_key(), resources) {
    Some(fonts) => fonts.lookup_immediate(font_name)
    None => None
  }
}

///|
fn pdf_markdown_xobject_resource(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  xobject_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match document.lookup_direct(pdf_markdown_xobject_key(), resources) {
    Some(xobjects) => document.lookup_direct(xobject_name, xobjects)
    None => None
  }
}

///|
fn pdf_markdown_is_form_xobject(
  document : @pdflite.PdfDocument,
  xobject : @pdflite.PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_markdown_subtype_key(), xobject) {
    Some(PdfNameObject(name)) => name == pdf_markdown_form()
    _ => false
  }
}

///|
fn pdf_markdown_form_resources(
  document : @pdflite.PdfDocument,
  parent_resources : @pdflite.PdfObject,
  xobject : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  match document.lookup_direct(pdf_markdown_resources_key(), xobject) {
    Some(resources) => resources
    None => parent_resources
  }
}

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
fn pdf_markdown_push_line_break(output : Array[Int]) -> Unit {
  pdf_markdown_trim_trailing_spaces(output)
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
fn pdf_markdown_push_extracted_text(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor?,
  text : @pdflite.PdfBytes,
) -> Unit raise {
  match extractor {
    Some(extractor) =>
      for codepoint in extractor.codepoints_of_text(text[:]) {
        output.push(codepoint)
      }
    None => ()
  }
}

///|
fn pdf_markdown_cached_text_extractor(
  cache : Array[(Int, @pdflite.PdfTextExtractor?)],
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfTextExtractor? raise {
  match pdf_markdown_font_resource_entry(document, resources, font_name) {
    Some(PdfIndirect(number)) =>
      for entry in cache {
        if entry.0 == number {
          break entry.1
        }
      } nobreak {
        let extractor = Some(
          document.text_extractor_of_font(
            document.lookup_object_or_null(number),
          ),
        )
        cache.push((number, extractor))
        extractor
      }
    Some(font) => Some(document.text_extractor_of_font(document.direct(font)))
    None => None
  }
}

///|
let pdf_markdown_max_form_depth : Int = 32

///|
fn pdf_markdown_push_text_codepoints_of_streams(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  streams : ArrayView[@pdflite.PdfObject],
  output : Array[Int],
  font_cache : Array[(Int, @pdflite.PdfTextExtractor?)],
  depth : Int,
) -> Unit raise {
  let mut extractor : @pdflite.PdfTextExtractor? = None
  for op in document.parse_content_ops_with_resources(resources, streams) {
    match op {
      Op_Tf(font_name, _) =>
        extractor = pdf_markdown_cached_text_extractor(
          font_cache, document, resources, font_name,
        )
      Op_Tj(text) => pdf_markdown_push_extracted_text(output, extractor, text)
      Op_TJ(PdfArray(items)) =>
        for item in items {
          match item {
            PdfString(text) =>
              pdf_markdown_push_extracted_text(output, extractor, text)
            PdfReal(value) if pdf_markdown_tj_adjustment_is_word_space(value) =>
              pdf_markdown_push_word_space(output)
            _ => ()
          }
        }
      Op_quote(text) => {
        pdf_markdown_push_line_break(output)
        pdf_markdown_push_extracted_text(output, extractor, text)
      }
      Op_double_quote(_, _, text) => {
        pdf_markdown_push_line_break(output)
        pdf_markdown_push_extracted_text(output, extractor, text)
      }
      Op_Tstar | Op_Td(_, _) | Op_TD(_, _) =>
        pdf_markdown_push_line_break(output)
      Op_Do(name) =>
        if depth < pdf_markdown_max_form_depth {
          match pdf_markdown_xobject_resource(document, resources, name) {
            Some(xobject) =>
              if pdf_markdown_is_form_xobject(document, xobject) {
                let form_resources = pdf_markdown_form_resources(
                  document, resources, xobject,
                )
                pdf_markdown_push_text_codepoints_of_streams(
                  document,
                  form_resources,
                  [xobject],
                  output,
                  font_cache,
                  depth + 1,
                )
              }
            None => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn pdf_markdown_text_codepoints_of_page(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_cache : Array[(Int, @pdflite.PdfTextExtractor?)],
) -> Array[Int] raise {
  let output : Array[Int] = []
  pdf_markdown_push_text_codepoints_of_streams(
    document,
    page.resources,
    page.content[:],
    output,
    font_cache,
    0,
  )
  output
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
  @utf8.decode_lossy(bytes[:])
}

///|
fn pdf_markdown_page_text(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_cache : Array[(Int, @pdflite.PdfTextExtractor?)],
) -> String raise {
  pdf_markdown_string_of_codepoints(
    pdf_markdown_text_codepoints_of_page(document, page, font_cache)[:],
  )
}

///|
fn pdf_markdown_readable_document(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  if document.is_encrypted() {
    match document.decrypt_with_passwords() {
      Some(result) => result.document
      None => fail("encrypted PDF requires a password")
    }
  } else {
    document
  }
}

///|
pub fn pdf_document_to_markdown(
  document : @pdflite.PdfDocument,
) -> String raise {
  let document = pdf_markdown_readable_document(document)
  let pages = document.pages_of_pagetree()
  let output = @buffer.new()
  let font_cache : Array[(Int, @pdflite.PdfTextExtractor?)] = []
  for index in 0..<pages.length() {
    if index > 0 {
      output.write_string("\n\n")
    }
    output.write_string("# Page ")
    output.write_string((index + 1).to_string())
    output.write_string("\n\n")
    output.write_string(
      pdf_markdown_page_text(document, pages[index], font_cache),
    )
  }
  output.write_string("\n")
  output.to_string()
}

///|
pub fn pdf_bytes_to_markdown(data : Bytes) -> String raise {
  pdf_document_to_markdown(@pdflite.pdf_read_document_from_bytes(data))
}
