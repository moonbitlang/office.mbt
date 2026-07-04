///|
type Message = @core.Message

///|
type ConversionResult = @core.ConversionResult

///|
type BreakType = @document.BreakType

///|
type Note = @document.Note

///|
type Comment = @document.Comment

///|
type Image = @document.Image

///|
type DocumentElement = @document.DocumentElement

///|
type ParagraphProperties = @document.ParagraphProperties

///|
type RunProperties = @document.RunProperties

///|
type TableProperties = @document.TableProperties

///|
type HtmlNode = @html.HtmlNode

///|
type HtmlPathElement = @style_map.HtmlPathElement

///|
type StyleMapping = @style_map.StyleMapping

///|
fn identity_document_transform(element : DocumentElement) -> DocumentElement {
  @document.identity_document_transform(element)
}

///|
fn default_style_map_lines() -> Array[String] {
  @style_map.default_style_map_lines()
}

///|
fn simplify_html(nodes : Array[HtmlNode]) -> Array[HtmlNode] {
  @html.simplify_html(nodes)
}

///|
fn write_html(nodes : Array[HtmlNode], pretty_print? : Bool = false) -> String {
  @html.write_html(nodes, pretty_print~)
}

///|
fn write_markdown(nodes : Array[HtmlNode]) -> String {
  @html.write_markdown(nodes)
}

///|
fn html_text(value : String) -> HtmlNode {
  @html.html_text(value)
}

///|
fn html_element(
  tag : String,
  attributes? : Map[String, String] = {},
  children? : Array[HtmlNode] = [],
  fresh? : Bool = false,
  separator? : String = "",
) -> HtmlNode {
  @html.html_element(tag, attributes~, children~, fresh~, separator~)
}

///|
fn fresh_html_element(
  tag : String,
  attributes? : Map[String, String] = {},
  children? : Array[HtmlNode] = [],
  separator? : String = "",
) -> HtmlNode {
  @html.fresh_html_element(tag, attributes~, children~, separator~)
}
