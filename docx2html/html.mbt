///|
pub(all) enum HtmlNode {
  Element(
    tag~ : String,
    attributes~ : Map[String, String],
    children~ : Array[HtmlNode],
    fresh~ : Bool,
    separator~ : String?
  )
  TextNode(String)
  ForceWrite
} derive(Debug, Eq)

///|
pub fn html_text(value : String) -> HtmlNode {
  TextNode(value)
}

///|
pub fn html_element(
  tag : String,
  attributes? : Map[String, String] = {},
  children? : Array[HtmlNode] = [],
  fresh? : Bool = false,
  separator? : String = "",
) -> HtmlNode {
  Element(
    tag~,
    attributes~,
    children~,
    fresh~,
    separator=separator_option(separator),
  )
}

///|
pub fn fresh_html_element(
  tag : String,
  attributes? : Map[String, String] = {},
  children? : Array[HtmlNode] = [],
  separator? : String = "",
) -> HtmlNode {
  Element(
    tag~,
    attributes~,
    children~,
    fresh=true,
    separator=separator_option(separator),
  )
}

///|
fn separator_option(value : String) -> String? {
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
pub fn write_html(
  nodes : Array[HtmlNode],
  pretty_print? : Bool = false,
) -> String {
  let writer = HtmlWriter::{
    pretty_print,
    buffer: StringBuilder(),
    indent: 0,
    stack: [],
    start: true,
    in_text: false,
  }
  writer.write_nodes(nodes)
  let result = writer.buffer.to_string()
  if pretty_print && result.has_suffix("\n") {
    result[:result.length() - 1].to_owned()
  } else {
    result
  }
}

///|
priv struct HtmlWriter {
  pretty_print : Bool
  buffer : StringBuilder
  mut indent : Int
  stack : Array[String]
  mut start : Bool
  mut in_text : Bool
}

///|
fn HtmlWriter::write_nodes(self : HtmlWriter, nodes : Array[HtmlNode]) -> Unit {
  for node in nodes {
    self.write_node(node)
  }
}

///|
fn HtmlWriter::write_node(self : HtmlWriter, node : HtmlNode) -> Unit {
  match node {
    TextNode(value) =>
      if self.pretty_print {
        self.write_pretty_text(value)
      } else {
        self.buffer.write_string(escape_html(value))
      }
    ForceWrite => ()
    Element(tag~, attributes~, children~, ..) => {
      let tag_name = html_primary_tag(tag)
      if children.is_empty() && is_void_html_tag(tag_name) {
        self.write_self_closing_tag(tag_name, attributes)
      } else {
        self.write_open_tag(tag_name, attributes)
        self.write_nodes(children)
        self.write_close_tag(tag_name)
      }
    }
  }
}

///|
fn HtmlWriter::write_open_tag(
  self : HtmlWriter,
  tag_name : String,
  attributes : Map[String, String],
) -> Unit {
  if self.pretty_print && is_pretty_indented_tag(tag_name) {
    self.write_pretty_indent()
  }
  self.stack.push(tag_name)
  self.buffer.write_string("<")
  self.buffer.write_string(tag_name)
  self.write_attributes(attributes)
  self.buffer.write_string(">")
  if self.pretty_print && is_pretty_indented_tag(tag_name) {
    self.indent = self.indent + 1
  }
  self.start = false
}

///|
fn HtmlWriter::write_close_tag(self : HtmlWriter, tag_name : String) -> Unit {
  if self.pretty_print && is_pretty_indented_tag(tag_name) {
    self.indent = self.indent - 1
    self.write_pretty_indent()
  }
  ignore(self.stack.pop())
  self.buffer.write_string("</")
  self.buffer.write_string(tag_name)
  self.buffer.write_string(">")
}

///|
fn HtmlWriter::write_self_closing_tag(
  self : HtmlWriter,
  tag_name : String,
  attributes : Map[String, String],
) -> Unit {
  if self.pretty_print {
    self.write_pretty_indent()
  }
  self.buffer.write_string("<")
  self.buffer.write_string(tag_name)
  self.write_attributes(attributes)
  self.buffer.write_string(" />")
  self.start = false
}

///|
fn HtmlWriter::write_pretty_text(self : HtmlWriter, value : String) -> Unit {
  self.start_pretty_text()
  if self.is_inside_pre() {
    self.buffer.write_string(escape_html(value))
  } else {
    self.buffer.write_string(escape_html(indent_first_text_newline(value)))
  }
}

///|
fn HtmlWriter::start_pretty_text(self : HtmlWriter) -> Unit {
  if !self.in_text {
    self.write_pretty_indent()
    self.in_text = true
  }
}

///|
fn HtmlWriter::write_pretty_indent(self : HtmlWriter) -> Unit {
  self.in_text = false
  if !self.start && self.is_inside_indented_element() && !self.is_inside_pre() {
    self.buffer.write_string("\n")
    for _ in 0..<self.indent {
      self.buffer.write_string("  ")
    }
  }
}

///|
fn HtmlWriter::is_inside_indented_element(self : HtmlWriter) -> Bool {
  match self.stack.last() {
    Some(tag_name) => is_pretty_indented_tag(tag_name)
    None => true
  }
}

///|
fn HtmlWriter::is_inside_pre(self : HtmlWriter) -> Bool {
  for tag_name in self.stack {
    if tag_name == "pre" {
      return true
    }
  }
  false
}

///|
fn is_pretty_indented_tag(tag_name : String) -> Bool {
  tag_name == "div" || tag_name == "p" || tag_name == "ul" || tag_name == "li"
}

///|
fn indent_first_text_newline(value : String) -> String {
  match value.find("\n") {
    Some(index) =>
      value[:index + 1].to_owned() + "  " + value[index + 1:].to_owned()
    None => value
  }
}

///|
fn html_primary_tag(tag : String) -> String {
  match tag.find("|") {
    Some(index) => tag[:index].trim().to_owned()
    None => tag.trim().to_owned()
  }
}

///|
fn html_tag_matches(candidate : String, actual : String) -> Bool {
  let actual = html_primary_tag(actual)
  for choice in candidate.split("|") {
    if choice.trim().to_owned() == actual {
      return true
    }
  }
  false
}

///|
fn is_void_html_tag(tag : String) -> Bool {
  let tag = html_primary_tag(tag)
  tag == "area" ||
  tag == "base" ||
  tag == "br" ||
  tag == "col" ||
  tag == "embed" ||
  tag == "hr" ||
  tag == "img" ||
  tag == "input" ||
  tag == "link" ||
  tag == "meta" ||
  tag == "param" ||
  tag == "source" ||
  tag == "track" ||
  tag == "wbr"
}

///|
fn HtmlWriter::write_attributes(
  self : HtmlWriter,
  attributes : Map[String, String],
) -> Unit {
  let items = attributes.to_array()
  items.sort_by(fn(a, b) {
    let (key_a, _) = a
    let (key_b, _) = b
    let rank_diff = html_attribute_rank(key_a) - html_attribute_rank(key_b)
    if rank_diff != 0 {
      rank_diff
    } else {
      key_a.compare(key_b)
    }
  })
  for item in items {
    let (key, value) = item
    self.buffer.write_string(" ")
    self.buffer.write_string(key)
    self.buffer.write_string("=\"")
    self.buffer.write_string(escape_html_attribute(value))
    self.buffer.write_string("\"")
  }
}

///|
fn html_attribute_rank(key : String) -> Int {
  match key {
    "class" => 0
    "href" => 1
    "alt" => 1
    "type" => 1
    "id" => 2
    "src" => 2
    "checked" => 2
    "target" => 3
    "disabled" => 3
    _ => 10
  }
}

///|
pub fn escape_html(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    match char {
      '&' => builder.write_string("&amp;")
      '<' => builder.write_string("&lt;")
      '>' => builder.write_string("&gt;")
      _ => builder.write_char(char)
    }
  }
  builder.to_string()
}

///|
pub fn escape_html_attribute(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    match char {
      '&' => builder.write_string("&amp;")
      '<' => builder.write_string("&lt;")
      '>' => builder.write_string("&gt;")
      '"' => builder.write_string("&quot;")
      _ => builder.write_char(char)
    }
  }
  builder.to_string()
}
