///|
fn pdf_id_name() -> PdfName {
  pdf_name_of_bytes(@ascii.encode("/ID"))
}

///|
fn pdf_reproducible_ids_enabled() -> Bool {
  @env.get_env_var("CAMLPDF_REPRODUCIBLE_IDS") == Some("true")
}

///|
fn pdf_id_ocaml_string_of_float(value : Double) -> String {
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
fn pdf_id_seed(path : String, time_text : () -> String) -> String {
  if pdf_reproducible_ids_enabled() {
    "camlpdf"
  } else {
    path + time_text()
  }
}

///|
fn pdf_generate_id_bytes_from_text(
  path : String,
  time_text : () -> String,
) -> PdfBytes {
  let seed = pdf_id_seed(path, time_text)
  pdf_md5_digest(@ascii.encode(seed))
}

///|
fn pdf_generate_current_id_bytes(path : String) -> PdfBytes {
  pdf_generate_id_bytes_from_text(path, fn() { @env.now().to_string() })
}

///|
fn pdf_id_object(digest : PdfBytes) -> PdfObject {
  PdfArray([PdfString(digest), PdfString(digest)])
}

///|
fn pdf_generate_current_id(path : String) -> PdfObject {
  pdf_id_object(pdf_generate_current_id_bytes(path))
}

///|
pub fn pdf_generate_id(path : String, get_time : () -> Double) -> PdfObject {
  let digest = pdf_generate_id_bytes_from_text(path, fn() {
    pdf_id_ocaml_string_of_float(get_time())
  })
  pdf_id_object(digest)
}

///|
pub fn PdfDocument::change_id(
  self : PdfDocument,
  path : String,
  get_time : () -> Double,
) -> Unit raise PdfError {
  match self.trailer_dict() {
    PdfDictionary(_) =>
      self.set_trailer_dict(
        self
        .trailer_dict()
        .add_dict_entry(pdf_id_name(), pdf_generate_id(path, get_time)),
      )
    _ => raise DictionaryExpected
  }
}

///|
fn PdfDocument::copy_with_current_id(
  self : PdfDocument,
  path : String,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  match output.trailer_dict() {
    PdfDictionary(_) => {
      output.set_trailer_dict(
        output
        .trailer_dict()
        .add_dict_entry(pdf_id_name(), pdf_generate_current_id(path)),
      )
      output
    }
    _ => raise DictionaryExpected
  }
}
