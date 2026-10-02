// Destinations, actions, annotations, outlines, page labels, metadata and
// embedded files (port of krilla's `interactive` and `interchange`
// modules, without tagging).

///|
/// A destination pointing to a point on a page (top-left origin).
pub(all) struct XyzDestination {
  page_index : Int
  point : Point
} derive(Eq, Show)

///|
pub fn XyzDestination::new(page_index : Int, point : Point) -> XyzDestination {
  { page_index, point, }
}

///|
/// A named destination.
pub(all) struct NamedDestination {
  name : String
  xyz_dest : XyzDestination
} derive(Eq, Show)

///|
pub fn NamedDestination::new(
  name : String,
  xyz_dest : XyzDestination,
) -> NamedDestination {
  { name, xyz_dest, }
}

///|
/// A destination.
pub(all) enum Destination {
  Xyz(XyzDestination)
  Named(NamedDestination)
} derive(Eq, Show)

///|
fn Destination::to_obj(
  self : Destination,
  sc : SerializeContext,
) -> Obj raise ExportError {
  match self {
    Xyz(xyz) => Ref(sc.register_xyz_destination(xyz))
    Named(nd) => {
      if sc.register_named_destination(nd) is None {
        raise DuplicateNamedDestination(nd.name)
      }
      Str(utf8_bytes(nd.name))
    }
  }
}

///|
/// An action.
pub(all) enum Action {
  /// A link to a URI.
  Link(String)
} derive(Eq, Show)

///|
/// The target of a link.
pub(all) enum Target {
  Destination(Destination)
  Action(Action)
} derive(Eq, Show)

///|
/// A link annotation.
pub(all) struct LinkAnnotation {
  rect : Rect
  quad_points : Array[Array[Point]]?
  target : Target
}

///|
pub fn LinkAnnotation::new(rect : Rect, target : Target) -> LinkAnnotation {
  { rect, quad_points: None, target, }
}

///|
/// A link annotation from quadrilaterals (each four points).
pub fn LinkAnnotation::new_with_quad_points(
  quads : Array[Array[Point]],
  target : Target,
) -> LinkAnnotation {
  let pts = []
  for q in quads {
    for p in q {
      pts.push(p)
    }
  }
  let b = bbox_of_points(pts[:]).unwrap()
  // Expand the bounding box by a little (Acrobat bug).
  let eps = 0.001
  {
    rect: {
      left: b.left - eps,
      top: b.top - eps,
      right: b.right + eps,
      bottom: b.bottom + eps,
    },
    quad_points: Some(quads),
    target,
  }
}

///|
/// An annotation.
pub(all) struct Annotation {
  link : LinkAnnotation
  alt : String?
  mut struct_parent : Int?
  location : Location?
}

///|
pub fn Annotation::new_link(
  link : LinkAnnotation,
  alt : String?,
  location? : Location? = None,
) -> Annotation {
  { link, alt, struct_parent: None, location, }
}

///|
fn page_root_transform(height : Double) -> Transform {
  Transform::from_row(1.0, 0.0, 0.0, -1.0, 0.0, height)
}

///|
fn Annotation::serialize(
  self : Annotation,
  sc : SerializeContext,
  root_ref : Int,
  page_height : Double,
) -> Unit raise ExportError {
  let d = DictBuilder::new()
  d.set("Type", Name("Annot"))
  d.set("Subtype", Name("Link"))
  let rect = self.link.rect.transform(page_root_transform(page_height))
  d.set("Rect", rect.to_pdf())
  d.set("Border", Arr([Int(0), Int(0), Int(0)]))
  if sc.settings.pdf_version() >= Pdf16 && self.link.quad_points is Some(quads) {
    let pts = []
    let ts = page_root_transform(page_height)
    for q in quads {
      for p in q {
        let p = ts.apply(p.x, p.y)
        pts.push(Real(p.x))
        pts.push(Real(p.y))
      }
    }
    d.set("QuadPoints", Arr(pts))
  }
  match self.link.target {
    Destination(dest) => d.set("Dest", dest.to_obj(sc))
    Action(Link(uri)) =>
      d.set(
        "A",
        Dict([
          ("Type", Name("Action")),
          ("S", Name("URI")),
          ("URI", Str(utf8_bytes(uri))),
        ]),
      )
  }
  // The print flag (no border is drawn).
  d.set("F", Int(4))
  if self.struct_parent is Some(sp) {
    d.set("StructParent", Int(sp))
  }
  if self.alt is Some(alt) {
    d.set("Contents", TextStr(alt))
  }
  match self.alt {
    None =>
      sc.register_validation_error(MissingAnnotationAltText(self.location))
    Some(a) =>
      if a.is_empty() {
        sc.register_validation_error(MissingAnnotationAltText(self.location))
      }
  }
  sc.put(root_ref, d.finish())
}

///|
/// A node of the document outline.
pub(all) struct OutlineNode {
  children : Array[OutlineNode]
  text : String
  destination : XyzDestination
}

///|
pub fn OutlineNode::new(
  text : String,
  destination : XyzDestination,
) -> OutlineNode {
  { children: [], text, destination, }
}

///|
pub fn OutlineNode::push_child(self : OutlineNode, node : OutlineNode) -> Unit {
  self.children.push(node)
}

///|
/// The document outline.
pub(all) struct Outline {
  children : Array[OutlineNode]
}

///|
pub fn Outline::new() -> Outline {
  { children: [], }
}

///|
pub fn Outline::push_child(self : Outline, node : OutlineNode) -> Unit {
  self.children.push(node)
}

///|
fn count_nodes(nodes : Array[OutlineNode]) -> Int {
  let mut n = nodes.length()
  for c in nodes {
    n += count_nodes(c.children)
  }
  n
}

///|
fn SerializeContext::serialize_outline_nodes(
  self : SerializeContext,
  nodes : Array[OutlineNode],
  parent : Int,
) -> (Int, Int) {
  let refs = nodes.map(_ => self.new_ref())
  for i, node in nodes {
    let d = DictBuilder::new()
    d.set("Parent", Ref(parent))
    if i > 0 {
      d.set("Prev", Ref(refs[i - 1]))
    }
    if i + 1 < refs.length() {
      d.set("Next", Ref(refs[i + 1]))
    }
    if !node.children.is_empty() {
      let (first, last) = self.serialize_outline_nodes(node.children, refs[i])
      d.set("First", Ref(first))
      d.set("Last", Ref(last))
      d.set("Count", Int(-count_nodes(node.children)))
    }
    d.set("Title", TextStr(node.text))
    d.set("Dest", Ref(self.register_xyz_destination(node.destination)))
    self.put(refs[i], d.finish())
  }
  (refs[0], refs[refs.length() - 1])
}

///|
/// The numbering style of a page label.
pub(all) enum NumberingStyle {
  Arabic
  LowerRoman
  UpperRoman
  LowerAlpha
  UpperAlpha
} derive(Eq, Show)

///|
/// A page label.
pub(all) struct PageLabel {
  style : NumberingStyle?
  prefix : String?
  offset : Int?
} derive(Eq, Show)

///|
pub fn PageLabel::new(
  style : NumberingStyle?,
  prefix : String?,
  offset : Int?,
) -> PageLabel {
  { style, prefix, offset, }
}

///|
pub fn PageLabel::default() -> PageLabel {
  { style: None, prefix: None, offset: None, }
}

///|
fn PageLabel::is_empty(self : PageLabel) -> Bool {
  self.style is None && self.prefix is None && self.offset is None
}

///|
fn PageLabel::to_obj(self : PageLabel) -> Obj {
  let d = DictBuilder::new()
  d.set("Type", Name("PageLabel"))
  if self.style is Some(style) {
    d.set(
      "S",
      Name(
        match style {
          Arabic => "D"
          LowerRoman => "r"
          UpperRoman => "R"
          LowerAlpha => "a"
          UpperAlpha => "A"
        },
      ),
    )
  }
  if self.prefix is Some(p) {
    d.set("P", TextStr(p))
  }
  if self.offset is Some(o) {
    d.set("St", Int(o))
  }
  d.finish()
}

///|
/// The text direction of the document.
pub(all) enum TextDirection {
  LeftToRight
  RightToLeft
} derive(Eq, Show)

///|
/// A date and time.
pub(all) struct DateTime {
  year : Int
  month : Int?
  day : Int?
  hour : Int?
  minute : Int?
  second : Int?
  utc_offset_hour : Int?
  utc_offset_minute : Int
} derive(Eq, Show)

///|
pub fn DateTime::new(year : Int) -> DateTime {
  {
    year: if year > 9999 {
      9999
    } else {
      year
    },
    month: None,
    day: None,
    hour: None,
    minute: None,
    second: None,
    utc_offset_hour: None,
    utc_offset_minute: 0,
  }
}

///|
fn clamp(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
pub fn DateTime::month(self : DateTime, m : Int) -> DateTime {
  { ..self, month: Some(clamp(m, 1, 12)), }
}

///|
pub fn DateTime::day(self : DateTime, d : Int) -> DateTime {
  { ..self, day: Some(clamp(d, 1, 31)), }
}

///|
pub fn DateTime::hour(self : DateTime, h : Int) -> DateTime {
  { ..self, hour: Some(clamp(h, 0, 23)), }
}

///|
pub fn DateTime::minute(self : DateTime, m : Int) -> DateTime {
  { ..self, minute: Some(clamp(m, 0, 59)), }
}

///|
pub fn DateTime::second(self : DateTime, s : Int) -> DateTime {
  { ..self, second: Some(clamp(s, 0, 59)), }
}

///|
pub fn DateTime::utc_offset_hour(self : DateTime, h : Int) -> DateTime {
  { ..self, utc_offset_hour: Some(clamp(h, -23, 23)), }
}

///|
pub fn DateTime::utc_offset_minute(self : DateTime, m : Int) -> DateTime {
  { ..self, utc_offset_minute: clamp(m, 0, 59), }
}

///|
fn pad2(v : Int) -> String {
  if v < 10 {
    "0\{v}"
  } else {
    v.to_string()
  }
}

///|
fn pad4(v : Int) -> String {
  let s = v.to_string()
  let sb = StringBuilder::new()
  for _ in 0..<(4 - s.length()) {
    sb.write_char('0')
  }
  sb.write_string(s)
  sb.to_string()
}

///|
/// The PDF date string (always with all fields, like krilla).
fn DateTime::to_pdf(self : DateTime) -> String {
  let oh = self.utc_offset_hour.unwrap_or(0)
  let tz = if oh == 0 && self.utc_offset_minute == 0 {
    "Z"
  } else {
    let sign = if oh < 0 { "-" } else { "+" }
    "\{sign}\{pad2(oh.abs())}'\{pad2(self.utc_offset_minute)}"
  }
  "D:\{pad4(self.year)}\{pad2(self.month.unwrap_or(1))}\{pad2(self.day.unwrap_or(1))}\{pad2(self.hour.unwrap_or(0))}\{pad2(self.minute.unwrap_or(0))}\{pad2(self.second.unwrap_or(0))}\{tz}"
}

///|
/// The XMP date string.
fn DateTime::to_xmp(self : DateTime) -> String {
  let tz = match self.utc_offset_hour {
    Some(h) => {
      let sign = if h < 0 { "-" } else { "+" }
      if h == 0 && self.utc_offset_minute == 0 {
        "Z"
      } else {
        "\{sign}\{pad2(h.abs())}:\{pad2(self.utc_offset_minute)}"
      }
    }
    None => "Z"
  }
  "\{pad4(self.year)}-\{pad2(self.month.unwrap_or(1))}-\{pad2(self.day.unwrap_or(1))}T\{pad2(self.hour.unwrap_or(0))}:\{pad2(self.minute.unwrap_or(0))}:\{pad2(self.second.unwrap_or(0))}\{tz}"
}

///|
/// Document metadata.
pub(all) struct Metadata {
  title : String?
  description : String?
  creator : String?
  producer : String?
  keywords : Array[String]?
  authors : Array[String]?
  document_id : String?
  language : String?
  creation_date : DateTime?
  text_direction : TextDirection?
}

///|
pub fn Metadata::new() -> Metadata {
  {
    title: None,
    description: None,
    creator: None,
    producer: None,
    keywords: None,
    authors: None,
    document_id: None,
    language: None,
    creation_date: None,
    text_direction: None,
  }
}

///|
pub fn Metadata::title(self : Metadata, title : String) -> Metadata {
  if title.is_empty() {
    self
  } else {
    { ..self, title: Some(title), }
  }
}

///|
pub fn Metadata::description(self : Metadata, d : String) -> Metadata {
  if d.is_empty() {
    self
  } else {
    { ..self, description: Some(d), }
  }
}

///|
pub fn Metadata::keywords(self : Metadata, k : Array[String]) -> Metadata {
  if k.is_empty() {
    self
  } else {
    { ..self, keywords: Some(k), }
  }
}

///|
pub fn Metadata::authors(self : Metadata, a : Array[String]) -> Metadata {
  if a.is_empty() {
    self
  } else {
    { ..self, authors: Some(a), }
  }
}

///|
pub fn Metadata::language(self : Metadata, l : String) -> Metadata {
  { ..self, language: Some(l), }
}

///|
pub fn Metadata::creator(self : Metadata, c : String) -> Metadata {
  if c.is_empty() {
    self
  } else {
    { ..self, creator: Some(c), }
  }
}

///|
pub fn Metadata::producer(self : Metadata, p : String) -> Metadata {
  if p.is_empty() {
    self
  } else {
    { ..self, producer: Some(p), }
  }
}

///|
pub fn Metadata::document_id(self : Metadata, id : String) -> Metadata {
  { ..self, document_id: Some(id), }
}

///|
pub fn Metadata::creation_date(self : Metadata, d : DateTime) -> Metadata {
  { ..self, creation_date: Some(d), }
}

///|
pub fn Metadata::text_direction(self : Metadata, d : TextDirection) -> Metadata {
  { ..self, text_direction: Some(d), }
}

///|
fn Metadata::has_document_info(self : Metadata) -> Bool {
  self.title is Some(_) ||
  self.producer is Some(_) ||
  self.keywords is Some(_) ||
  self.authors is Some(_) ||
  self.creator is Some(_) ||
  self.creation_date is Some(_) ||
  self.description is Some(_)
}

///|
fn join(items : Array[String], sep : String) -> String {
  let sb = StringBuilder::new()
  for i, s in items {
    if i > 0 {
      sb.write_string(sep)
    }
    sb.write_string(s)
  }
  sb.to_string()
}

///|
/// The relationship of an embedded file to the document.
pub(all) enum AssociationKind {
  Source
  Data
  Alternative
  Supplement
  Unspecified
} derive(Eq, Show)

///|
/// An embedded file.
pub(all) struct EmbeddedFile {
  path : String
  mime_type : String?
  description : String?
  association_kind : AssociationKind
  data : Bytes
  compress : Bool?
  location : Location?
  modification_date : DateTime?
}

///|
fn SerializeContext::serialize_embedded_file(
  self : SerializeContext,
  file : EmbeddedFile,
  root_ref : Int,
) -> Unit {
  self.register_validation_error(EmbeddedFile(Existence, file.location))
  if file.modification_date is None {
    self.register_validation_error(EmbeddedFile(MissingDate, file.location))
  }
  if file.description is None {
    self.register_validation_error(
      EmbeddedFile(MissingDescription, file.location),
    )
  }
  if file.mime_type is None {
    self.register_validation_error(EmbeddedFile(MissingMimeType, file.location))
  }
  let stream_ref = self.new_ref()
  let sd = DictBuilder::new()
  sd.set("Type", Name("EmbeddedFile"))
  if file.mime_type is Some(m) {
    sd.set("Subtype", Name(m))
  }
  let params = DictBuilder::new()
  params.set("Size", Int(file.data.length()))
  if file.modification_date is Some(date) {
    params.set("ModDate", Str(utf8_bytes(date.to_pdf())))
  }
  sd.set("Params", params.finish())
  self.put_stream(
    stream_ref,
    sd.entries(),
    file.data,
    compress=file.compress.unwrap_or(true),
  )
  let d = DictBuilder::new()
  d.set("Type", Name("Filespec"))
  let pdf17 = self.settings.pdf_version() >= Pdf17
  d.set("F", Str(utf8_bytes(file.path)))
  if pdf17 {
    d.set("UF", TextStr(file.path))
  }
  d.set(
    "EF",
    Dict(
      if pdf17 {
        [("F", Ref(stream_ref)), ("UF", Ref(stream_ref))]
      } else {
        [("F", Ref(stream_ref))]
      },
    ),
  )
  if file.description is Some(desc) {
    d.set("Desc", TextStr(desc))
  }
  let settings = self.settings
  if settings.pdf_version().specifies_associated_files() ||
    settings.validators().specifies_associated_files() {
    d.set(
      "AFRelationship",
      Name(
        match file.association_kind {
          Source => "Source"
          Data => "Data"
          Alternative => "Alternative"
          Supplement => "Supplement"
          Unspecified => "Unspecified"
        },
      ),
    )
  }
  self.put(root_ref, d.finish())
}
