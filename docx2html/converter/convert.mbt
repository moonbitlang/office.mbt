///|
/// Selects whether conversion renders HTML or Markdown.
pub(all) enum OutputFormat {
  Html
  Markdown
} derive(Debug, Eq)

///|
priv struct ConvertOptions {
  style_map : Array[StyleMapping]
  ignore_empty_paragraphs : Bool
  id_prefix : String
}

///|
priv struct ConvertedNodes {
  nodes : Array[HtmlNode]
  messages : Array[Message]
}

///|
/// Rendered image nodes plus any diagnostics from image conversion.
pub(all) struct ImageConversion {
  nodes : Array[HtmlNode]
  messages : Array[Message]
} derive(Debug, Eq)

///|
/// Builds an image conversion result from rendered nodes and diagnostics.
pub fn image_conversion(
  nodes : Array[HtmlNode],
  messages? : Array[Message] = [],
) -> ImageConversion {
  { nodes, messages }
}

///|
/// Converts a document tree to HTML.
pub fn convert_document_to_html(
  document : DocumentElement,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
  convert_image? : (Image) -> ImageConversion = data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = identity_document_transform,
) -> ConversionResult {
  convert_document(
    document,
    output_format=Html,
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
/// Converts a document tree to Markdown.
pub fn convert_document_to_markdown(
  document : DocumentElement,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  convert_image? : (Image) -> ImageConversion = data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = identity_document_transform,
) -> ConversionResult {
  convert_document(
    document,
    output_format=Markdown,
    style_map~,
    include_default_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    convert_image~,
    transform_document~,
  )
}

///|
/// Converts a document tree using the requested output format.
pub fn convert_document(
  document : DocumentElement,
  output_format? : OutputFormat = Html,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
  convert_image? : (Image) -> ImageConversion = data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = identity_document_transform,
) -> ConversionResult {
  let converted = convert_document_to_nodes(
    document,
    style_map~,
    include_default_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    convert_image~,
    transform_document~,
  )
  let nodes = simplify_html(converted.nodes)
  let value = match output_format {
    Html => write_html(nodes, pretty_print~)
    Markdown => write_markdown(nodes)
  }
  { value, messages: converted.messages }
}

///|
fn convert_document_to_nodes(
  document : DocumentElement,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  convert_image? : (Image) -> ImageConversion = data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = identity_document_transform,
) -> ConvertedNodes {
  let document = transform_document(document)
  let all_style_lines : Array[String] = []
  all_style_lines.append(style_map)
  if include_default_style_map {
    all_style_lines.append(default_style_map_lines())
  }
  let parsed_style_map = @style_map.read_style_map_with_messages(
    all_style_lines,
  )
  let options = ConvertOptions::{
    style_map: parsed_style_map.mappings,
    ignore_empty_paragraphs,
    id_prefix,
  }
  let converter = DocumentConverter::{
    options,
    messages: parsed_style_map.messages,
    note_references: [],
    note_number: 1,
    comments: document_comments(document),
    comment_references: [],
    comment_number: 1,
    image_converter: convert_image,
  }
  let nodes = converter.convert_element(document)
  { nodes, messages: @core.dedupe_messages(converter.messages) }
}

///|
priv struct DocumentConverter {
  options : ConvertOptions
  messages : Array[Message]
  note_references : Array[NoteReferenceInfo]
  mut note_number : Int
  comments : Array[Comment]
  comment_references : Array[CommentReferenceInfo]
  mut comment_number : Int
  image_converter : (Image) -> ImageConversion
}

///|
fn document_comments(document : DocumentElement) -> Array[Comment] {
  match document {
    Document(comments~, ..) => comments
    _ => []
  }
}

///|
priv struct NoteReferenceInfo {
  note_type : String
  note_id : String
}

///|
priv struct CommentReferenceInfo {
  comment_id : String
  label : String
}

///|
fn DocumentConverter::convert_element(
  self : DocumentConverter,
  element : DocumentElement,
) -> Array[HtmlNode] {
  match element {
    Document(children~, notes~, comments~) => {
      let nodes = self.convert_children(children)
      let note_nodes = self.convert_referenced_notes(notes)
      let comment_nodes = self.convert_comments(comments)
      nodes + note_nodes + comment_nodes
    }
    Paragraph(children~, properties~) =>
      self.convert_paragraph(element, children, properties)
    Run(children~, properties~) =>
      self.convert_run(element, children, properties)
    Text(value) => [html_text(value)]
    Tab => [html_text("\t")]
    Checkbox(checked) => {
      let attrs : Map[String, String] = { "type": "checkbox" }
      if checked {
        attrs["checked"] = "checked"
      }
      [html_element("input", attributes=attrs)]
    }
    Hyperlink(children~, href~, anchor~, target_frame~) => {
      let attrs : Map[String, String] = Map([])
      match (href, anchor) {
        (Some(value), None) => attrs["href"] = value
        (Some(value), Some(anchor)) =>
          attrs["href"] = replace_url_fragment(value, anchor)
        (None, Some(value)) =>
          attrs["href"] = "#" + self.options.id_prefix + value
        (None, None) => ()
      }
      match target_frame {
        Some(value) => if value != "" { attrs["target"] = value }
        None => ()
      }
      let converted_children = self.convert_children(children)
      if attrs.is_empty() {
        converted_children
      } else {
        [html_element("a", attributes=attrs, children=converted_children)]
      }
    }
    Break(break_type) => self.convert_break(element, break_type)
    BookmarkStart(name) =>
      [
        html_element(
          "a",
          attributes={ "id": self.options.id_prefix + name },
          children=[ForceWrite],
          fresh=true,
        ),
      ]
    Table(children~, properties~) =>
      self.convert_table(element, children, properties)
    TableRow(children~, is_header~) =>
      [self.convert_table_row(children, as_header=is_header)]
    TableCell(children~, col_span~, row_span~) =>
      [self.convert_table_cell(children, col_span~, row_span~, as_header=false)]
    Image(image) => self.convert_image(image)
    NoteReference(note_type~, note_id~) => {
      let label = self.note_number.to_string()
      self.note_number = self.note_number + 1
      self.note_references.push({ note_type, note_id })
      let id = self.options.id_prefix + note_type + "-ref-" + note_id
      let href = "#" + self.options.id_prefix + note_type + "-" + note_id
      [
        html_element("sup", children=[
          html_element("a", attributes={ "href": href, "id": id }, children=[
            html_text("[" + label + "]"),
          ]),
        ]),
      ]
    }
    CommentReference(comment_id) =>
      self.convert_comment_reference(element, comment_id)
  }
}

///|
fn DocumentConverter::convert_break(
  self : DocumentConverter,
  element : DocumentElement,
  break_type : BreakType,
) -> Array[HtmlNode] {
  match @style_map.find_style_mapping(element, self.options.style_map) {
    Some(mapping) => wrap_html_path(mapping.to, [])
    None =>
      match break_type {
        Line => [html_element("br")]
        Page | Column => []
      }
  }
}

///|
fn replace_url_fragment(href : String, fragment : String) -> String {
  let base = match href.find("#") {
    Some(index) => href[:index].to_owned()
    None => href
  }
  base + "#" + fragment
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
  properties : ParagraphProperties,
) -> Array[HtmlNode] {
  let content = self.convert_children(children)
  if self.options.ignore_empty_paragraphs && html_nodes_are_empty(content) {
    []
  } else {
    let default_path : Array[HtmlPathElement] = [
      { tag: "p", attributes: Map([]), fresh: true, separator: None },
    ]
    if @style_map.find_style_mapping(element, self.options.style_map) == None {
      self.warn_unrecognised_style(
        "paragraph",
        properties.style_id,
        properties.style_name,
      )
    }
    let content = if self.options.ignore_empty_paragraphs {
      content
    } else {
      force_write_nodes(content)
    }
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
        @style_map.find_style_mapping(
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
    Superscript =>
      paths.push([
        { tag: "sup", attributes: Map([]), fresh: false, separator: None },
      ])
    Subscript =>
      paths.push([
        { tag: "sub", attributes: Map([]), fresh: false, separator: None },
      ])
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
    None =>
      self.warn_unrecognised_style(
        "run",
        properties.style_id,
        properties.style_name,
      )
  }
  for path in paths {
    nodes = wrap_html_path(path, nodes)
  }
  nodes
}

///|
fn DocumentConverter::warn_unrecognised_style(
  self : DocumentConverter,
  kind : String,
  style_id : String?,
  style_name : String?,
) -> Unit {
  match (style_id, style_name) {
    (Some(id), Some(name)) =>
      self.messages.push(
        Warning(
          "Unrecognised " +
          kind +
          " style: '" +
          name +
          "' (Style ID: " +
          id +
          ")",
        ),
      )
    _ => ()
  }
}

///|
fn path_for_property(
  converter : DocumentConverter,
  _element : DocumentElement,
  property : String,
  default_tag : String?,
) -> Array[HtmlPathElement] {
  let matcher = @style_map.RunPropertyMatcher(property)
  for mapping in converter.options.style_map {
    if mapping.from == matcher {
      return mapping.to
    }
  }
  match default_tag {
    Some(tag) => [{ tag, attributes: Map([]), fresh: false, separator: None }]
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
  properties : TableProperties,
) -> Array[HtmlNode] {
  let rows = force_write_nodes(self.convert_table_children(children))
  let default_path : Array[HtmlPathElement] = [
    { tag: "table", attributes: Map([]), fresh: true, separator: None },
  ]
  ignore(properties)
  self.wrap_with_style(element, rows, default_path)
}

///|
fn DocumentConverter::convert_table_children(
  self : DocumentConverter,
  children : Array[DocumentElement],
) -> Array[HtmlNode] {
  let body_index = first_body_row_index(children)
  if body_index == 0 {
    self.convert_children(children)
  } else {
    [
      html_element(
        "thead",
        children=self.convert_table_segment(
          children,
          start=0,
          end=body_index,
          as_header=true,
        ),
        fresh=true,
      ),
      html_element(
        "tbody",
        children=self.convert_table_segment(
          children,
          start=body_index,
          end=children.length(),
          as_header=false,
        ),
        fresh=true,
      ),
    ]
  }
}

///|
fn first_body_row_index(children : Array[DocumentElement]) -> Int {
  let mut index = 0
  for child in children {
    match child {
      TableRow(is_header=true, ..) => index = index + 1
      _ => return index
    }
  }
  index
}

///|
fn DocumentConverter::convert_table_segment(
  self : DocumentConverter,
  children : Array[DocumentElement],
  start~ : Int,
  end~ : Int,
  as_header~ : Bool,
) -> Array[HtmlNode] {
  let nodes : Array[HtmlNode] = []
  for index in start..<end {
    match children[index] {
      TableRow(children=row_children, ..) =>
        nodes.push(self.convert_table_row(row_children, as_header~))
      other => nodes.append(self.convert_element(other))
    }
  }
  nodes
}

///|
fn DocumentConverter::convert_table_row(
  self : DocumentConverter,
  children : Array[DocumentElement],
  as_header~ : Bool,
) -> HtmlNode {
  let nodes : Array[HtmlNode] = []
  for child in children {
    match child {
      TableCell(children=cell_children, col_span~, row_span~) =>
        nodes.push(
          self.convert_table_cell(
            cell_children,
            col_span~,
            row_span~,
            as_header~,
          ),
        )
      _ => nodes.append(self.convert_element(child))
    }
  }
  html_element("tr", children=force_write_nodes(nodes), fresh=true)
}

///|
fn DocumentConverter::convert_table_cell(
  self : DocumentConverter,
  children : Array[DocumentElement],
  col_span~ : Int,
  row_span~ : Int,
  as_header~ : Bool,
) -> HtmlNode {
  let attrs : Map[String, String] = Map([])
  if col_span != 1 {
    attrs["colspan"] = col_span.to_string()
  }
  if row_span != 1 {
    attrs["rowspan"] = row_span.to_string()
  }
  let tag = if as_header { "th" } else { "td" }
  html_element(
    tag,
    attributes=attrs,
    children=force_write_nodes(self.convert_children(children)),
    fresh=true,
  )
}

///|
fn force_write_nodes(children : Array[HtmlNode]) -> Array[HtmlNode] {
  let nodes = [@html.ForceWrite]
  nodes.append(children)
  nodes
}

///|
fn DocumentConverter::convert_image(
  self : DocumentConverter,
  image : Image,
) -> Array[HtmlNode] {
  let result = (self.image_converter)(image)
  self.messages.append(result.messages)
  result.nodes
}

///|
/// Converts images to inline data URI image nodes.
pub fn data_uri_image_converter(image : Image) -> ImageConversion {
  img_element(fn(image) {
    {
      "src": "data:" +
      image.content_type +
      ";base64," +
      @base64.encode(image.data),
    }
  })(image)
}

///|
/// Converts one image to an inline data URI image result.
pub fn data_uri_image(image : Image) -> ImageConversion {
  data_uri_image_converter(image)
}

///|
/// Creates an image converter that emits an `img` element.
pub fn img_element(
  read_attributes : (Image) -> Map[String, String],
) -> (Image) -> ImageConversion {
  fn(image) {
    let attrs : Map[String, String] = Map([])
    match image.alt_text {
      Some(alt) => attrs["alt"] = alt
      None => ()
    }
    for item in read_attributes(image) {
      let (key, value) = item
      attrs[key] = value
    }
    image_conversion([fresh_html_element("img", attributes=attrs)])
  }
}

///|
/// Alias for `img_element` matching Mammoth image API style.
pub fn inline_image(
  read_attributes : (Image) -> Map[String, String],
) -> (Image) -> ImageConversion {
  img_element(read_attributes)
}

///|
fn DocumentConverter::convert_referenced_notes(
  self : DocumentConverter,
  notes : Array[Note],
) -> Array[HtmlNode] {
  if self.note_references.is_empty() {
    return []
  }
  let items : Array[HtmlNode] = []
  for reference in self.note_references {
    match find_note(notes, reference.note_type, reference.note_id) {
      Some(note) => items.push(self.convert_note(note, reference))
      None => ()
    }
  }
  if items.is_empty() {
    []
  } else {
    [html_element("ol", children=items, fresh=true)]
  }
}

///|
fn find_note(
  notes : Array[Note],
  note_type : String,
  note_id : String,
) -> Note? {
  for note in notes {
    if note.note_type == note_type && note.note_id == note_id {
      return Some(note)
    }
  }
  None
}

///|
fn DocumentConverter::convert_note(
  self : DocumentConverter,
  note : Note,
  _reference : NoteReferenceInfo,
) -> HtmlNode {
  let body = self.convert_children(note.body)
  let backlink = html_element(
    "a",
    attributes={
      "href": "#" +
      self.options.id_prefix +
      note.note_type +
      "-ref-" +
      note.note_id,
    },
    children=[html_text("↑")],
    fresh=true,
  )
  append_note_backlink(body, backlink)
  html_element(
    "li",
    attributes={
      "id": self.options.id_prefix + note.note_type + "-" + note.note_id,
    },
    children=body,
    fresh=true,
  )
}

///|
fn append_note_backlink(nodes : Array[HtmlNode], backlink : HtmlNode) -> Unit {
  if nodes.length() == 0 {
    nodes.push(html_element("p", children=[html_text(" "), backlink]))
  } else {
    let last_index = nodes.length() - 1
    match nodes[last_index] {
      Element(tag="p", attributes~, children~, fresh~, separator~) =>
        nodes[last_index] = Element(
          tag="p",
          attributes~,
          children=children + [html_text(" "), backlink],
          fresh~,
          separator~,
        )
      _ => nodes.push(html_element("p", children=[html_text(" "), backlink]))
    }
  }
}

///|
fn DocumentConverter::convert_comment_reference(
  self : DocumentConverter,
  element : DocumentElement,
  comment_id : String,
) -> Array[HtmlNode] {
  match @style_map.find_style_mapping(element, self.options.style_map) {
    Some(mapping) =>
      match self.find_comment(comment_id) {
        Some(comment) => {
          let label = "[" +
            comment_author_label(comment) +
            self.comment_number.to_string() +
            "]"
          self.comment_number = self.comment_number + 1
          self.comment_references.push({ comment_id, label })
          let id = self.options.id_prefix + "comment-ref-" + comment_id
          let href = "#" + self.options.id_prefix + "comment-" + comment_id
          wrap_html_path(mapping.to, [
            html_element("a", attributes={ "href": href, "id": id }, children=[
              html_text(label),
            ]),
          ])
        }
        None => []
      }
    None => []
  }
}

///|
fn comment_author_label(comment : Comment) -> String {
  comment.author_initials
}

///|
fn DocumentConverter::find_comment(
  self : DocumentConverter,
  comment_id : String,
) -> Comment? {
  for comment in self.comments {
    if comment.comment_id == comment_id {
      return Some(comment)
    }
  }
  None
}

///|
fn DocumentConverter::convert_comments(
  self : DocumentConverter,
  comments : Array[Comment],
) -> Array[HtmlNode] {
  if self.comment_references.is_empty() {
    return []
  }
  let nodes : Array[HtmlNode] = []
  for reference in self.comment_references {
    match find_comment(comments, reference.comment_id) {
      Some(comment) => {
        let body = self.convert_children(comment.body)
        let backlink = html_element(
          "a",
          attributes={
            "href": "#" +
            self.options.id_prefix +
            "comment-ref-" +
            comment.comment_id,
          },
          children=[html_text("↑")],
          fresh=true,
        )
        append_note_backlink(body, backlink)
        nodes.append([
          html_element(
            "dt",
            attributes={
              "id": self.options.id_prefix + "comment-" + comment.comment_id,
            },
            children=[html_text("Comment " + reference.label)],
            fresh=true,
          ),
          html_element("dd", children=body, fresh=true),
        ])
      }
      None => ()
    }
  }
  if nodes.is_empty() {
    []
  } else {
    [html_element("dl", children=nodes, fresh=true)]
  }
}

///|
fn find_comment(comments : Array[Comment], comment_id : String) -> Comment? {
  for comment in comments {
    if comment.comment_id == comment_id {
      return Some(comment)
    }
  }
  None
}

///|
fn DocumentConverter::wrap_with_style(
  self : DocumentConverter,
  element : DocumentElement,
  content : Array[HtmlNode],
  default_path : Array[HtmlPathElement],
) -> Array[HtmlNode] {
  let path = match
    @style_map.find_style_mapping(element, self.options.style_map) {
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
  if path.length() == 1 && path[0].tag == "!" {
    return []
  }
  let mut wrapped = nodes
  for index = path.length() - 1; index >= 0; index = index - 1 {
    let part = path[index]
    wrapped = [
      html_element(
        part.tag,
        attributes=part.attributes,
        children=wrapped,
        fresh=part.fresh,
        separator=part.separator.unwrap_or(""),
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
        if @html.is_void_html_tag(tag) || !html_nodes_are_empty(children) {
          return false
        }
    }
  }
  true
}
