///|
/// Return true when this CMap consumes text as fixed two-byte character codes.
///
/// Identity CMaps and common UCS2/UTF16 predefined maps are treated as
/// two-byte. Parsed external CMaps are two-byte only when all code spaces have
/// length 2, or when they inherit an identity base with no explicit spaces.
pub fn PdfCMapEncoding::uses_two_byte_codes(self : PdfCMapEncoding) -> Bool {
  match self {
    PdfPredefinedCMap(name) =>
      self.is_identity_h() ||
      self.is_identity_v() ||
      pdf_text_predefined_cmap_uses_two_byte_charcodes(name)
    PdfExternalCMap(_, parsed) =>
      if parsed.codespaces.length() == 0 {
        match parsed.usecmap {
          Some(name) =>
            name == pdf_text_identity_h_name ||
            name == pdf_text_identity_v_name ||
            pdf_text_predefined_cmap_uses_two_byte_charcodes(name)
          None => false
        }
      } else {
        for codespace in parsed.codespaces {
          if codespace.length != 2 {
            break false
          }
        } nobreak {
          true
        }
      }
    _ => false
  }
}
