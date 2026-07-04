///|
/// Document tree plus diagnostics produced while reading a DOCX package.
pub type DocxReadResult = @docx_impl.DocxReadResult

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
