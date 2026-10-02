// Documents and pages (port of krilla's `document`, `page` and the
// finishing parts of `serialize` and `chunk_container`).

///|
/// Settings of a page.
pub(all) struct PageSettings {
  surface_size : Size
  media_box : Rect?
  trim_box : Rect?
  page_label : PageLabel
}

///|
/// Page settings for a page of the given size; `None` if it is not
/// positive.
pub fn PageSettings::from_wh(width : Double, height : Double) -> PageSettings? {
  match Size::from_wh(width, height) {
    Some(size) =>
      Some({
        surface_size: size,
        media_box: Rect::from_xywh(0.0, 0.0, width, height),
        trim_box: None,
        page_label: PageLabel::default(),
      })
    None => None
  }
}

///|
pub fn PageSettings::with_trim_box(
  self : PageSettings,
  rect : Rect,
) -> PageSettings {
  { ..self, trim_box: Some(rect), }
}

///|
pub fn PageSettings::with_page_label(
  self : PageSettings,
  label : PageLabel,
) -> PageSettings {
  { ..self, page_label: label, }
}

///|
/// A page being written.
pub struct Page {
  priv sc : SerializeContext
  priv settings : PageSettings
  priv page_index : Int
  priv mut stream : Stream
  priv mut num_mcids : Int
  priv annotations : Array[Annotation]
}

///|
/// The page index.
pub fn Page::index(self : Page) -> Int {
  self.page_index
}

///|
/// Add an annotation to the page.
pub fn Page::add_annotation(self : Page, annotation : Annotation) -> Unit {
  self.annotations.push(annotation)
}

///|
/// Add an annotation that is part of the structure tree.
pub fn Page::add_tagged_annotation(
  self : Page,
  annotation : Annotation,
) -> Identifier {
  let annot_index = self.annotations.length()
  let sp = self.sc.register_annotation_parent({
    page_index: self.page_index,
    annot_index,
  })
  annotation.struct_parent = sp
  self.add_annotation(annotation)
  match sp {
    None => Dummy
    Some(_) => Annotation(self.page_index, annot_index)
  }
}

///|
/// The drawing surface of the page. Finish it with `Surface::finish`.
pub fn Page::surface(self : Page) -> Surface {
  let height = self.settings.surface_size.height
  {
    sc: self.sc,
    fill: None,
    stroke: None,
    root_builder: ContentBuilder::new(
      page_root_transform(height),
      self.settings.media_box is None,
    ),
    sub_builders: [],
    push_instructions: [],
    mcid: if self.sc.settings.enable_tagging {
      Some(0)
    } else {
      None
    },
    kind: PageSurface(self),
  }
}

///|
/// Finish the page surface and store its content in the page.
pub fn Surface::finish(self : Surface) -> Unit {
  if !self.sub_builders.is_empty() || !self.push_instructions.is_empty() {
    abort("unbalanced push/pop on surface")
  }
  if self.root_builder.active_marked_content {
    abort("unfinished marked content")
  }
  if self.kind is PageSurface(page) {
    page.stream = self.root_builder.finish()
    page.num_mcids = self.mcid.unwrap_or(0)
  }
}

///|
priv struct InternalPage {
  stream_ref : Int
  stream : Stream
  settings : PageSettings
  page_index : Int
  struct_parent : Int?
  annotations : Array[Annotation]
}

///|
/// Finish the page.
pub fn Page::finish(self : Page) -> Unit {
  let sc = self.sc
  let struct_parent = sc.register_page_struct_parent(
    self.page_index,
    self.num_mcids,
  )
  for e in self.stream.validation_errors {
    sc.register_validation_error(e)
  }
  let stream_ref = sc.new_ref()
  let page = {
    stream_ref,
    stream: self.stream,
    settings: self.settings,
    page_index: self.page_index,
    struct_parent,
    annotations: self.annotations,
  }
  sc.pages.push((sc.page_infos[self.page_index].ref_, page))
}

///|
fn SerializeContext::serialize_page(
  self : SerializeContext,
  root_ref : Int,
  page : InternalPage,
) -> Unit raise ExportError {
  let height = page.settings.surface_size.height
  let annotation_refs = []
  for annotation in page.annotations {
    let r = self.new_ref()
    annotation.serialize(self, r, height)
    annotation_refs.push((r, None))
  }
  let d = DictBuilder::new()
  d.set("Type", Name("Page"))
  d.set("Resources", page.stream.resources.to_pdf())
  let ts = page_root_transform(height)
  let media_box = match page.settings.media_box {
    Some(m) => m
    None => page.stream.bbox
  }
  d.set("MediaBox", media_box.transform(ts).to_pdf())
  if page.settings.trim_box is Some(trim) {
    d.set("TrimBox", trim.transform(ts).to_pdf())
  }
  if page.struct_parent is Some(sp) {
    d.set("StructParents", Int(sp))
  }
  let validators = self.settings.validators()
  if (
      !page.annotations.is_empty() ||
      (
        (validators.ua is Some(_) || validators.requires_tagging()) &&
        self.settings.pdf_version() >=
        StructureOrderTabbing.minimum_pdf_version()
      )
    ) &&
    self.settings.enable_tagging {
    if self.settings.pdf_version() >=
      StructureOrderTabbing.minimum_pdf_version() {
      d.set("Tabs", Name("S"))
    } else {
      self.register_validation_error(
        RequiresNewerPdfVersion(StructureOrderTabbing, self.location),
      )
    }
  }
  d.set("Parent", Ref(self.page_tree_ref))
  d.set("Contents", Ref(page.stream_ref))
  if !annotation_refs.is_empty() {
    d.set("Annots", Arr(annotation_refs.map(a => Ref(a.0))))
  }
  self.page_infos[page.page_index].annotations = annotation_refs
  self.put(root_ref, d.finish())
  self.put_content_stream(page.stream_ref, [], page.stream.content)
}

///|
/// A PDF document being written.
pub struct Document {
  priv sc : SerializeContext
}

///|
/// Create a new document.
pub fn Document::new_with(settings : SerializeSettings) -> Document {
  { sc: SerializeContext::new(settings), }
}

///|
/// Start a new page.
pub fn Document::start_page_with(
  self : Document,
  settings : PageSettings,
) -> Page {
  let sc = self.sc
  let page_index = sc.page_infos.length()
  sc.page_infos.push({
    ref_: sc.new_ref(),
    surface_size: settings.surface_size,
    annotations: [],
    page_label: settings.page_label,
  })
  {
    sc,
    settings,
    page_index,
    stream: Stream::empty(),
    num_mcids: 0,
    annotations: [],
  }
}

///|
/// Register a named destination; `None` if a different destination with
/// the same name exists.
pub fn Document::register_named_destination(
  self : Document,
  nd : NamedDestination,
) -> Unit? {
  match self.sc.register_named_destination(nd) {
    Some(_) => Some(())
    None => None
  }
}

///|
/// Set the outline (only stored if non-empty or required).
pub fn Document::set_outline(self : Document, outline : Outline) -> Unit {
  if !outline.children.is_empty() ||
    self.sc.settings.validators().prohibits(MissingDocumentOutline) is Some(_) {
    self.sc.outline = Some(outline)
  }
}

///|
pub fn Document::set_metadata(self : Document, metadata : Metadata) -> Unit {
  self.sc.metadata = Some(metadata)
}

///|
/// Set the tag tree (only stored if tagging is enabled).
pub fn Document::set_tag_tree(self : Document, tree : TagTree) -> Unit {
  if self.sc.settings.enable_tagging {
    self.sc.tag_tree = Some(tree)
  }
}

///|
/// Embed a file; `None` if a file with the same path was embedded before.
pub fn Document::embed_file(self : Document, file : EmbeddedFile) -> Unit? {
  let sc = self.sc
  if sc.embedded_files.contains(file.path) {
    return None
  }
  let r = sc.new_ref()
  sc.serialize_embedded_file(file, r)
  sc.embedded_files[file.path] = r
  Some(())
}

///|
/// Whether tagging is enabled.
pub fn Document::tagging_enabled(self : Document) -> Bool {
  self.sc.settings.enable_tagging
}

///|
fn xml_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match c {
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '&' => sb.write_string("&amp;")
      '"' => sb.write_string("&quot;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// A short stable hash (hex) of some strings.
fn stable_hash_hex(parts : Array[String]) -> String {
  let mut h = 0xcbf29ce484222325UL
  for p in parts {
    for c in p {
      h = (h ^ c.to_int().to_uint64()) * 0x100000001b3UL
    }
    h = (h ^ 0xFFUL) * 0x100000001b3UL
  }
  let sb = StringBuilder::new()
  for i in 0..<16 {
    let nib = ((h >> (60 - 4 * i)) & 0xFUL).to_int()
    sb.write_char(hex_digits[nib].unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Build the XMP metadata packet.
fn SerializeContext::xmp(
  self : SerializeContext,
  instance_id : String,
  document_id : String,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<?xpacket begin=\"\u{FEFF}\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?><x:xmpmeta xmlns:x=\"adobe:ns:meta/\" x:xmptk=\"xmp-writer\"><rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"><rdf:Description rdf:about=\"\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\" xmlns:pdf=\"http://ns.adobe.com/pdf/1.3/\" xmlns:xmpMM=\"http://ns.adobe.com/xap/1.0/mm/\" xmlns:xmpTPg=\"http://ns.adobe.com/xap/1.0/t/pg/\" xmlns:pdfaid=\"http://www.aiim.org/pdfa/ns/id/\" xmlns:pdfuaid=\"http://www.aiim.org/pdfua/ns/id/\">",
  )
  if self.metadata is Some(m) {
    if m.title is Some(t) {
      sb.write_string(
        "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">\{xml_escape(t)}</rdf:li></rdf:Alt></dc:title>",
      )
    }
    if m.description is Some(t) {
      sb.write_string(
        "<dc:description><rdf:Alt><rdf:li xml:lang=\"x-default\">\{xml_escape(t)}</rdf:li></rdf:Alt></dc:description>",
      )
    }
    if m.keywords is Some(k) {
      sb.write_string(
        "<pdf:Keywords>\{xml_escape(join(k, ", "))}</pdf:Keywords>",
      )
    }
    if m.authors is Some(a) {
      sb.write_string(
        "<dc:creator><rdf:Seq><rdf:li>\{xml_escape(join(a, ", "))}</rdf:li></rdf:Seq></dc:creator>",
      )
    }
    if m.creator is Some(c) {
      sb.write_string("<xmp:CreatorTool>\{xml_escape(c)}</xmp:CreatorTool>")
    }
    if m.producer is Some(p) {
      sb.write_string("<pdf:Producer>\{xml_escape(p)}</pdf:Producer>")
    }
    if m.language is Some(l) {
      sb.write_string(
        "<dc:language><rdf:Bag><rdf:li>\{xml_escape(l)}</rdf:li></rdf:Bag></dc:language>",
      )
    }
    match m.creation_date {
      Some(date) => {
        let d = date.to_xmp()
        sb.write_string("<xmp:ModifyDate>\{d}</xmp:ModifyDate>")
        sb.write_string("<xmp:CreateDate>\{d}</xmp:CreateDate>")
      }
      None => self.register_validation_error(MissingDocumentDate)
    }
  }
  let validators = self.settings.validators()
  if validators.a is Some(a) {
    let (part, conformance) = match a {
      A1_A => (1, Some("A"))
      A1_B => (1, Some("B"))
      A2_A => (2, Some("A"))
      A2_B => (2, Some("B"))
      A2_U => (2, Some("U"))
      A3_A => (3, Some("A"))
      A3_B => (3, Some("B"))
      A3_U => (3, Some("U"))
      A4 => (4, None)
      A4F => (4, Some("F"))
      A4E => (4, Some("E"))
    }
    sb.write_string("<pdfaid:part>\{part}</pdfaid:part>")
    if part == 4 {
      sb.write_string("<pdfaid:rev>2020</pdfaid:rev>")
    }
    if conformance is Some(c) {
      sb.write_string("<pdfaid:conformance>\{c}</pdfaid:conformance>")
    }
  }
  if validators.ua is Some(_) {
    sb.write_string("<pdfuaid:part>1</pdfuaid:part>")
  }
  sb.write_string("<xmpTPg:NPages>\{self.page_infos.length()}</xmpTPg:NPages>")
  sb.write_string("<dc:format>application/pdf</dc:format>")
  sb.write_string("<xmpMM:InstanceID>\{instance_id}</xmpMM:InstanceID>")
  sb.write_string("<xmpMM:DocumentID>\{document_id}</xmpMM:DocumentID>")
  sb.write_string("<xmpMM:RenditionClass>proof</xmpMM:RenditionClass>")
  sb.write_string(
    "<pdf:PDFVersion>\{self.settings.pdf_version().header()}</pdf:PDFVersion>",
  )
  sb.write_string(
    "</rdf:Description></rdf:RDF></x:xmpmeta><?xpacket end=\"r\"?>",
  )
  sb.to_string()
}

///|
/// Finish the document and return the PDF bytes.
pub fn Document::finish(self : Document) -> Bytes raise ExportError {
  let sc = self.sc
  // Write an empty (A4) page if none has been created yet.
  if sc.page_infos.is_empty() {
    let page = self.start_page_with(
      PageSettings::from_wh(595.0, 842.0).unwrap(),
    )
    page.surface().finish()
    page.finish()
  }
  let settings = sc.settings
  // Page labels.
  let mut page_labels_ref = None
  let labels = sc.page_infos.map(p => p.page_label)
  if !labels.iter().all(l => l.is_empty()) {
    let nums = []
    let mut prev : PageLabel? = None
    for i, label in labels {
      let push = match prev {
        Some(p) =>
          // Like krilla (which compares the previous offset with the next
          // offset plus one).
          p.style != label.style ||
          p.prefix != label.prefix ||
          p.offset != label.offset.map(n => n + 1)
        None => true
      }
      if push {
        let r = sc.new_ref()
        sc.put(r, label.to_obj())
        nums.push(Int(i))
        nums.push(Ref(r))
        prev = Some(label)
      }
    }
    let r = sc.new_ref()
    sc.put(r, Dict([("Nums", Arr(nums))]))
    page_labels_ref = Some(r)
  }
  // The outline.
  let mut outline_ref = None
  match sc.outline {
    Some(outline) => {
      let r = sc.new_ref()
      let d = DictBuilder::new()
      d.set("Type", Name("Outlines"))
      if !outline.children.is_empty() {
        let (first, last) = sc.serialize_outline_nodes(outline.children, r)
        d.set("First", Ref(first))
        d.set("Last", Ref(last))
        d.set("Count", Int(outline.children.length()))
      }
      sc.put(r, d.finish())
      outline_ref = Some(r)
    }
    None => sc.register_validation_error(MissingDocumentOutline)
  }
  // Fonts.
  for c in sc.font_containers {
    if !c.cid_font.is_empty() {
      c.cid_font.serialize(sc, c.ref_)
    }
  }
  // Pages and the page tree.
  for entry in sc.pages {
    sc.serialize_page(entry.0, entry.1)
  }
  sc.put(
    sc.page_tree_ref,
    Dict([
      ("Type", Name("Pages")),
      ("Count", Int(sc.page_infos.length())),
      ("Kids", Arr(sc.page_infos.map(p => Ref(p.ref_)))),
    ]),
  )
  // Destinations.
  for entry in sc.xyz_destinations {
    let (r, dest) = entry
    guard sc.page_infos.get(dest.page_index) is Some(info) else {
      abort(
        "attempted to link to page \{dest.page_index + 1}, but document only has \{sc.page_infos.length()} pages",
      )
    }
    let p = page_root_transform(info.surface_size.height).apply(
      dest.point.x,
      dest.point.y,
    )
    sc.put(r, Arr([Ref(info.ref_), Name("XYZ"), Real(p.x), Real(p.y), Null]))
  }
  // The structure tree.
  let mut struct_tree_ref = None
  match sc.tag_tree {
    Some(tree) => struct_tree_ref = Some(sc.serialize_tag_tree(tree))
    None => sc.register_validation_error(MissingTagging)
  }
  // Document information.
  let missing_title = match sc.metadata {
    Some(m) => m.title is None
    None => true
  }
  if missing_title {
    sc.register_validation_error(NoDocumentTitle)
  }
  let mut info_ref = None
  if sc.metadata is Some(m) &&
    !settings.validators().prohibits_info_dict() &&
    m.has_document_info() {
    let d = DictBuilder::new()
    if settings.pdf_version() < Pdf20 {
      if m.title is Some(t) {
        d.set("Title", TextStr(t))
      }
      if m.description is Some(t) {
        d.set("Subject", TextStr(t))
      }
      if m.keywords is Some(k) {
        d.set("Keywords", TextStr(join(k, ", ")))
      }
      if m.authors is Some(a) {
        d.set("Author", TextStr(join(a, ", ")))
      }
      if m.creator is Some(c) {
        d.set("Creator", TextStr(c))
      }
      if m.producer is Some(p) {
        d.set("Producer", TextStr(p))
      }
    }
    if m.creation_date is Some(date) {
      d.set("ModDate", Str(utf8_bytes(date.to_pdf())))
      d.set("CreationDate", Str(utf8_bytes(date.to_pdf())))
    }
    let r = sc.new_ref()
    sc.put(r, d.finish())
    info_ref = Some(r)
  }
  // Identifiers.
  let instance_id = stable_hash_hex([
    sc.cur_ref.to_string(),
    sc.page_infos.length().to_string(),
  ])
  let document_id = match sc.metadata {
    Some({ document_id: Some(id), .. }) =>
      stable_hash_hex([settings.pdf_version().as_str(), id])
    Some({ title: Some(t), authors: Some(a), .. }) =>
      stable_hash_hex([settings.pdf_version().as_str(), t, join(a, ", ")])
    _ => instance_id
  }
  // XMP metadata.
  let mut meta_ref = None
  if settings.xmp_metadata {
    let xmp = sc.xmp(instance_id, document_id)
    let r = sc.new_ref()
    sc.put_stream(
      r,
      [("Type", Name("Metadata")), ("Subtype", Name("XML"))],
      utf8_bytes(xmp),
      compress=false,
    )
    meta_ref = Some(r)
  }
  // The catalog.
  let catalog_ref = sc.new_ref()
  let cat = DictBuilder::new()
  cat.set("Type", Name("Catalog"))
  cat.set("Pages", Ref(sc.page_tree_ref))
  if meta_ref is Some(r) {
    cat.set("Metadata", Ref(r))
  }
  if page_labels_ref is Some(r) {
    cat.set("PageLabels", Ref(r))
  }
  match sc.metadata {
    Some({ language: Some(lang), .. }) => cat.set("Lang", TextStr(lang))
    _ => sc.register_validation_error(NoDocumentLanguage)
  }
  if struct_tree_ref is Some(r) {
    cat.set("StructTreeRoot", Ref(r))
    let mi = DictBuilder::new()
    mi.set("Marked", Bool(true))
    if settings.pdf_version() >= Pdf16 && settings.pdf_version() < Pdf20 {
      mi.set("Suspects", Bool(false))
    }
    cat.set("MarkInfo", mi.finish())
  }
  let write_doc_title = settings.validators().requires_display_doc_title()
  let text_direction = match sc.metadata {
    Some(m) => m.text_direction
    None => None
  }
  if write_doc_title || text_direction is Some(_) {
    let vp = DictBuilder::new()
    if write_doc_title {
      vp.set("DisplayDocTitle", Bool(true))
    }
    if text_direction is Some(dir) {
      vp.set("Direction", Name(if dir == RightToLeft { "R2L" } else { "L2R" }))
    }
    cat.set("ViewerPreferences", vp.finish())
  }
  if outline_ref is Some(r) {
    cat.set("Outlines", Ref(r))
  }
  let write_embedded_files = !sc.embedded_files.is_empty() ||
    settings.validators().requires_embedded_files_when_empty()
  if !sc.named_destinations.is_empty() || write_embedded_files {
    let names = DictBuilder::new()
    if !sc.named_destinations.is_empty() {
      let sorted = sc.named_destinations.to_array()
      sorted.sort_by((a, b) => compare_bytes(utf8_bytes(a.0), utf8_bytes(b.0)))
      let entries = []
      for e in sorted {
        entries.push(Str(utf8_bytes(e.0)))
        entries.push(Ref(e.1.0))
      }
      names.set("Dests", Dict([("Names", Arr(entries))]))
    }
    if write_embedded_files {
      let sorted = sc.embedded_files.to_array()
      sorted.sort_by((a, b) => compare_bytes(utf8_bytes(a.0), utf8_bytes(b.0)))
      let entries = []
      for e in sorted {
        entries.push(Str(utf8_bytes(e.0)))
        entries.push(Ref(e.1))
      }
      names.set("EmbeddedFiles", Dict([("Names", Arr(entries))]))
    }
    cat.set("Names", names.finish())
  }
  if !sc.embedded_files.is_empty() &&
    (
      settings.pdf_version().specifies_associated_files() ||
      settings.validators().specifies_associated_files()
    ) {
    let sorted = sc.embedded_files.to_array()
    sorted.sort_by((a, b) => compare_bytes(utf8_bytes(a.0), utf8_bytes(b.0)))
    cat.set("AF", Arr(sorted.map(e => Ref(e.1))))
  }
  sc.put(catalog_ref, cat.finish())
  // Validation errors (deduplicated, in order).
  if !sc.validation_errors.is_empty() {
    let errors : Array[(ValidationError, Validators)] = []
    for e in sc.validation_errors {
      if !errors.iter().any(x => x.0.same(e.0)) {
        errors.push(e)
      }
    }
    raise Validation(errors)
  }
  write_file(
    settings.pdf_version().header(),
    sc.objects,
    sc.cur_ref,
    catalog_ref,
    info_ref,
    Some((utf8_bytes(document_id), utf8_bytes(instance_id))),
  )
}
