///|
pub(all) enum PdfStandardFont {
  PdfTimesRoman
  PdfTimesBold
  PdfTimesItalic
  PdfTimesBoldItalic
  PdfHelvetica
  PdfHelveticaBold
  PdfHelveticaOblique
  PdfHelveticaBoldOblique
  PdfCourier
  PdfCourierBold
  PdfCourierOblique
  PdfCourierBoldOblique
  PdfSymbol
  PdfZapfDingbats
} derive(Debug, Eq, ToJson)

///|
pub fn PdfStandardFont::name(self : PdfStandardFont) -> String {
  match self {
    PdfTimesRoman => "Times-Roman"
    PdfTimesBold => "Times-Bold"
    PdfTimesItalic => "Times-Italic"
    PdfTimesBoldItalic => "Times-BoldItalic"
    PdfHelvetica => "Helvetica"
    PdfHelveticaBold => "Helvetica-Bold"
    PdfHelveticaOblique => "Helvetica-Oblique"
    PdfHelveticaBoldOblique => "Helvetica-BoldOblique"
    PdfCourier => "Courier"
    PdfCourierBold => "Courier-Bold"
    PdfCourierOblique => "Courier-Oblique"
    PdfCourierBoldOblique => "Courier-BoldOblique"
    PdfSymbol => "Symbol"
    PdfZapfDingbats => "ZapfDingbats"
  }
}

///|
fn pdf_text_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
pub fn PdfStandardFont::pdf_name(self : PdfStandardFont) -> PdfName {
  pdf_text_name("/" + self.name())
}

///|
pub fn pdf_standard_font_of_name(name : String) -> PdfStandardFont? {
  match name {
    "/Times-Roman" | "/TimesNewRoman" => Some(PdfTimesRoman)
    "/Times-Bold" | "/TimesNewRoman,Bold" => Some(PdfTimesBold)
    "/Times-Italic" | "/TimesNewRoman,Italic" => Some(PdfTimesItalic)
    "/Times-BoldItalic" | "/TimesNewRoman,BoldItalic" =>
      Some(PdfTimesBoldItalic)
    "/Helvetica" | "/Arial" => Some(PdfHelvetica)
    "/Helvetica-Bold" | "/Arial,Bold" => Some(PdfHelveticaBold)
    "/Helvetica-Oblique" | "/Arial,Italic" => Some(PdfHelveticaOblique)
    "/Helvetica-BoldOblique" | "/Arial,BoldItalic" =>
      Some(PdfHelveticaBoldOblique)
    "/Courier" | "/CourierNew" => Some(PdfCourier)
    "/Courier-Bold" | "/CourierNew,Bold" => Some(PdfCourierBold)
    "/Courier-Oblique" | "/CourierNew,Italic" => Some(PdfCourierOblique)
    "/Courier-BoldOblique" | "/CourierNew,BoldItalic" =>
      Some(PdfCourierBoldOblique)
    "/Symbol" => Some(PdfSymbol)
    "/ZapfDingbats" => Some(PdfZapfDingbats)
    _ => None
  }
}

///|
pub fn pdf_standard_font_of_pdf_name(name : PdfName) -> PdfStandardFont? {
  match name {
    name if name == pdf_text_name("/Times-Roman") ||
      name == pdf_text_name("/TimesNewRoman") => Some(PdfTimesRoman)
    name if name == pdf_text_name("/Times-Bold") ||
      name == pdf_text_name("/TimesNewRoman,Bold") => Some(PdfTimesBold)
    name if name == pdf_text_name("/Times-Italic") ||
      name == pdf_text_name("/TimesNewRoman,Italic") => Some(PdfTimesItalic)
    name if name == pdf_text_name("/Times-BoldItalic") ||
      name == pdf_text_name("/TimesNewRoman,BoldItalic") =>
      Some(PdfTimesBoldItalic)
    name if name == pdf_text_name("/Helvetica") ||
      name == pdf_text_name("/Arial") => Some(PdfHelvetica)
    name if name == pdf_text_name("/Helvetica-Bold") ||
      name == pdf_text_name("/Arial,Bold") => Some(PdfHelveticaBold)
    name if name == pdf_text_name("/Helvetica-Oblique") ||
      name == pdf_text_name("/Arial,Italic") => Some(PdfHelveticaOblique)
    name if name == pdf_text_name("/Helvetica-BoldOblique") ||
      name == pdf_text_name("/Arial,BoldItalic") =>
      Some(PdfHelveticaBoldOblique)
    name if name == pdf_text_name("/Courier") ||
      name == pdf_text_name("/CourierNew") => Some(PdfCourier)
    name if name == pdf_text_name("/Courier-Bold") ||
      name == pdf_text_name("/CourierNew,Bold") => Some(PdfCourierBold)
    name if name == pdf_text_name("/Courier-Oblique") ||
      name == pdf_text_name("/CourierNew,Italic") => Some(PdfCourierOblique)
    name if name == pdf_text_name("/Courier-BoldOblique") ||
      name == pdf_text_name("/CourierNew,BoldItalic") =>
      Some(PdfCourierBoldOblique)
    name if name == pdf_text_name("/Symbol") => Some(PdfSymbol)
    name if name == pdf_text_name("/ZapfDingbats") => Some(PdfZapfDingbats)
    _ => None
  }
}

///|
pub fn PdfStandardFont::baseline_adjustment(self : PdfStandardFont) -> Int {
  match self {
    PdfTimesRoman => 662 / 2
    PdfTimesBold => 676 / 2
    PdfTimesItalic => 653 / 2
    PdfTimesBoldItalic => 669 / 2
    PdfHelvetica
    | PdfHelveticaBold
    | PdfHelveticaOblique
    | PdfHelveticaBoldOblique => 718 / 2
    PdfCourier | PdfCourierBold | PdfCourierOblique | PdfCourierBoldOblique =>
      562 / 2
    PdfSymbol => 673 / 2
    PdfZapfDingbats => 705 / 2
  }
}

///|
pub fn PdfStandardFont::stemv(self : PdfStandardFont) -> Int {
  match self {
    PdfTimesRoman => 116
    PdfTimesBold => 122
    PdfTimesItalic => 105
    PdfTimesBoldItalic => 108
    PdfHelvetica => 114
    PdfHelveticaBold => 123
    PdfHelveticaOblique => 127
    PdfHelveticaBoldOblique => 136
    PdfCourier => 88
    PdfCourierBold => 93
    PdfCourierOblique => 100
    PdfCourierBoldOblique => 104
    PdfSymbol => 0
    PdfZapfDingbats => 125
  }
}

///|
pub fn PdfStandardFont::flags(self : PdfStandardFont) -> Int {
  match self {
    PdfSymbol => 65541
    PdfZapfDingbats => 4
    PdfCourier | PdfCourierBold | PdfCourierOblique | PdfCourierBoldOblique =>
      33
    _ => 32
  }
}
