///|
/// Node in the intermediate HTML tree.
pub type HtmlNode = @html.HtmlNode

///|
/// Builds an HTML text node.
pub fn html_text(value : String) -> HtmlNode {
  @html.html_text(value)
}

///|
/// Builds an HTML element node.
pub fn html_element(
  tag : String,
  attributes? : Map[String, String] = {},
  children? : Array[HtmlNode] = [],
  fresh? : Bool = false,
  separator? : String = "",
) -> HtmlNode {
  @html.html_element(tag, attributes~, children~, fresh~, separator~)
}

///|
/// Builds an HTML element with a fresh generated id.
pub fn fresh_html_element(
  tag : String,
  attributes? : Map[String, String] = {},
  children? : Array[HtmlNode] = [],
  separator? : String = "",
) -> HtmlNode {
  @html.fresh_html_element(tag, attributes~, children~, separator~)
}

///|
/// Serializes HTML nodes to a string.
pub fn write_html(
  nodes : Array[HtmlNode],
  pretty_print? : Bool = false,
) -> String {
  @html.write_html(nodes, pretty_print~)
}

///|
/// Escapes text for HTML content.
pub fn escape_html(value : String) -> String {
  @html.escape_html(value)
}

///|
/// Escapes text for an HTML attribute value.
pub fn escape_html_attribute(value : String) -> String {
  @html.escape_html_attribute(value)
}

///|
/// Serializes HTML nodes to Markdown.
pub fn write_markdown(nodes : Array[HtmlNode]) -> String {
  @html.write_markdown(nodes)
}

///|
/// Escapes text for Markdown output.
pub fn escape_markdown_text(value : String) -> String {
  @html.escape_markdown_text(value)
}

///|
/// Simplifies adjacent and redundant HTML nodes.
pub fn simplify_html(nodes : Array[HtmlNode]) -> Array[HtmlNode] {
  @html.simplify_html(nodes)
}
