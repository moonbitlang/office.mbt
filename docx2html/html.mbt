///|
pub(all) enum HtmlNode {
  Element(
    tag~ : String,
    attributes~ : Map[String, String],
    children~ : Array[HtmlNode],
    fresh~ : Bool
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
) -> HtmlNode {
  Element(tag~, attributes~, children~, fresh~)
}

///|
pub fn fresh_html_element(
  tag : String,
  attributes? : Map[String, String] = {},
  children? : Array[HtmlNode] = [],
) -> HtmlNode {
  Element(tag~, attributes~, children~, fresh=true)
}

///|
pub fn write_html(
  nodes : Array[HtmlNode],
  pretty_print? : Bool = false,
) -> String {
  let writer = HtmlWriter::{ pretty_print, buffer: StringBuilder(), indent: 0 }
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
    TextNode(value) => {
      if self.pretty_print {
        self.write_indent()
      }
      self.buffer.write_string(escape_html(value))
      if self.pretty_print {
        self.buffer.write_string("\n")
      }
    }
    ForceWrite => ()
    Element(tag~, attributes~, children~, ..) => {
      if self.pretty_print {
        self.write_indent()
      }
      self.buffer.write_string("<")
      self.buffer.write_string(tag)
      self.write_attributes(attributes)
      if children.is_empty() && is_void_html_tag(tag) {
        self.buffer.write_string(" />")
      } else {
        self.buffer.write_string(">")
        if self.pretty_print {
          self.buffer.write_string("\n")
        }
        self.indent = self.indent + 1
        self.write_nodes(children)
        self.indent = self.indent - 1
        if self.pretty_print {
          self.write_indent()
        }
        self.buffer.write_string("</")
        self.buffer.write_string(tag)
        self.buffer.write_string(">")
      }
      if self.pretty_print {
        self.buffer.write_string("\n")
      }
    }
  }
}

///|
fn is_void_html_tag(tag : String) -> Bool {
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
fn HtmlWriter::write_indent(self : HtmlWriter) -> Unit {
  for _ in 0..<self.indent {
    self.buffer.write_string("  ")
  }
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
