// Generated from .repos/pdfafmdata.ml and CamlPDF AFM parsing rules.
// This file constitutes a modification of Adobe's AFM data files. This file
// also constitutes a modification of Adobe's license file.
//
// This file and the 14 PostScript(R) AFM files it accompanies may be used,
// copied, and distributed for any purpose and without charge, with or without
// modification, provided that all copyright notices are retained; that the AFM
// files are not distributed without this file; that all modifications to this
// file or any of the AFM files are prominently noted in the modified file(s);
// and that this paragraph is not modified. Adobe Systems has no responsibility
// or obligation to support the use of the AFM files.

///|
fn pdf_standard14_afm_bytes(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_standard14_afm_header(
  key : String,
  value : String,
) -> (PdfBytes, PdfBytes) {
  (pdf_standard14_afm_bytes(key), pdf_standard14_afm_bytes(value))
}
