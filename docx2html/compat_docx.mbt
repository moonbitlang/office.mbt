///|
/// Document tree plus diagnostics produced while reading a DOCX package.
pub type DocxReadResult = @docx_impl.DocxReadResult

///|
/// Package-level read result: body document plus sections and header/footer
/// stories. Returned by `read_docx_package`.
pub type DocxPackageResult = @docx_impl.DocxPackageResult

///|
/// Converts DOCX bytes to HTML.
pub fn convert_to_html(
  docx : BytesView,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  include_embedded_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
  convert_image? : (Image) -> ImageConversion = @converter.data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = @document.identity_document_transform,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> ConversionResult raise DocxError {
  bridge_core_error(() => {
    @docx_impl.convert_to_html(
      docx,
      style_map~,
      include_default_style_map~,
      include_embedded_style_map~,
      ignore_empty_paragraphs~,
      id_prefix~,
      pretty_print~,
      convert_image~,
      transform_document~,
      external_file_access~,
      read_external_file~,
    )
  })
}

///|
/// Converts DOCX bytes to Markdown.
pub fn convert_to_markdown(
  docx : BytesView,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  include_embedded_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  convert_image? : (Image) -> ImageConversion = @converter.data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = @document.identity_document_transform,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> ConversionResult raise DocxError {
  bridge_core_error(() => {
    @docx_impl.convert_to_markdown(
      docx,
      style_map~,
      include_default_style_map~,
      include_embedded_style_map~,
      ignore_empty_paragraphs~,
      id_prefix~,
      convert_image~,
      transform_document~,
      external_file_access~,
      read_external_file~,
    )
  })
}

///|
/// Converts DOCX bytes using the requested output format.
pub fn convert(
  docx : BytesView,
  output_format? : OutputFormat = Html,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  include_embedded_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
  convert_image? : (Image) -> ImageConversion = @converter.data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = @document.identity_document_transform,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> ConversionResult raise DocxError {
  bridge_core_error(() => {
    @docx_impl.convert(
      docx,
      output_format~,
      style_map~,
      include_default_style_map~,
      include_embedded_style_map~,
      ignore_empty_paragraphs~,
      id_prefix~,
      pretty_print~,
      convert_image~,
      transform_document~,
      external_file_access~,
      read_external_file~,
    )
  })
}

///|
/// Extracts raw text from DOCX bytes.
pub fn extract_raw_text(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> ConversionResult raise DocxError {
  bridge_core_error(() => {
    @docx_impl.extract_raw_text(
      docx,
      external_file_access~,
      read_external_file~,
    )
  })
}

///|
/// Reads the embedded style map from DOCX bytes, if present.
pub fn read_embedded_style_map(docx : BytesView) -> String? raise DocxError {
  bridge_core_error(() => @docx_impl.read_embedded_style_map(docx))
}

///|
/// Reads DOCX bytes into a document tree.
pub fn read_docx(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocumentElement raise DocxError {
  bridge_core_error(() => {
    @docx_impl.read_docx(docx, external_file_access~, read_external_file~)
  })
}

///|
/// Reads DOCX bytes into a document tree and diagnostics.
pub fn read_docx_with_messages(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocxReadResult raise DocxError {
  bridge_core_error(() => {
    @docx_impl.read_docx_with_messages(
      docx,
      external_file_access~,
      read_external_file~,
    )
  })
}

///|
/// Builds a minimal, schema-valid blank docx (one empty paragraph, Normal
/// style, Letter page). See `@docx.new_blank_docx`.
pub fn new_blank_docx() -> Bytes {
  @docx_impl.new_blank_docx()
}

///|
/// Serializes semantic body content (paragraphs and runs, F1 surface) into
/// a schema-valid docx. Fail-closed: unsupported elements raise
/// `Unsupported` rather than dropping content. See `@docx.write_docx`.
pub fn write_docx(body : Array[DocumentElement]) -> Bytes raise DocxError {
  bridge_core_error(() => @docx_impl.write_docx(body))
}

///|
/// Validates and builds one comment for `write_docx_with_comments`:
/// author/initials/date metadata, the inclusive 0-based range of body
/// block indexes it anchors (`from..to`, both endpoints top-level
/// paragraphs), and its paragraph-only plain-content body. See
/// `@docx.comment_spec` for the fail-closed rules (non-empty author,
/// lexical xsd:dateTime date, ordered range, non-empty body).
pub fn comment_spec(
  author~ : String,
  initials? : String,
  date? : String,
  from~ : Int,
  to~ : Int,
  done? : Bool,
  body : Array[DocumentElement],
) -> @docx_impl.CommentSpec raise DocxError {
  bridge_core_error(() => {
    @docx_impl.comment_spec(author~, initials?, date?, from~, to~, done?, body)
  })
}

///|
/// Builds an anchorless REPLY to an earlier comment spec (by its index
/// in the array passed to `write_docx_with_comments`); the thread
/// linkage lands in word/commentsExtended.xml. See `@docx.comment_reply`.
pub fn comment_reply(
  author~ : String,
  initials? : String,
  date? : String,
  reply_to~ : Int,
  done? : Bool,
  body : Array[DocumentElement],
) -> @docx_impl.CommentSpec raise DocxError {
  bridge_core_error(() => {
    @docx_impl.comment_reply(author~, initials?, date?, reply_to~, done?, body)
  })
}

///|
/// `write_docx` plus comments: anchors are emitted into the anchored
/// paragraphs in the canonical shape and the definitions land in
/// word/comments.xml as a main-part relationship, with dense ids (a
/// spec's array index is its w:id). See `@docx.write_docx_with_comments`.
pub fn write_docx_with_comments(
  body : Array[DocumentElement],
  comments : Array[@docx_impl.CommentSpec],
) -> Bytes raise DocxError {
  bridge_core_error(() => @docx_impl.write_docx_with_comments(body, comments))
}

///|
/// Reads DOCX bytes into the package-level representation: the body
/// document (identical to `read_docx_with_messages`) plus sections and
/// header/footer stories. See `@docx.read_docx_package`.
pub fn read_docx_package(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocxPackageResult raise DocxError {
  bridge_core_error(() => {
    @docx_impl.read_docx_package(
      docx,
      external_file_access~,
      read_external_file~,
    )
  })
}

///|
/// Embeds or replaces the DOCX style map part.
pub fn embed_style_map(
  docx : BytesView,
  style_map : String,
) -> Bytes raise DocxError {
  bridge_core_error(() => @docx_impl.embed_style_map(docx, style_map))
}

///|
fn no_external_file_reader(_path : String) -> Bytes? {
  None
}

///|
/// Reads DOCX bytes into the package representation PLUS the annotation
/// index (comments with threading and anchors, note references). See
/// `@docx.read_docx_annotated`; the package half is identical to
/// `read_docx_package`.
pub fn read_docx_annotated(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> @docx_impl.DocxAnnotatedResult raise DocxError {
  bridge_core_error(() => {
    @docx_impl.read_docx_annotated(
      docx,
      external_file_access~,
      read_external_file~,
    )
  })
}
