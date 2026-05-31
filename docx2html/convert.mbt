///|
pub(all) struct ConvertOptions {
  style_map : Array[StyleMapping]
  ignore_empty_paragraphs : Bool
  id_prefix : String
  pretty_print : Bool
  output_format : String
} derive(Debug, Eq)

///|
pub fn ConvertOptions::default() -> ConvertOptions {
  {
    style_map: read_style_map(default_style_map_lines()),
    ignore_empty_paragraphs: true,
    id_prefix: "",
    pretty_print: false,
    output_format: "html",
  }
}

///|
pub fn convert_document_to_html(
  document : DocumentElement,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
) -> ConversionResult {
  let all_style_lines : Array[String] = []
  all_style_lines.append(style_map)
  if include_default_style_map {
    all_style_lines.append(default_style_map_lines())
  }
  let options = ConvertOptions::{
    style_map: read_style_map(all_style_lines),
    ignore_empty_paragraphs,
    id_prefix,
    pretty_print,
    output_format: "html",
  }
  let converter = DocumentConverter::{ options, messages: [] }
  let nodes = converter.convert_element(document)
  {
    value: write_html(simplify_html(nodes), pretty_print~),
    messages: converter.messages,
  }
}

///|
pub fn convert_document_to_markdown(
  document : DocumentElement,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
) -> ConversionResult {
  let result = convert_document_to_html(
    document,
    style_map~,
    include_default_style_map~,
  )
  let options = ConvertOptions::default()
  let converter = DocumentConverter::{ options, messages: [] }
  let nodes = converter.convert_element(document)
  { value: write_markdown(simplify_html(nodes)), messages: result.messages }
}

///|
priv struct DocumentConverter {
  options : ConvertOptions
  messages : Array[Message]
}

///|
fn DocumentConverter::convert_element(
  self : DocumentConverter,
  element : DocumentElement,
) -> Array[HtmlNode] {
  match element {
    Document(children~, notes~, comments~) => {
      let nodes = self.convert_children(children)
      let note_nodes = self.convert_notes(notes)
      let comment_nodes = self.convert_comments(comments)
      nodes + note_nodes + comment_nodes
    }
    Paragraph(children~, ..) => self.convert_paragraph(element, children)
    Run(children~, properties~) =>
      self.convert_run(element, children, properties)
    Text(value) => [html_text(value)]
    Tab => [html_text("\t")]
    Checkbox(checked) => {
      let attrs : Map[String, String] = { "type": "checkbox", "disabled": "" }
      if checked {
        attrs["checked"] = ""
      }
      [html_element("input", attributes=attrs)]
    }
    Hyperlink(children~, href~, anchor~, target_frame~) => {
      let attrs : Map[String, String] = {}
      match href {
        Some(value) => attrs["href"] = value
        None => ()
      }
      match anchor {
        Some(value) => attrs["href"] = "#" + value
        None => ()
      }
      match target_frame {
        Some(value) => attrs["target"] = value
        None => ()
      }
      [
        html_element(
          "a",
          attributes=attrs,
          children=self.convert_children(children),
        ),
      ]
    }
    Break(Line) =>
      self.wrap_with_style_or_default(element, [html_element("br")])
    Break(_) => []
    BookmarkStart(name) =>
      [html_element("a", attributes={ "id": self.options.id_prefix + name })]
    Table(children~, ..) => self.convert_table(element, children)
    TableRow(children~, is_header~) => {
      let tag = if is_header { "th" } else { "td" }
      ignore(tag)
      [html_element("tr", children=self.convert_children(children), fresh=true)]
    }
    TableCell(children~, col_span~, row_span~) => {
      let attrs : Map[String, String] = {}
      if col_span != 1 {
        attrs["colspan"] = col_span.to_string()
      }
      if row_span != 1 {
        attrs["rowspan"] = row_span.to_string()
      }
      [
        html_element(
          "td",
          attributes=attrs,
          children=self.convert_children(children),
          fresh=true,
        ),
      ]
    }
    Image(image) => [self.convert_image(image)]
    NoteReference(note_type~, note_id~) => {
      let id = self.options.id_prefix + note_type + "-ref-" + note_id
      let href = "#" + self.options.id_prefix + note_type + "-" + note_id
      [
        html_element("sup", children=[
          html_element("a", attributes={ "id": id, "href": href }, children=[
            html_text("[" + note_id + "]"),
          ]),
        ]),
      ]
    }
    CommentReference(comment_id) =>
      self.wrap_with_style_or_default(element, [
        html_text("[" + comment_id + "]"),
      ])
  }
}

///|
fn DocumentConverter::convert_children(
  self : DocumentConverter,
  children : Array[DocumentElement],
) -> Array[HtmlNode] {
  let nodes : Array[HtmlNode] = []
  for child in children {
    nodes.append(self.convert_element(child))
  }
  nodes
}

///|
fn DocumentConverter::convert_paragraph(
  self : DocumentConverter,
  element : DocumentElement,
  children : Array[DocumentElement],
) -> Array[HtmlNode] {
  let content = self.convert_children(children)
  if self.options.ignore_empty_paragraphs && html_nodes_are_empty(content) {
    []
  } else {
    let default_path = [{ tag: "p", attributes: {}, fresh: true }]
    self.wrap_with_style(element, content, default_path)
  }
}

///|
fn DocumentConverter::convert_run(
  self : DocumentConverter,
  element : DocumentElement,
  children : Array[DocumentElement],
  properties : RunProperties,
) -> Array[HtmlNode] {
  let mut nodes = self.convert_children(children)
  let paths : Array[Array[HtmlPathElement]] = []
  match properties.highlight {
    Some(_) =>
      match
        find_style_mapping(
          Run(children~, properties~),
          [
            for mapping in self.options.style_map if mapping.from
            is HighlightMatcher(_) => mapping
          ],
        ) {
        Some(mapping) => paths.push(mapping.to)
        None => ()
      }
    None => ()
  }
  if properties.is_small_caps {
    paths.push(path_for_property(self, element, "smallCaps", None))
  }
  if properties.is_all_caps {
    paths.push(path_for_property(self, element, "allCaps", None))
  }
  if properties.is_strikethrough {
    paths.push(path_for_property(self, element, "strikethrough", Some("s")))
  }
  if properties.is_underline {
    paths.push(path_for_property(self, element, "underline", None))
  }
  match properties.vertical_alignment {
    Superscript => paths.push([{ tag: "sup", attributes: {}, fresh: false }])
    Subscript => paths.push([{ tag: "sub", attributes: {}, fresh: false }])
    Baseline => ()
  }
  if properties.is_italic {
    paths.push(path_for_property(self, element, "italic", Some("em")))
  }
  if properties.is_bold {
    paths.push(path_for_property(self, element, "bold", Some("strong")))
  }
  match find_run_style_mapping(element, self.options.style_map) {
    Some(mapping) => paths.push(mapping.to)
    None => ()
  }
  for path in paths {
    nodes = wrap_html_path(path, nodes)
  }
  nodes
}

///|
fn path_for_property(
  converter : DocumentConverter,
  _element : DocumentElement,
  property : String,
  default_tag : String?,
) -> Array[HtmlPathElement] {
  let matcher = RunPropertyMatcher(property)
  for mapping in converter.options.style_map {
    if mapping.from == matcher {
      return mapping.to
    }
  }
  match default_tag {
    Some(tag) => [{ tag, attributes: {}, fresh: false }]
    None => []
  }
}

///|
fn find_run_style_mapping(
  element : DocumentElement,
  style_map : Array[StyleMapping],
) -> StyleMapping? {
  for mapping in style_map {
    match mapping.from {
      RunMatcher(..) =>
        if mapping.from.matches(element) {
          return Some(mapping)
        }
      _ => ()
    }
  }
  None
}

///|
fn DocumentConverter::convert_table(
  self : DocumentConverter,
  element : DocumentElement,
  children : Array[DocumentElement],
) -> Array[HtmlNode] {
  let rows = self.convert_children(children)
  let default_path = [{ tag: "table", attributes: {}, fresh: true }]
  self.wrap_with_style(element, rows, default_path)
}

///|
fn DocumentConverter::convert_image(
  self : DocumentConverter,
  image : Image,
) -> HtmlNode {
  let attrs : Map[String, String] = {
    "src": "data:" +
    image.content_type +
    ";base64," +
    @base64.encode(image.data[:]),
  }
  match image.alt_text {
    Some(alt) => attrs["alt"] = alt
    None => ()
  }
  ignore(self)
  html_element("img", attributes=attrs)
}

///|
fn DocumentConverter::convert_notes(
  self : DocumentConverter,
  notes : Array[Note],
) -> Array[HtmlNode] {
  let nodes : Array[HtmlNode] = []
  for note in notes {
    nodes.push(
      html_element(
        "p",
        attributes={
          "id": self.options.id_prefix + note.note_type + "-" + note.note_id,
        },
        children=[html_text("[" + note.note_id + "] ")] +
          self.convert_children(note.body),
      ),
    )
  }
  nodes
}

///|
fn DocumentConverter::convert_comments(
  self : DocumentConverter,
  comments : Array[Comment],
) -> Array[HtmlNode] {
  let nodes : Array[HtmlNode] = []
  for comment in comments {
    nodes.push(
      html_element("dl", children=[
        html_element(
          "dt",
          attributes={
            "id": self.options.id_prefix + "comment-" + comment.comment_id,
          },
          children=[html_text("Comment [" + comment.comment_id + "]")],
        ),
        html_element("dd", children=self.convert_children(comment.body)),
      ]),
    )
  }
  nodes
}

///|
fn DocumentConverter::wrap_with_style_or_default(
  self : DocumentConverter,
  element : DocumentElement,
  default_nodes : Array[HtmlNode],
) -> Array[HtmlNode] {
  self.wrap_with_style(element, default_nodes, [])
}

///|
fn DocumentConverter::wrap_with_style(
  self : DocumentConverter,
  element : DocumentElement,
  content : Array[HtmlNode],
  default_path : Array[HtmlPathElement],
) -> Array[HtmlNode] {
  let path = match find_style_mapping(element, self.options.style_map) {
    Some(mapping) => mapping.to
    None => default_path
  }
  wrap_html_path(path, content)
}

///|
fn wrap_html_path(
  path : Array[HtmlPathElement],
  nodes : Array[HtmlNode],
) -> Array[HtmlNode] {
  let mut wrapped = nodes
  for index = path.length() - 1; index >= 0; index = index - 1 {
    let part = path[index]
    wrapped = [
      html_element(
        part.tag,
        attributes=part.attributes,
        children=wrapped,
        fresh=part.fresh,
      ),
    ]
  }
  wrapped
}

///|
fn html_nodes_are_empty(nodes : Array[HtmlNode]) -> Bool {
  for node in nodes {
    match node {
      TextNode(value) => if value != "" { return false }
      ForceWrite => return false
      Element(tag~, children~, ..) =>
        if is_void_html_tag(tag) || !html_nodes_are_empty(children) {
          return false
        }
    }
  }
  true
}

///|
pub fn simplify_html(nodes : Array[HtmlNode]) -> Array[HtmlNode] {
  let result : Array[HtmlNode] = []
  for node in nodes {
    let simplified = simplify_html_node(node)
    append_simplified(result, simplified)
  }
  result
}

///|
fn simplify_html_node(node : HtmlNode) -> HtmlNode {
  match node {
    Element(tag~, attributes~, children~, fresh~) =>
      Element(tag~, attributes~, children=simplify_html(children), fresh~)
    _ => node
  }
}

///|
fn append_simplified(result : Array[HtmlNode], node : HtmlNode) -> Unit {
  if result.length() == 0 {
    result.push(node)
  } else {
    let last_index = result.length() - 1
    match (result[last_index], node) {
      (
        Element(tag=tag_a, attributes=attrs_a, children=children_a, fresh=false),
        Element(tag=tag_b, attributes=attrs_b, children=children_b, fresh=false),
      ) =>
        if tag_a == tag_b && attrs_a == attrs_b {
          let merged = children_a + children_b
          result[last_index] = Element(
            tag=tag_a,
            attributes=attrs_a,
            children=merged,
            fresh=false,
          )
        } else {
          result.push(node)
        }
      _ => result.push(node)
    }
  }
}
