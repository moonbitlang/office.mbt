///|
pub type OutputFormat = @converter.OutputFormat

///|
pub type ImageConversion = @converter.ImageConversion

///|
pub fn image_conversion(
  nodes : Array[HtmlNode],
  messages? : Array[Message] = [],
) -> ImageConversion {
  @converter.image_conversion(nodes, messages~)
}

///|
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
pub fn data_uri_image_converter(image : Image) -> ImageConversion {
  @converter.data_uri_image_converter(image)
}

///|
pub fn data_uri_image(image : Image) -> ImageConversion {
  @converter.data_uri_image(image)
}

///|
pub fn img_element(
  read_attributes : (Image) -> Map[String, String],
) -> (Image) -> ImageConversion {
  @converter.img_element(read_attributes)
}

///|
pub fn inline_image(
  read_attributes : (Image) -> Map[String, String],
) -> (Image) -> ImageConversion {
  @converter.inline_image(read_attributes)
}
