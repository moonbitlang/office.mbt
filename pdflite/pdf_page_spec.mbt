///|
priv enum PdfPageSpecToken {
  PageSpecNumber(Int)
  PageSpecWord(String)
  PageSpecDash
  PageSpecComma
}

///|
priv struct PdfPageSpecContext {
  end_page : Int
  document : PdfDocument?
  source : String
}

///|
fn PdfPageSpecContext::bad(self : PdfPageSpecContext) -> Unit raise PdfError {
  raise BadPageSpecification(self.source)
}
