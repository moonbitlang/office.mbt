///|
type DocxError = @core.DocxError

///|
type Message = @core.Message

///|
type ConversionResult = @core.ConversionResult

///|
type VerticalAlignment = @document.VerticalAlignment

///|
type Numbering = @document.Numbering

///|
type Indent = @document.Indent

///|
type ParagraphProperties = @document.ParagraphProperties

///|
type RunProperties = @document.RunProperties

///|
type TableProperties = @document.TableProperties

///|
type Note = @document.Note

///|
type Comment = @document.Comment

///|
type Image = @document.Image

///|
type DocumentElement = @document.DocumentElement

///|
type OutputFormat = @converter.OutputFormat

///|
type ImageConversion = @converter.ImageConversion

///|
type XmlNode = @xml.XmlNode

///|
type XmlElement = @xml.XmlElement

///|
type ZipArchive = @zip.ZipArchive

///|
fn open_zip(data : BytesView) -> ZipArchive raise DocxError {
  @zip.open_zip(data)
}

///|
fn split_zip_path(path : String) -> (String, String) {
  @zip.split_zip_path(path)
}

///|
fn join_zip_path(parts : Array[String]) -> String {
  @zip.join_zip_path(parts)
}

///|
fn read_xml_string(
  value : String,
  namespace_map? : Map[String, String] = Map([]),
) -> XmlElement raise DocxError {
  @xml.read_xml_string(value, namespace_map~)
}

///|
fn write_xml_string(
  element : XmlElement,
  namespaces? : Map[String, String] = Map([]),
) -> String {
  @xml.write_xml_string(element, namespaces~)
}

///|
fn xml_element(
  name : String,
  attributes? : Map[String, String] = Map([]),
  children? : Array[XmlNode] = [],
) -> XmlElement {
  @xml.xml_element(name, attributes~, children~)
}

///|
fn convert_document(
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
fn extract_raw_text_from_document(
  document : DocumentElement,
) -> ConversionResult {
  @document.extract_raw_text_from_document(document)
}

///|
fn read_style_map_string(style_map : String) -> Array[String] {
  @style_map.read_style_map_string(style_map)
}

///|
fn data_uri_image_converter(image : Image) -> ImageConversion {
  @converter.data_uri_image_converter(image)
}

///|
fn identity_document_transform(element : DocumentElement) -> DocumentElement {
  @document.identity_document_transform(element)
}

///|
fn document(
  children : Array[DocumentElement],
  notes? : Array[Note] = [],
  comments? : Array[Comment] = [],
) -> DocumentElement {
  @document.document(children, notes~, comments~)
}

///|
fn paragraph(
  children : Array[DocumentElement],
  properties? : ParagraphProperties = @document.ParagraphProperties::default(),
) -> DocumentElement {
  @document.paragraph(children, properties~)
}

///|
fn run(
  children : Array[DocumentElement],
  properties? : RunProperties = @document.RunProperties::default(),
) -> DocumentElement {
  @document.run(children, properties~)
}

///|
fn text(value : String) -> DocumentElement {
  @document.text(value)
}

///|
fn tab() -> DocumentElement {
  @document.tab()
}

///|
fn checkbox(checked : Bool) -> DocumentElement {
  @document.checkbox(checked)
}

///|
fn line_break() -> DocumentElement {
  @document.line_break()
}

///|
fn page_break() -> DocumentElement {
  @document.page_break()
}

///|
fn column_break() -> DocumentElement {
  @document.column_break()
}
