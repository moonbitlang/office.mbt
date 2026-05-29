///|
fn pdf_presentation_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_presentation_trans_key_name : PdfName = pdf_presentation_name("/Trans")

///|
fn pdf_presentation_trans_key() -> PdfName {
  pdf_presentation_trans_key_name
}

///|
let pdf_presentation_duration_key_name : PdfName = pdf_presentation_name("/Dur")

///|
fn pdf_presentation_duration_key() -> PdfName {
  pdf_presentation_duration_key_name
}

///|
let pdf_presentation_s_key_name : PdfName = pdf_presentation_name("/S")

///|
fn pdf_presentation_s_key() -> PdfName {
  pdf_presentation_s_key_name
}

///|
let pdf_presentation_d_key_name : PdfName = pdf_presentation_name("/D")

///|
fn pdf_presentation_d_key() -> PdfName {
  pdf_presentation_d_key_name
}

///|
let pdf_presentation_dm_key_name : PdfName = pdf_presentation_name("/Dm")

///|
fn pdf_presentation_dm_key() -> PdfName {
  pdf_presentation_dm_key_name
}

///|
let pdf_presentation_m_key_name : PdfName = pdf_presentation_name("/M")

///|
fn pdf_presentation_m_key() -> PdfName {
  pdf_presentation_m_key_name
}

///|
let pdf_presentation_di_key_name : PdfName = pdf_presentation_name("/Di")

///|
fn pdf_presentation_di_key() -> PdfName {
  pdf_presentation_di_key_name
}

///|
fn pdf_presentation_effect_name(effect : String) -> PdfName raise PdfError {
  match effect {
    "Split" | "Blinds" | "Box" | "Wipe" | "Dissolve" | "Glitter" =>
      pdf_presentation_name("/" + effect)
    _ => raise SoftError("Unknown presentation type")
  }
}

///|
fn pdf_presentation_direction_name(horizontal : Bool) -> PdfName {
  if horizontal {
    pdf_presentation_name("/H")
  } else {
    pdf_presentation_name("/V")
  }
}

///|
fn pdf_presentation_motion_name(inward : Bool) -> PdfName {
  if inward {
    pdf_presentation_name("/I")
  } else {
    pdf_presentation_name("/O")
  }
}

///|
fn PdfPage::change_presentation_effect(
  self : PdfPage,
  transition : String?,
  delay : Double?,
  horizontal : Bool,
  inward : Bool,
  direction : Int,
  effect_duration : Double,
) -> PdfPage raise PdfError {
  let mut transdict = match transition {
    None => PdfDictionary([])
    Some(name) =>
      PdfDictionary([
        (
          pdf_presentation_s_key(),
          PdfNameObject(pdf_presentation_effect_name(name)),
        ),
      ])
  }
  transdict = transdict.add_dict_entry(
    pdf_presentation_d_key(),
    PdfReal(effect_duration),
  )
  match transition {
    Some("Split" | "Blinds") =>
      transdict = transdict.add_dict_entry(
        pdf_presentation_dm_key(),
        PdfNameObject(pdf_presentation_direction_name(horizontal)),
      )
    _ => ()
  }
  match transition {
    Some("Split" | "Box") =>
      transdict = transdict.add_dict_entry(
        pdf_presentation_m_key(),
        PdfNameObject(pdf_presentation_motion_name(inward)),
      )
    _ => ()
  }
  match transition {
    Some("Wipe" | "Glitter") =>
      transdict = transdict.add_dict_entry(
        pdf_presentation_di_key(),
        PdfInteger(direction),
      )
    _ => ()
  }
  let mut rest = self.rest.add_dict_entry(
    pdf_presentation_trans_key(),
    transdict,
  )
  rest = match delay {
    None => rest.remove_dict_entry(pdf_presentation_duration_key())
    Some(value) =>
      rest.add_dict_entry(pdf_presentation_duration_key(), PdfReal(value))
  }
  { ..self, rest, }
}

///|
/// Add presentation transition metadata to the selected 1-based page numbers.
///
/// The accepted transition names match cpdf: `Split`, `Blinds`, `Box`, `Wipe`,
/// `Dissolve`, and `Glitter`. Unknown names raise
/// `PdfError::SoftError("Unknown presentation type")`.
pub fn PdfDocument::presentation(
  self : PdfDocument,
  range : ArrayView[Int],
  transition : String?,
  delay : Double?,
  horizontal : Bool,
  inward : Bool,
  direction : Int,
  effect_duration : Double,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(range)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push(
        page.change_presentation_effect(
          transition, delay, horizontal, inward, direction, effect_duration,
        ),
      )
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::presentation`.
pub fn pdf_presentation(
  range : ArrayView[Int],
  transition : String?,
  delay : Double?,
  horizontal : Bool,
  inward : Bool,
  direction : Int,
  effect_duration : Double,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.presentation(
    range, transition, delay, horizontal, inward, direction, effect_duration,
  )
}
