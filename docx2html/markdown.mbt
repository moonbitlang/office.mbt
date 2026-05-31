///|
pub fn write_markdown(nodes : Array[HtmlNode]) -> String {
  let writer = MarkdownWriter::{ buffer: StringBuilder() }
  writer.write_nodes(nodes)
  writer.buffer.to_string()
}

///|
priv struct MarkdownWriter {
  buffer : StringBuilder
}

///|
fn MarkdownWriter::write_nodes(
  self : MarkdownWriter,
  nodes : Array[HtmlNode],
) -> Unit {
  for node in nodes {
    self.write_node(node)
  }
}

///|
fn MarkdownWriter::write_node(self : MarkdownWriter, node : HtmlNode) -> Unit {
  match node {
    TextNode(value) => self.buffer.write_string(escape_markdown_text(value))
    ForceWrite => ()
    Element(tag~, attributes~, children~, ..) =>
      match tag {
        "p" => {
          self.write_nodes(children)
          self.buffer.write_string("\n\n")
        }
        "br" => self.buffer.write_string("  \n")
        "strong" => {
          self.buffer.write_string("__")
          self.write_nodes(children)
          self.buffer.write_string("__")
        }
        "em" => {
          self.buffer.write_string("*")
          self.write_nodes(children)
          self.buffer.write_string("*")
        }
        "a" => self.write_anchor(attributes, children)
        "img" => self.write_image(attributes)
        "h1" | "h2" | "h3" | "h4" | "h5" | "h6" =>
          self.write_heading(tag, children)
        "ul" => self.write_list(children, ordered=false)
        "ol" => self.write_list(children, ordered=true)
        "li" => {
          self.write_nodes(children)
          self.buffer.write_string("\n")
        }
        _ => self.write_nodes(children)
      }
  }
}

///|
fn MarkdownWriter::write_anchor(
  self : MarkdownWriter,
  attributes : Map[String, String],
  children : Array[HtmlNode],
) -> Unit {
  match attributes.get("href") {
    Some(href) => {
      self.buffer.write_string("[")
      self.write_nodes(children)
      self.buffer.write_string("](")
      self.buffer.write_string(href)
      self.buffer.write_string(")")
    }
    None => self.write_nodes(children)
  }
}

///|
fn MarkdownWriter::write_image(
  self : MarkdownWriter,
  attributes : Map[String, String],
) -> Unit {
  match attributes.get("src") {
    Some(src) => {
      let alt = attributes.get_or_default("alt", "")
      self.buffer.write_string("![")
      self.buffer.write_string(escape_markdown_text(alt))
      self.buffer.write_string("](")
      self.buffer.write_string(src)
      self.buffer.write_string(")")
    }
    None => ()
  }
}

///|
fn MarkdownWriter::write_heading(
  self : MarkdownWriter,
  tag : String,
  children : Array[HtmlNode],
) -> Unit {
  let level = tag[1].to_int() - ('0' : UInt16).to_int()
  for _ in 0..<level {
    self.buffer.write_string("#")
  }
  self.buffer.write_string(" ")
  self.write_nodes(children)
  self.buffer.write_string("\n\n")
}

///|
fn MarkdownWriter::write_list(
  self : MarkdownWriter,
  children : Array[HtmlNode],
  ordered~ : Bool,
) -> Unit {
  let mut index = 1
  for child in children {
    match child {
      Element(tag="li", children=li_children, ..) => {
        if ordered {
          self.buffer.write_string("\{index}. ")
          index = index + 1
        } else {
          self.buffer.write_string("- ")
        }
        self.write_nodes(li_children)
        self.buffer.write_string("\n")
      }
      _ => self.write_node(child)
    }
  }
  self.buffer.write_string("\n")
}

///|
pub fn escape_markdown_text(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    match char {
      '\\'
      | '`'
      | '*'
      | '_'
      | '{'
      | '}'
      | '['
      | ']'
      | '('
      | ')'
      | '#'
      | '+'
      | '-'
      | '.'
      | '!' => {
        builder.write_string("\\")
        builder.write_char(char)
      }
      _ => builder.write_char(char)
    }
  }
  builder.to_string()
}
