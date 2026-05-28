///|
fn pdf_chop_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_chop_cropbox_key_name : PdfName = pdf_chop_name("/CropBox")

///|
fn pdf_chop_cropbox_key() -> PdfName {
  pdf_chop_cropbox_key_name
}

///|
let pdf_chop_bleedbox_key_name : PdfName = pdf_chop_name("/BleedBox")

///|
fn pdf_chop_bleedbox_key() -> PdfName {
  pdf_chop_bleedbox_key_name
}

///|
let pdf_chop_trimbox_key_name : PdfName = pdf_chop_name("/TrimBox")

///|
fn pdf_chop_trimbox_key() -> PdfName {
  pdf_chop_trimbox_key_name
}

///|
let pdf_chop_artbox_key_name : PdfName = pdf_chop_name("/ArtBox")

///|
fn pdf_chop_artbox_key() -> PdfName {
  pdf_chop_artbox_key_name
}

///|
let pdf_chop_annots_key_name : PdfName = pdf_chop_name("/Annots")

///|
fn pdf_chop_annots_key() -> PdfName {
  pdf_chop_annots_key_name
}
