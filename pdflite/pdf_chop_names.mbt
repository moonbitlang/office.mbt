///|
fn pdf_chop_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_chop_cropbox_key_name : @core.PdfName = pdf_chop_name("/CropBox")

///|
fn pdf_chop_cropbox_key() -> @core.PdfName {
  pdf_chop_cropbox_key_name
}

///|
let pdf_chop_bleedbox_key_name : @core.PdfName = pdf_chop_name("/BleedBox")

///|
fn pdf_chop_bleedbox_key() -> @core.PdfName {
  pdf_chop_bleedbox_key_name
}

///|
let pdf_chop_trimbox_key_name : @core.PdfName = pdf_chop_name("/TrimBox")

///|
fn pdf_chop_trimbox_key() -> @core.PdfName {
  pdf_chop_trimbox_key_name
}

///|
let pdf_chop_artbox_key_name : @core.PdfName = pdf_chop_name("/ArtBox")

///|
fn pdf_chop_artbox_key() -> @core.PdfName {
  pdf_chop_artbox_key_name
}

///|
let pdf_chop_annots_key_name : @core.PdfName = pdf_chop_name("/Annots")

///|
fn pdf_chop_annots_key() -> @core.PdfName {
  pdf_chop_annots_key_name
}
