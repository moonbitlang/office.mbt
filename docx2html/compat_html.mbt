///|
pub type HtmlNode = @html.HtmlNode

///|
pub fn html_text(value : String) -> HtmlNode {
  @html.html_text(value)
}

///|
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
pub fn fresh_html_element(
  tag : String,
  attributes? : Map[String, String] = {},
  children? : Array[HtmlNode] = [],
  separator? : String = "",
) -> HtmlNode {
  @html.fresh_html_element(tag, attributes~, children~, separator~)
}

///|
pub fn write_html(
  nodes : Array[HtmlNode],
  pretty_print? : Bool = false,
) -> String {
  @html.write_html(nodes, pretty_print~)
}

///|
pub fn escape_html(value : String) -> String {
  @html.escape_html(value)
}

///|
pub fn escape_html_attribute(value : String) -> String {
  @html.escape_html_attribute(value)
}

///|
pub fn write_markdown(nodes : Array[HtmlNode]) -> String {
  @html.write_markdown(nodes)
}

///|
pub fn escape_markdown_text(value : String) -> String {
  @html.escape_markdown_text(value)
}

///|
pub fn simplify_html(nodes : Array[HtmlNode]) -> Array[HtmlNode] {
  @html.simplify_html(nodes)
}
