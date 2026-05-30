// Generated from CamlPDF pdfafmdata.ml and AFM parsing rules.
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
fn pdf_standard14_afm_data_of_font(font : PdfStandardFont) -> PdfAfmData {
  match font {
    PdfCourier => pdf_standard14_courier_afm_data()
    PdfCourierOblique => pdf_standard14_courier_oblique_afm_data()
    PdfCourierBold => pdf_standard14_courier_bold_afm_data()
    PdfCourierBoldOblique => pdf_standard14_courier_bold_oblique_afm_data()
    PdfTimesRoman => pdf_standard14_times_roman_afm_data()
    PdfTimesBold => pdf_standard14_times_bold_afm_data()
    PdfTimesItalic => pdf_standard14_times_italic_afm_data()
    PdfTimesBoldItalic => pdf_standard14_times_bold_italic_afm_data()
    PdfHelvetica => pdf_standard14_helvetica_afm_data()
    PdfHelveticaBold => pdf_standard14_helvetica_bold_afm_data()
    PdfHelveticaOblique => pdf_standard14_helvetica_oblique_afm_data()
    PdfHelveticaBoldOblique => pdf_standard14_helvetica_bold_oblique_afm_data()
    PdfSymbol => pdf_standard14_symbol_afm_data()
    PdfZapfDingbats => pdf_standard14_zapf_dingbats_afm_data()
  }
}
