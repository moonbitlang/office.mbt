///|
/// Selects whether conversion renders HTML or Markdown.
pub type OutputFormat = @converter.OutputFormat

///|
/// Rendered image nodes plus any diagnostics from image conversion.
pub type ImageConversion = @converter.ImageConversion

///|
/// Builds an image conversion result from rendered nodes and diagnostics.
pub fn image_conversion(
  nodes : Array[HtmlNode],
  messages? : Array[Message] = [],
) -> ImageConversion {
  @converter.image_conversion(nodes, messages~)
}

///|
/// Converts a document tree to HTML.
pub fn convert_document_to_html(
  document : DocumentElement,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
  convert_image? : (Image) -> ImageConversion = @converter.data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = @document.identity_document_transform,
) -> ConversionResult {
  @converter.convert_document_to_html(
    document,
    style_map~,
    include_default_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    pretty_print~,
    convert_image~,
    transform_document~,
  )
}

///|
/// Converts a document tree to Markdown.
pub fn convert_document_to_markdown(
  document : DocumentElement,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  convert_image? : (Image) -> ImageConversion = @converter.data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = @document.identity_document_transform,
) -> ConversionResult {
  @converter.convert_document_to_markdown(
    document,
    style_map~,
    include_default_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    convert_image~,
    transform_document~,
  )
}

///|
/// Converts a document tree using the requested output format.
pub fn convert_document(
  document : DocumentElement,
  output_format? : OutputFormat = Html,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
  convert_image? : (Image) -> ImageConversion = @converter.data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = @document.identity_document_transform,
) -> ConversionResult {
  @converter.convert_document(
    document,
    output_format~,
    style_map~,
    include_default_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    pretty_print~,
    convert_image~,
    transform_document~,
  )
}

///|
/// Converts images to inline data URI image nodes.
pub fn data_uri_image_converter(image : Image) -> ImageConversion {
  @converter.data_uri_image_converter(image)
}

///|
/// Converts one image to an inline data URI image result.
pub fn data_uri_image(image : Image) -> ImageConversion {
  @converter.data_uri_image(image)
}

///|
/// Creates an image converter that emits an `img` element.
pub fn img_element(
  read_attributes : (Image) -> Map[String, String],
) -> (Image) -> ImageConversion {
  @converter.img_element(read_attributes)
}

///|
/// Alias for `img_element` matching Mammoth image API style.
pub fn inline_image(
  read_attributes : (Image) -> Map[String, String],
) -> (Image) -> ImageConversion {
  @converter.inline_image(read_attributes)
}
