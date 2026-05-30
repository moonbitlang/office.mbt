///|
/// A destination target page reference.
///
/// PDF destination arrays may refer either to a page object or to a page number
/// in another document.
pub(all) enum PdfTargetPage {
  TargetPageObject(Int)
  TargetOtherDocPageNumber(Int)
} derive(Debug, Eq, ToJson)

///|
/// A normalized PDF destination.
///
/// The variants cover action dictionaries, named/string destinations, null
/// destinations, and all standard page-view destination array forms.
pub(all) enum PdfDestination {
  DestAction(@syntax.PdfObject)
  DestNull
  DestNamed(@core.PdfName)
  DestString(@core.PdfBytes)
  DestXYZ(PdfTargetPage, Double?, Double?, Double?)
  DestFit(PdfTargetPage)
  DestFitH(PdfTargetPage, Double?)
  DestFitV(PdfTargetPage, Double?)
  DestFitR(PdfTargetPage, Double, Double, Double, Double)
  DestFitB(PdfTargetPage)
  DestFitBH(PdfTargetPage, Double?)
  DestFitBV(PdfTargetPage, Double?)
} derive(Debug, Eq, ToJson)
