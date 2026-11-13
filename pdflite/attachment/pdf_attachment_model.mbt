///|
/// One embedded file attachment.
///
/// `pagenumber == 0` represents a document-level attachment. Page attachments
/// use one-based page numbers. `data == None` represents a malformed page-level
/// attachment annotation with a file specification but no embedded-file stream.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAttachment {
  name : String
  pagenumber : Int32
  data : @core.PdfBytes?
  description : String?
  relationship : String?
}
