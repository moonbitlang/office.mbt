// Tagged PDF (port of krilla's `interchange::tagging`): content tags for
// marked content, the logical structure tree and its serialization
// (StructTreeRoot, ParentTree, IDTree, RoleMap).

///|
/// The type of an artifact.
#derive(Eq, Debug)
pub(all) enum ArtifactType {
  Header
  Footer
  Watermark
  PageNumber
  LineNumber
  Redaction
  Bates
  PaginationOther
  Layout
  Page
  Background
  Other
}

///|
fn ArtifactType::map_pdf_version(
  self : ArtifactType,
  version : PdfVersion,
) -> ArtifactType {
  match self {
    PageNumber | LineNumber | Redaction | Bates if version < Pdf20 =>
      PaginationOther
    Header | Footer | Watermark if version < Pdf17 => PaginationOther
    Background if version < Pdf17 => Other
    _ => self
  }
}

///|
fn ArtifactType::to_pdf_artifact_type(self : ArtifactType) -> String? {
  match self {
    Header
    | Footer
    | Watermark
    | PageNumber
    | LineNumber
    | Redaction
    | Bates
    | PaginationOther => Some("Pagination")
    Layout => Some("Layout")
    Page => Some("Page")
    Background => Some("Background")
    Other => None
  }
}

///|
fn ArtifactType::to_pdf_artifact_subtype(self : ArtifactType) -> String? {
  match self {
    Header => Some("Header")
    Footer => Some("Footer")
    Watermark => Some("Watermark")
    PageNumber => Some("PageNum")
    LineNumber => Some("LineNum")
    Redaction => Some("Redaction")
    Bates => Some("Bates")
    _ => None
  }
}

///|
/// An artifact.
pub(all) struct Artifact {
  kind : ArtifactType
  bbox : Rect?
}

///|
fn Artifact::requires_properties(self : Artifact, version : PdfVersion) -> Bool {
  self.bbox is Some(_) ||
  self.kind.map_pdf_version(version).to_pdf_artifact_type() is Some(_)
}

///|
/// The properties of a marked-content span.
pub(all) struct SpanTag {
  lang : String?
  alt_text : String?
  expanded : String?
  actual_text : String?
}

///|
pub fn SpanTag::empty() -> SpanTag {
  { lang: None, alt_text: None, expanded: None, actual_text: None, }
}

///|
/// A tag for marked content.
pub(all) enum ContentTag {
  Artifact(Artifact)
  Span(SpanTag)
  Other
}

///|
fn ContentTag::name(self : ContentTag) -> String {
  match self {
    Artifact(_) => "Artifact"
    Span(_) => "Span"
    Other => "P"
  }
}

///|
fn ContentTag::write_properties(
  self : ContentTag,
  sc : SerializeContext,
  props : DictBuilder,
  page_height : Double,
) -> Unit {
  let version = sc.settings.pdf_version()
  match self {
    Artifact(artifact) => {
      let at = artifact.kind.map_pdf_version(version)
      if artifact.bbox is Some(bbox) {
        let r = bbox.transform(page_root_transform(page_height))
        props.set("BBox", r.to_pdf())
      }
      if version >= Pdf17 {
        if at == Header {
          props.set("Attached", Arr([Name("Top")]))
        }
        if at == Footer {
          props.set("Attached", Arr([Name("Bottom")]))
        }
        if at.to_pdf_artifact_subtype() is Some(st) {
          props.set("Subtype", Name(st))
        }
      }
      if at.to_pdf_artifact_type() is Some(t) {
        props.set("Type", Name(t))
      }
    }
    Span(span) => {
      if span.lang is Some(l) {
        props.set("Lang", TextStr(l))
      }
      if span.alt_text is Some(a) && version >= Pdf15 {
        props.set("Alt", TextStr(a))
      }
      if span.expanded is Some(e) {
        props.set("E", TextStr(e))
      }
      if span.actual_text is Some(t) && version >= Pdf15 {
        props.set("ActualText", TextStr(t))
      }
    }
    Other => ()
  }
}

///|
/// Identifies a piece of content in the structure tree.
#derive(Eq, Debug)
pub(all) enum Identifier {
  /// Marked content on a page: page index and MCID.
  PageContent(Int32, Int32)
  /// An annotation: page index and annotation index.
  Annotation(Int32, Int32)
  /// Marked content in a layer (a form XObject drawn on a page): page index,
  /// stream ID and MCID within the stream.
  StreamContent(Int32, Int32, Int32)
  /// Content that is not part of the structure tree.
  Dummy
}

///|
priv struct AnnotationIdentifier {
  page_index : Int32
  annot_index : Int32
}

///|
/// The kind of a structure element.
#derive(Eq, Debug)
pub(all) enum TagName {
  Part
  Article
  Section
  Div
  BlockQuote
  Caption
  TOC
  TOCI
  Index
  P
  Hn
  L
  LI
  Lbl
  LBody
  Table
  TR
  TH
  TD
  THead
  TBody
  TFoot
  Span
  InlineQuote
  Note
  Reference
  BibEntry
  Code
  Link
  Annot
  Figure
  Formula
  Form
  NonStruct
  Datetime
  Terms
  Title
  Strong
  Em
}

///|
/// The numbering of a list.
#derive(Eq, Debug)
pub(all) enum ListNumbering {
  NoNumbering
  Disc
  Circle
  Square
  Decimal
  LowerRoman
  UpperRoman
  LowerAlpha
  UpperAlpha
}

///|
fn ListNumbering::name(self : ListNumbering) -> String {
  match self {
    NoNumbering => "None"
    Disc => "Disc"
    Circle => "Circle"
    Square => "Square"
    Decimal => "Decimal"
    LowerRoman => "LowerRoman"
    UpperRoman => "UpperRoman"
    LowerAlpha => "LowerAlpha"
    UpperAlpha => "UpperAlpha"
  }
}

///|
/// The scope of a table header cell.
#derive(Eq, Debug)
pub(all) enum TableHeaderScope {
  Row
  Column
  Both
}

///|
/// The placement of a structure element.
#derive(Eq, Debug)
pub(all) enum Placement {
  Block
  Inline
  Before
  Start
  End
}

///|
/// A border style.
#derive(Eq, Debug)
pub(all) enum BorderStyle {
  NoBorder
  Hidden
  Solid
  Dashed
  Dotted
  Double
  Groove
  Ridge
  Inset
  Outset
}

///|
fn BorderStyle::name(self : BorderStyle) -> String {
  match self {
    NoBorder => "None"
    Hidden => "Hidden"
    Solid => "Solid"
    Dashed => "Dashed"
    Dotted => "Dotted"
    Double => "Double"
    Groove => "Groove"
    Ridge => "Ridge"
    Inset => "Inset"
    Outset => "Outset"
  }
}

///|
/// The line height of a structure element.
#derive(Eq, Debug)
pub(all) enum LineHeight {
  NormalHeight
  AutoHeight
  CustomHeight(Double)
}

///|
/// A text decoration type.
#derive(Eq, Debug)
pub(all) enum TextDecorationType {
  NoDecoration
  Underline
  Overline
  LineThrough
}

///|
/// Values for the four sides `[before after start end]`.
#derive(Eq, Debug)
pub(all) struct Sides[T] {
  before : T
  after : T
  start : T
  end : T
}

///|
pub fn[T] Sides::uniform(v : T) -> Sides[T] {
  { before: v, after: v, start: v, end: v, }
}

///|
fn[T : Eq] Sides::to_obj(self : Sides[T], f : (T) -> Obj) -> Obj {
  if self.before == self.after &&
    self.before == self.start &&
    self.before == self.end {
    f(self.before)
  } else {
    Arr([f(self.before), f(self.after), f(self.start), f(self.end)])
  }
}

///|
/// An RGB color with 8-bit components.
#derive(Eq, Debug)
pub(all) struct NaiveRgbColor {
  red : Int32
  green : Int32
  blue : Int32
}

///|
fn NaiveRgbColor::to_obj(self : NaiveRgbColor) -> Obj {
  Arr([
    Real(self.red.to_double() / 255.0),
    Real(self.green.to_double() / 255.0),
    Real(self.blue.to_double() / 255.0),
  ])
}

///|
/// An attribute of a structure element.
pub(all) enum Attr {
  // Structure attributes.
  Id(Bytes)
  Lang(String)
  AltText(String)
  Expanded(String)
  ActualText(String)
  Title(String)
  HeadingLevel(Int32)
  // List attributes.
  ListNumbering(ListNumbering)
  // Table attributes.
  Summary(String)
  HeaderScope(TableHeaderScope)
  CellHeaders(Array[Bytes])
  RowSpan(Int32)
  ColSpan(Int32)
  // Layout attributes.
  Placement(Placement)
  BBox(Int32, Rect)
  Width(Double)
  Height(Double)
  BackgroundColor(NaiveRgbColor)
  BorderColor(Sides[NaiveRgbColor])
  BorderStyle(Sides[BorderStyle])
  BorderThickness(Sides[Double])
  Padding(Sides[Double])
  Color(NaiveRgbColor)
  BaselineShift(Double)
  LineHeight(LineHeight)
  TextDecorationColor(NaiveRgbColor)
  TextDecorationThickness(Double)
  TextDecorationType(TextDecorationType)
}

///|
fn Attr::ordinal(self : Attr) -> Int32 {
  match self {
    Id(_) => 0
    Lang(_) => 1
    AltText(_) => 2
    Expanded(_) => 3
    ActualText(_) => 4
    Title(_) => 5
    HeadingLevel(_) => 6
    ListNumbering(_) => 7
    Summary(_) => 8
    HeaderScope(_) => 9
    CellHeaders(_) => 10
    RowSpan(_) => 11
    ColSpan(_) => 12
    Placement(_) => 13
    BBox(_, _) => 14
    Width(_) => 15
    Height(_) => 16
    BackgroundColor(_) => 17
    BorderColor(_) => 18
    BorderStyle(_) => 19
    BorderThickness(_) => 20
    Padding(_) => 21
    Color(_) => 22
    BaselineShift(_) => 23
    LineHeight(_) => 24
    TextDecorationColor(_) => 25
    TextDecorationThickness(_) => 26
    TextDecorationType(_) => 27
  }
}

///|
/// A structure element kind with its attributes.
pub(all) struct TagKind {
  name : TagName
  attrs : Array[Attr]
  mut location : Location?
}

///|
pub fn TagKind::new(name : TagName) -> TagKind {
  { name, attrs: [], location: None, }
}

///|
/// Set an attribute (replacing one of the same kind).
pub fn TagKind::set(self : TagKind, attr : Attr) -> Unit {
  let o = attr.ordinal()
  for i, item in self.attrs {
    if item.ordinal() == o {
      self.attrs[i] = attr
      return
    }
    if item.ordinal() > o {
      self.attrs.insert(i, attr)
      return
    }
  }
  self.attrs.push(attr)
}

///|
/// Remove the attribute with the ordinal of `attr`.
pub fn TagKind::remove_like(self : TagKind, attr : Attr) -> Unit {
  let o = attr.ordinal()
  for i, item in self.attrs {
    if item.ordinal() == o {
      self.attrs.remove(i) |> ignore
      return
    }
  }
}

///|
pub fn TagKind::with_attr(self : TagKind, attr : Attr) -> TagKind {
  self.set(attr)
  self
}

///|
pub fn TagKind::get_lang(self : TagKind) -> String? {
  for a in self.attrs {
    if a is Lang(l) {
      return Some(l)
    }
  }
  None
}

///|
pub fn TagKind::get_id(self : TagKind) -> Bytes? {
  for a in self.attrs {
    if a is Id(id) {
      return Some(id)
    }
  }
  None
}

///|
pub fn TagKind::heading_level(self : TagKind) -> Int32 {
  for a in self.attrs {
    if a is HeadingLevel(l) {
      return l
    }
  }
  1
}

///|
fn TagKind::title(self : TagKind) -> String? {
  for a in self.attrs {
    if a is Title(t) {
      return Some(t)
    }
  }
  None
}

///|
pub fn TagKind::alt_text(self : TagKind) -> String? {
  for a in self.attrs {
    if a is AltText(t) {
      return Some(t)
    }
  }
  None
}

///|
fn TagName::minimum_version(self : TagName) -> PdfVersion {
  match self {
    THead | TBody | TFoot | Annot => Pdf15
    _ => Pdf14
  }
}

///|
/// The structure type written for the kind (PDF 1.x role names).
fn TagKind::role(self : TagKind, sc : SerializeContext) -> String {
  if sc.settings.pdf_version() < self.name.minimum_version() {
    return "P"
  }
  match self.name {
    Part => "Part"
    Article => "Art"
    Section => "Sect"
    Div => "Div"
    BlockQuote => "BlockQuote"
    Caption => "Caption"
    TOC => "TOC"
    TOCI => "TOCI"
    Index => "Index"
    P => "P"
    L => "L"
    LI => "LI"
    Lbl => "Lbl"
    LBody => "LBody"
    Table => "Table"
    TR => "TR"
    TH => "TH"
    TD => "TD"
    THead => "THead"
    TBody => "TBody"
    TFoot => "TFoot"
    Span => "Span"
    InlineQuote => "Quote"
    Note => "Note"
    Reference => "Reference"
    BibEntry => "BibEntry"
    Code => "Code"
    Link => "Link"
    Annot => "Annot"
    Figure => "Figure"
    Formula => "Formula"
    Form => "Form"
    NonStruct => "NonStruct"
    Datetime => "Datetime"
    Terms => "Terms"
    Title => "Title"
    Strong => "Strong"
    Em => "Em"
    Hn => {
      let level = self.heading_level()
      if level > 6 {
        sc.custom_heading_roles[level] = ()
      }
      "H\{level}"
    }
  }
}

///|
/// A node of the structure tree.
pub(all) enum Node {
  Group(TagGroup)
  Leaf(Identifier)
}

///|
/// A structure element with its children.
pub(all) struct TagGroup {
  tag : TagKind
  children : Array[Node]
}

///|
pub fn TagGroup::new(tag : TagKind) -> TagGroup {
  { tag, children: [], }
}

///|
pub fn TagGroup::with_children(
  tag : TagKind,
  children : Array[Node],
) -> TagGroup {
  { tag, children, }
}

///|
pub fn TagGroup::push(self : TagGroup, child : Node) -> Unit {
  self.children.push(child)
}

///|
/// The structure tree.
pub(all) struct TagTree {
  children : Array[Node]
  mut lang : String?
}

///|
pub fn TagTree::new() -> TagTree {
  { children: [], lang: None, }
}

///|
pub fn TagTree::push(self : TagTree, child : Node) -> Unit {
  self.children.push(child)
}

///|
priv struct TagSerializer {
  sc : SerializeContext
  /// The parent structure element of each piece of marked content that a
  /// page gave out, by page index and marked content ID (zero: none; object
  /// numbers start at one): for every page of the document, as many slots
  /// as the page counted marked content IDs. Not upstream, where this is a
  /// part of the map below: a document has an entry per text run, and a
  /// table by page is found without a key to build and to hash.
  page_parents : Array[FixedArray[Int32]]
  /// The parent structure element of each other piece of content, and of
  /// page content with an ID that its page did not give out (an identifier
  /// is a public value).
  parent_tree_map : Map[String, Int32]
  /// The structure elements by ID.
  id_tree : Map[Bytes, Int32]
  mut note_id : Int32
}

///|
/// The table of [TagSerializer::page_parents] for the pages of a document:
/// what every page counted is known when the tag tree is serialized.
fn SerializeContext::new_page_parents(
  self : SerializeContext,
) -> Array[FixedArray[Int32]] {
  let table : Array[FixedArray[Int32]] = Array::make(self.page_infos.length(), [])
  for parent in self.struct_parents {
    if parent is Page(page_index, num_mcids) &&
      page_index >= 0 &&
      page_index < table.length() &&
      num_mcids > table[page_index].length() {
      table[page_index] = FixedArray::make(num_mcids, 0)
    }
  }
  table
}

///|
fn identifier_key(id : Identifier) -> String {
  match id {
    PageContent(p, m) => "p\{p}:\{m}"
    StreamContent(_, s, m) => "s\{s}:\{m}"
    Annotation(p, a) => "a\{p}:\{a}"
    Dummy => "d"
  }
}

///|
/// The parent of a piece of marked content of a page, or zero if it has
/// none (no object has the number zero).
fn TagSerializer::page_parent(
  self : TagSerializer,
  page_index : Int32,
  mcid : Int32,
) -> Int32 {
  if page_index >= 0 && page_index < self.page_parents.length() {
    let parents = self.page_parents[page_index]
    if mcid >= 0 && mcid < parents.length() {
      return parents[mcid]
    }
  }
  match
    self.parent_tree_map.get(identifier_key(PageContent(page_index, mcid))) {
    Some(parent) => parent
    None => 0
  }
}

///|
/// Note the parent of a piece of marked content of a page.
fn TagSerializer::set_page_parent(
  self : TagSerializer,
  page_index : Int32,
  mcid : Int32,
  parent_ref : Int32,
) -> Unit {
  if page_index >= 0 && page_index < self.page_parents.length() {
    let parents = self.page_parents[page_index]
    if mcid >= 0 && mcid < parents.length() {
      parents[mcid] = parent_ref
      return
    }
  }
  self.parent_tree_map[identifier_key(PageContent(page_index, mcid))] = parent_ref
}

///|
/// Serialize the groups among the children of a structure element; returns
/// their references in order (the other children, content, are written by
/// [TagSerializer::children]).
fn TagSerializer::child_groups(
  self : TagSerializer,
  nodes : Array[Node],
  parent : Int32,
) -> Array[Int32] raise ExportError {
  let refs = []
  for node in nodes {
    if node is Group(g) {
      refs.push(self.group(g, parent))
    }
  }
  refs
}

///|
fn TagSerializer::group(
  self : TagSerializer,
  group : TagGroup,
  parent_ref : Int32,
) -> Int32 raise ExportError {
  let sc = self.sc
  let elem_ref = sc.new_ref()
  let group_refs = self.child_groups(group.children, elem_ref)
  let tag = group.tag
  let d = DictBuilder::new()
  d.set("Type", Name("StructElem"))
  d.set("S", Name(tag.role(sc)))
  d.set("P", Ref(parent_ref))
  let version = sc.settings.pdf_version()
  match tag.get_id() {
    Some(id) => {
      if self.id_tree.contains(id) {
        raise DuplicateTagId(id, tag.location)
      }
      d.set("ID", Str(id))
      self.id_tree[id] = elem_ref
    }
    None =>
      if tag.name == Note {
        let id = utf8_bytes("Note \{self.note_id}")
        d.set("ID", Str(id))
        self.id_tree[id] = elem_ref
        self.note_id += 1
      }
  }
  if tag.name == Hn {
    match tag.title() {
      None => sc.register_validation_error(MissingHeadingTitle)
      Some(t) =>
        if t.is_empty() {
          sc.register_validation_error(MissingHeadingTitle)
        }
    }
  }
  if tag.name == Figure || tag.name == Formula {
    match tag.alt_text() {
      None => sc.register_validation_error(MissingAltText(tag.location))
      Some(t) =>
        if t.is_empty() {
          sc.register_validation_error(MissingAltText(tag.location))
        }
    }
  }
  for attr in tag.attrs {
    match attr {
      Title(t) => d.set("T", TextStr(t))
      Lang(l) => d.set("Lang", TextStr(l))
      AltText(a) => d.set("Alt", TextStr(a))
      Expanded(e) => if version >= Pdf15 { d.set("E", TextStr(e)) }
      ActualText(t) => d.set("ActualText", TextStr(t))
      _ => ()
    }
  }
  // (Which owners the element has attributes of, so that the dictionary of
  // an owner without one, which most elements are for every owner, is not
  // started.)
  let mut has_list = false
  let mut has_table = false
  let mut has_layout = false
  for attr in tag.attrs {
    match attr {
      ListNumbering(_) => has_list = true
      Summary(_) | HeaderScope(_) | CellHeaders(_) | RowSpan(_) | ColSpan(_) =>
        has_table = true
      Placement(_)
      | BBox(_, _)
      | Width(_)
      | Height(_)
      | BackgroundColor(_)
      | BorderColor(_)
      | BorderStyle(_)
      | BorderThickness(_)
      | Padding(_)
      | Color(_)
      | BaselineShift(_)
      | LineHeight(_)
      | TextDecorationColor(_)
      | TextDecorationThickness(_)
      | TextDecorationType(_) => has_layout = true
      Id(_)
      | Lang(_)
      | AltText(_)
      | Expanded(_)
      | ActualText(_)
      | Title(_)
      | HeadingLevel(_) => ()
    }
  }
  if has_list || has_table || has_layout {
    let attributes = []
    // List attributes.
    if has_list {
      let list = DictBuilder::new()
      for attr in tag.attrs {
        if attr is ListNumbering(n) {
          list.set("ListNumbering", Name(n.name()))
        }
      }
      if !list.entries().is_empty() {
        attributes.push(Dict([("O", Name("List")), ..list.entries()]))
      }
    }
    // Table attributes.
    if has_table {
      self.table_attributes(tag, attributes)
    }
    // Layout attributes.
    if has_layout {
      self.layout_attributes(tag, attributes)
    }
    if !attributes.is_empty() {
      d.set("A", Arr(attributes))
    }
  }
  self.children(elem_ref, group.children, group_refs, d)
  sc.put(elem_ref, d.finish())
  elem_ref
}

///|
/// The attributes of a structure element whose owner is `Table`, if it has
/// any that are written.
fn TagSerializer::table_attributes(
  self : TagSerializer,
  tag : TagKind,
  attributes : Array[Obj],
) -> Unit {
  let sc = self.sc
  let version = sc.settings.pdf_version()
  let table = DictBuilder::new()
  for attr in tag.attrs {
    match attr {
      Summary(s) => if version >= Pdf17 { table.set("Summary", TextStr(s)) }
      HeaderScope(scope) =>
        if version >= TableHeaderScope.minimum_pdf_version() {
          table.set(
            "Scope",
            Name(
              match scope {
                Row => "Row"
                Column => "Column"
                Both => "Both"
              },
            ),
          )
        } else if scope == Row {
          sc.register_validation_error(
            RequiresNewerPdfVersion(TableHeaderScope, tag.location),
          )
        }
      CellHeaders(headers) =>
        if version >= Pdf15 {
          table.set("Headers", Arr(headers.map(h => Str(h))))
        }
      RowSpan(n) => table.set("RowSpan", Int(n))
      ColSpan(n) => table.set("ColSpan", Int(n))
      _ => ()
    }
  }
  if !table.entries().is_empty() {
    attributes.push(Dict([("O", Name("Table")), ..table.entries()]))
  }
}

///|
/// The attributes of a structure element whose owner is `Layout`, if it
/// has any that are written.
fn TagSerializer::layout_attributes(
  self : TagSerializer,
  tag : TagKind,
  attributes : Array[Obj],
) -> Unit {
  let sc = self.sc
  let version = sc.settings.pdf_version()
  let layout = DictBuilder::new()
  let pdf15 = version >= Pdf15
  for attr in tag.attrs {
    match attr {
      Placement(p) =>
        layout.set(
          "Placement",
          Name(
            match p {
              Block => "Block"
              Inline => "Inline"
              Before => "Before"
              Start => "Start"
              End => "End"
            },
          ),
        )
      BBox(page_idx, rect) => {
        guard sc.page_infos.get(page_idx) is Some(info) else {
          abort(
            "tag tree contains bounding box with page index \{page_idx}, but document only has \{sc.page_infos.length()} pages",
          )
        }
        let r = rect.transform(page_root_transform(info.surface_size.height))
        layout.set("BBox", r.to_pdf())
      }
      Width(w) => layout.set("Width", Real(w))
      Height(h) => layout.set("Height", Real(h))
      BackgroundColor(c) =>
        if pdf15 {
          layout.set("BackgroundColor", c.to_obj())
        }
      BorderColor(s) =>
        if pdf15 {
          layout.set("BorderColor", s.to_obj(c => c.to_obj()))
        }
      BorderStyle(s) =>
        if pdf15 {
          layout.set("BorderStyle", s.to_obj(b => Name(b.name())))
        }
      BorderThickness(s) =>
        if pdf15 {
          layout.set("BorderThickness", s.to_obj(v => Real(v)))
        }
      Padding(s) => if pdf15 { layout.set("Padding", s.to_obj(v => Real(v))) }
      Color(c) => if pdf15 { layout.set("Color", c.to_obj()) }
      BaselineShift(v) => layout.set("BaselineShift", Real(v))
      LineHeight(h) =>
        layout.set(
          "LineHeight",
          match h {
            NormalHeight => Name("Normal")
            AutoHeight => Name("Auto")
            CustomHeight(v) => Real(v)
          },
        )
      TextDecorationColor(c) =>
        if pdf15 {
          layout.set("TextDecorationColor", c.to_obj())
        }
      TextDecorationThickness(v) =>
        if pdf15 {
          layout.set("TextDecorationThickness", Real(v))
        }
      TextDecorationType(t) =>
        if pdf15 {
          layout.set(
            "TextDecorationType",
            Name(
              match t {
                NoDecoration => "None"
                Underline => "Underline"
                Overline => "Overline"
                LineThrough => "LineThrough"
              },
            ),
          )
        }
      _ => ()
    }
  }
  if !layout.entries().is_empty() {
    attributes.push(Dict([("O", Name("Layout")), ..layout.entries()]))
  }
}

///|
/// Write the children of a structure element: `nodes` in their order,
/// with `group_refs` as the references of the groups among them
/// ([TagSerializer::child_groups]).
fn TagSerializer::children(
  self : TagSerializer,
  parent_ref : Int32,
  nodes : Array[Node],
  group_refs : Array[Int32],
  d : DictBuilder,
) -> Unit {
  let sc = self.sc
  // (Zero: none yet. `struct_page_ref : Option<Ref>` upstream.)
  let mut struct_page_ref = 0
  let mut next_group = 0
  let kids = []
  for node in nodes {
    match node {
      Group(_) => {
        kids.push(Ref(group_refs[next_group]))
        next_group += 1
      }
      Leaf(PageContent(page_index, mcid) as id) => {
        guard sc.page_infos.get(page_index) is Some(info) else {
          abort(
            "tag tree contains identifier from page \{page_index + 1}, but document only has \{sc.page_infos.length()} pages",
          )
        }
        let page_ref = info.ref_
        if struct_page_ref == 0 {
          struct_page_ref = page_ref
        }
        if self.page_parent(page_index, mcid) != 0 {
          abort("the identifier \{Repr(id)} appears twice in the tag tree")
        }
        self.set_page_parent(page_index, mcid, parent_ref)
        if struct_page_ref == page_ref {
          kids.push(Int(mcid))
        } else {
          kids.push(
            Dict([
              ("Type", Name("MCR")),
              ("Pg", Ref(page_ref)),
              ("MCID", Int(mcid)),
            ]),
          )
        }
      }
      Leaf(StreamContent(page_index, stream_id, mcid) as id) => {
        guard sc.page_infos.get(page_index) is Some(info) else {
          abort(
            "tag tree contains identifier from page \{page_index + 1}, but document only has \{sc.page_infos.length()} pages",
          )
        }
        guard sc.tag_stream_refs.get(stream_id) is Some(stream_ref) else {
          abort(
            "the identifier \{Repr(id)} belongs to a layer that was not drawn",
          )
        }
        let key = identifier_key(id)
        if self.parent_tree_map.contains(key) {
          abort("the identifier \{Repr(id)} appears twice in the tag tree")
        }
        self.parent_tree_map[key] = parent_ref
        kids.push(
          Dict([
            ("Type", Name("MCR")),
            ("Pg", Ref(info.ref_)),
            ("Stm", Ref(stream_ref)),
            ("MCID", Int(mcid)),
          ]),
        )
      }
      Leaf(Annotation(page_index, annot_index) as id) => {
        guard sc.page_infos.get(page_index) is Some(info) else {
          abort("tag tree contains an annotation from a missing page")
        }
        let page_ref = info.ref_
        guard info.annotations.get(annot_index) is Some((annot_ref, _)) else {
          abort("tag tree contains a missing annotation")
        }
        let key = identifier_key(id)
        if self.parent_tree_map.contains(key) {
          abort("identifier \{Repr(id)} appears twice in the tag tree")
        }
        self.parent_tree_map[key] = annot_ref
        info.annotations[annot_index] = (annot_ref, Some(parent_ref))
        kids.push(
          Dict([
            ("Type", Name("OBJR")),
            ("Pg", Ref(page_ref)),
            ("Obj", Ref(annot_ref)),
          ]),
        )
      }
      Leaf(Dummy) => ()
    }
  }
  d.set("K", Arr(kids))
  if struct_page_ref != 0 {
    d.set("Pg", Ref(struct_page_ref))
  }
}

///|
fn TagSerializer::validate(
  self : TagSerializer,
  nodes : Array[Node],
) -> Unit raise ExportError {
  for child in nodes {
    if child is Group(g) {
      // The headers of the element (krilla `tag.headers()`: its first
      // `CellHeaders` attribute).
      for attr in g.tag.attrs {
        if attr is CellHeaders(headers) {
          for id in headers {
            if !self.id_tree.contains(id) {
              raise UnknownTagId(id, g.tag.location)
            }
          }
          break
        }
      }
      self.validate(g.children)
    }
  }
}

///|
/// Serialize the structure tree; returns the reference of the
/// StructTreeRoot.
fn SerializeContext::serialize_tag_tree(
  self : SerializeContext,
  tree : TagTree,
) -> Int32 raise ExportError {
  let ts = TagSerializer::{
    sc: self,
    page_parents: self.new_page_parents(),
    parent_tree_map: {},
    id_tree: {},
    note_id: 1,
  }
  let struct_tree_root_ref = self.new_ref()
  let root_ref = self.new_ref()
  let group_refs = ts.child_groups(tree.children, root_ref)
  let doc = DictBuilder::new()
  doc.set("Type", Name("StructElem"))
  doc.set("S", Name("Document"))
  doc.set("P", Ref(struct_tree_root_ref))
  if tree.lang is Some(lang) {
    doc.set("Lang", TextStr(lang))
  }
  ts.children(root_ref, tree.children, group_refs, doc)
  self.put(root_ref, doc.finish())
  ts.validate(tree.children)
  let d = DictBuilder::new()
  d.set("Type", Name("StructTreeRoot"))
  // Role map for custom structure types.
  let role_map = [
    ("Datetime", Name("Span")),
    ("Terms", Name("Part")),
    ("Title", Name("P")),
    ("Strong", Name("Span")),
    ("Em", Name("Span")),
  ]
  let levels = self.custom_heading_roles.keys().collect()
  levels.sort()
  for level in levels {
    role_map.push(("H\{level}", Name("P")))
  }
  d.set("RoleMap", Dict(role_map))
  d.set("K", Arr([Ref(root_ref)]))
  if !self.struct_parents.is_empty() {
    let nums = []
    for index, sp in self.struct_parents {
      match sp {
        Page(page_index, num_mcids) => {
          let list_ref = self.new_ref()
          let refs = []
          for mcid in 0..<num_mcids {
            let parent = ts.page_parent(page_index, mcid)
            if parent == 0 {
              abort(
                "page tag identifier \{page_index}:\{mcid} doesn't appear in the tag tree",
              )
            }
            refs.push(Ref(parent))
          }
          self.put(list_ref, Arr(refs))
          nums.push(Int(index))
          nums.push(Ref(list_ref))
        }
        Stream(stream_id, num_mcids) => {
          let list_ref = self.new_ref()
          let refs = []
          for mcid in 0..<num_mcids {
            match
              ts.parent_tree_map.get(
                identifier_key(StreamContent(0, stream_id, mcid)),
              ) {
              Some(r) => refs.push(Ref(r))
              None =>
                abort(
                  "layer tag identifier \{stream_id}:\{mcid} doesn't appear in the tag tree",
                )
            }
          }
          self.put(list_ref, Arr(refs))
          nums.push(Int(index))
          nums.push(Ref(list_ref))
        }
        Annotation(ai) => {
          let info = self.page_infos[ai.page_index]
          match info.annotations[ai.annot_index].1 {
            Some(parent) => {
              nums.push(Int(index))
              nums.push(Ref(parent))
            }
            None =>
              abort("annotation identifier doesn't appear in the tag tree")
          }
        }
      }
    }
    d.set("ParentTree", Dict([("Nums", Arr(nums))]))
  }
  if !ts.id_tree.is_empty() {
    let entries = ts.id_tree.to_array()
    entries.sort_by((a, b) => compare_bytes(a.0, b.0))
    let names = []
    for e in entries {
      names.push(Str(e.0))
      names.push(Ref(e.1))
    }
    d.set("IDTree", Dict([("Names", Arr(names))]))
  }
  if !self.struct_parents.is_empty() {
    d.set("ParentTreeNextKey", Int(self.struct_parents.length()))
  }
  self.put(struct_tree_root_ref, d.finish())
  struct_tree_root_ref
}

///|
fn compare_bytes(a : Bytes, b : Bytes) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return a[i].to_int() - b[i].to_int()
    }
  }
  a.length() - b.length()
}
