///|
/// Serializes HTML nodes to Markdown.
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
          self.write_id_anchor(attributes)
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
          self.write_heading(tag, attributes, children)
        "ul" => self.write_list(children, ordered=false, indent=0, nested=false)
        "ol" => self.write_list(children, ordered=true, indent=0, nested=false)
        "li" =>
          self.write_list_item(
            attributes,
            children,
            ordered=false,
            indent=0,
            number=1,
          )
        _ => {
          self.write_id_anchor(attributes)
          self.write_nodes(children)
        }
      }
  }
}

///|
fn MarkdownWriter::write_id_anchor(
  self : MarkdownWriter,
  attributes : Map[String, String],
) -> Unit {
  match attributes.get("id") {
    Some(id) => {
      self.buffer.write_string("<a id=\"")
      self.buffer.write_string(id)
      self.buffer.write_string("\"></a>")
    }
    None => ()
  }
}

///|
fn MarkdownWriter::write_anchor(
  self : MarkdownWriter,
  attributes : Map[String, String],
  children : Array[HtmlNode],
) -> Unit {
  self.write_id_anchor(attributes)
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
  let src = attributes.get_or_default("src", "")
  let alt = attributes.get_or_default("alt", "")
  if src != "" || alt != "" {
    self.buffer.write_string("![")
    self.buffer.write_string(alt)
    self.buffer.write_string("](")
    self.buffer.write_string(src)
    self.buffer.write_string(")")
  }
}

///|
fn MarkdownWriter::write_heading(
  self : MarkdownWriter,
  tag : String,
  attributes : Map[String, String],
  children : Array[HtmlNode],
) -> Unit {
  let level = tag[1].to_int() - ('0' : UInt16).to_int()
  for _ in 0..<level {
    self.buffer.write_string("#")
  }
  self.buffer.write_string(" ")
  self.write_id_anchor(attributes)
  self.write_nodes(children)
  self.buffer.write_string("\n\n")
}

///|
fn MarkdownWriter::write_list(
  self : MarkdownWriter,
  children : Array[HtmlNode],
  ordered~ : Bool,
  indent~ : Int,
  nested~ : Bool,
) -> Unit {
  if nested {
    self.buffer.write_string("\n")
  }
  let mut index = 1
  for child in children {
    match child {
      Element(tag="li", attributes=li_attributes, children=li_children, ..) => {
        self.write_list_item(
          li_attributes,
          li_children,
          ordered~,
          indent~,
          number=index,
        )
        index = index + 1
      }
      _ => self.write_node(child)
    }
  }
  if !nested {
    self.buffer.write_string("\n")
  }
}

///|
fn MarkdownWriter::write_list_item(
  self : MarkdownWriter,
  attributes : Map[String, String],
  children : Array[HtmlNode],
  ordered~ : Bool,
  indent~ : Int,
  number~ : Int,
) -> Unit {
  for _ in 0..<indent {
    self.buffer.write_string("\t")
  }
  if ordered {
    self.buffer.write_string("\{number}. ")
  } else {
    self.buffer.write_string("- ")
  }
  self.write_id_anchor(attributes)
  let ended_by_nested_list = self.write_list_item_children(
    children,
    nested_indent=indent + 1,
  )
  if !ended_by_nested_list {
    self.buffer.write_string("\n")
  }
}

///|
fn MarkdownWriter::write_list_item_children(
  self : MarkdownWriter,
  children : Array[HtmlNode],
  nested_indent~ : Int,
) -> Bool {
  let mut ended_by_nested_list = false
  for child in children {
    match child {
      Element(tag="ul", children=nested_children, ..) => {
        self.write_list(
          nested_children,
          ordered=false,
          indent=nested_indent,
          nested=true,
        )
        ended_by_nested_list = true
      }
      Element(tag="ol", children=nested_children, ..) => {
        self.write_list(
          nested_children,
          ordered=true,
          indent=nested_indent,
          nested=true,
        )
        ended_by_nested_list = true
      }
      _ => {
        self.write_node(child)
        ended_by_nested_list = false
      }
    }
  }
  ended_by_nested_list
}

///|
/// Escapes text for Markdown output.
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
