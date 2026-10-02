///|
// Importing a page of another document as a Form XObject: the page's
// content and every object its resources reach are copied into the
// importing document under new object numbers, so the page can be drawn
// (scaled and placed like an image) on any page of it.
//
// The walks over the source keep explicit worklists rather than recursing.
// The page tree walk visits each node and each `/Kids` array held by
// reference once (a second visit is an error, so a cycle ends it), and
// the walk over what a page reaches visits each object once; the only
// recursion left is over the direct nesting inside one copied object,
// which is limited to `pdf_import_max_nesting` levels.

///|
fn pdf_import_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
/// How deeply direct objects (arrays and dictionaries inside one object)
/// may nest in a copied object.
let pdf_import_max_nesting : Int = 256

///|
/// A page of another document, imported as a Form XObject by
/// `PdfDocument::import_page`.
///
/// Drawn with the identity matrix, the form fills the rectangle from
/// `(0, 0)` to `(width, height)` in user space, upright: a content stream
/// draws it into a box `w` by `h` at `(x, y)` with
/// `q w/width 0 0 h/height x y cm /Name Do Q`, after adding `object` to the
/// page's `/XObject` resources under `/Name`.
pub struct PdfImportedPage {
  /// the Form XObject's object number in the importing document
  object : Int
  /// the page's width as a viewer shows it, in points
  width : Double
  /// the page's height as a viewer shows it, in points
  height : Double
} derive(Eq, Debug)

///|
/// A leaf of a source's page tree, with the attributes it inherits
/// (PDF 32000-1 §7.7.3.4), still unresolved.
priv struct PdfImportLeaf {
  page : @syntax.PdfObject
  resources : @syntax.PdfObject?
  mediabox : @syntax.PdfObject?
  cropbox : @syntax.PdfObject?
  rotate : @syntax.PdfObject?
}

///|
/// A document whose pages are to be imported (see
/// `PdfDocument::import_page`): its page tree, walked once.
struct PdfPageSource {
  document : PdfDocument
  pages : Array[PdfImportLeaf]
  /// the object numbers of the page tree's nodes, pages included, which
  /// an imported page's objects never reach into
  tree : Map[Int, Unit]
}

///|
/// Whether `object` is a dictionary (or a stream) whose `/Type`, resolved,
/// is `/Page` or `/Pages`.
fn PdfDocument::pdf_import_is_page_node(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Bool {
  let dictionary = match object {
    PdfStreamObject(stream) => stream.dictionary
    other => other
  }
  match self.lookup_direct(pdf_import_name("/Type"), dictionary) {
    Some(PdfNameObject(kind)) =>
      kind == pdf_import_name("/Page") || kind == pdf_import_name("/Pages")
    _ => false
  }
}

///|
/// Read `document`'s page tree to import its pages: its leaves in order,
/// with their inherited attributes (an entry whose value is null, directly
/// or through a reference, is absent and inherits). A node or a `/Kids`
/// array held by reference that is reached twice (a cycle, or one shared
/// by two parents), a `/Pages` node without a `/Kids` array or a kid that
/// is not a dictionary raises `PageTreeExpected`; an encrypted document
/// raises `HardError`, as prawn-templates refuses one.
pub fn PdfPageSource::new(
  document : PdfDocument,
) -> PdfPageSource raise @core.PdfError {
  if document.is_encrypted() {
    raise HardError("cannot import a page of an encrypted document")
  }
  let catalog = match document.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => raise RootExpected
  }
  guard document.direct(catalog).lookup_immediate(pdf_import_name("/Pages"))
    is Some(root) else {
    raise PageTreeExpected
  }
  let pages : Array[PdfImportLeaf] = []
  let tree : Map[Int, Unit] = Map([])
  let kids_key = pdf_import_name("/Kids")
  let type_key = pdf_import_name("/Type")
  // nodes still to visit, the next one last
  let stack : Array[(@syntax.PdfObject, PdfImportLeaf)] = [
    (
      root,
      {
        page: PdfNull,
        resources: None,
        mediabox: None,
        cropbox: None,
        rotate: None,
      },
    ),
  ]
  while stack.pop() is Some((reference, inherited)) {
    match reference {
      PdfIndirect(number) => {
        if tree.contains(number) {
          raise PageTreeExpected
        }
        tree[number] = ()
      }
      _ => ()
    }
    let node = document.direct(reference)
    guard node is PdfDictionary(_) else { raise PageTreeExpected }
    // an entry whose value is null, directly or through a reference, is
    // absent (PDF 32000-1 §7.3.7, §7.3.9) and so inherits
    let own = (key : String, from : @syntax.PdfObject?) => {
      match node.lookup_immediate(pdf_import_name(key)) {
        Some(value) if document.direct(value) != PdfNull => Some(value)
        _ => from
      }
    }
    let attributes = PdfImportLeaf::{
      page: node,
      resources: own("/Resources", inherited.resources),
      mediabox: own("/MediaBox", inherited.mediabox),
      cropbox: own("/CropBox", inherited.cropbox),
      rotate: own("/Rotate", inherited.rotate),
    }
    let kind = match document.lookup_direct(type_key, node) {
      Some(PdfNameObject(kind)) => Some(kind)
      _ => None
    }
    // a /Kids array held by reference is part of the tree too: a direct
    // node in an array that lists itself would otherwise loop
    match node.lookup_immediate(kids_key) {
      Some(PdfIndirect(number)) => {
        if tree.contains(number) {
          raise PageTreeExpected
        }
        tree[number] = ()
      }
      _ => ()
    }
    let kids = document.lookup_direct(kids_key, node)
    let branch = kind == Some(pdf_import_name("/Pages")) ||
      (kind != Some(pdf_import_name("/Page")) && kids is Some(PdfArray(_)))
    if branch {
      guard kids is Some(PdfArray(kids)) else { raise PageTreeExpected }
      for i = kids.length() - 1; i >= 0; i = i - 1 {
        stack.push((kids[i], attributes))
      }
    } else {
      pages.push(attributes)
    }
  }
  { document, pages, tree, }
}

///|
/// How many pages the source has.
pub fn PdfPageSource::page_count(self : PdfPageSource) -> Int {
  self.pages.length()
}

///|
fn PdfPageSource::leaf(
  self : PdfPageSource,
  page_number : Int,
) -> PdfImportLeaf raise @core.PdfError {
  guard page_number >= 1 && page_number <= self.pages.length() else {
    raise BadPageSpecification(
      "page \{page_number} of a document of \{self.pages.length()} pages",
    )
  }
  self.pages[page_number - 1]
}

///|
/// What a page shows and how: its visible box (in default user space
/// units), its rotation and its user unit.
priv struct PdfImportGeometry {
  box : @geometry.PdfRectangle
  rotate : @page.PdfPageRotation
  unit : Double
}

///|
fn pdf_import_finite(value : Double) -> Bool {
  !(value.is_nan() || value.is_inf())
}

///|
/// The visible box of a page (PDF 32000-1 §14.11.2): its media box (US
/// Letter when it has none, as pdflite's page tree reader assumes) clipped
/// to its crop box when it has one; a malformed box raises the rectangle
/// parser's error, and an empty or degenerate visible box `BadRectangle`.
/// `/Rotate` must be a multiple of 90 (`PageRotationExpected`) and
/// `/UserUnit` (PDF 32000-1 §14.11.2, Table 30) a positive number
/// (`BadNumberArgument`).
fn PdfPageSource::geometry(
  self : PdfPageSource,
  leaf : PdfImportLeaf,
) -> PdfImportGeometry raise @core.PdfError {
  let document = self.document
  let media = match leaf.mediabox {
    Some(box) => document.parse_rectangle(box)
    None => { min_x: 0.0, min_y: 0.0, max_x: 612.0, max_y: 792.0, }
  }
  let box = match leaf.cropbox {
    Some(crop) => {
      let crop = document.parse_rectangle(crop)
      @geometry.PdfRectangle::{
        min_x: double_max(crop.min_x, media.min_x),
        min_y: double_max(crop.min_y, media.min_y),
        max_x: double_min(crop.max_x, media.max_x),
        max_y: double_min(crop.max_y, media.max_y),
      }
    }
    None => media
  }
  guard pdf_import_finite(box.min_x) &&
    pdf_import_finite(box.min_y) &&
    pdf_import_finite(box.max_x) &&
    pdf_import_finite(box.max_y) &&
    box.max_x > box.min_x &&
    box.max_y > box.min_y else {
    raise BadRectangle
  }
  let rotate = match leaf.rotate.map(r => document.direct(r)) {
    None | Some(PdfNull) => @page.Rotate0
    Some(PdfInteger(degrees)) => @page.pdf_page_rotation_of_int(degrees)
    Some(PdfReal(degrees) | PdfExactReal(degrees)) if pdf_import_finite(degrees) &&
      degrees == degrees.floor() &&
      degrees.abs() < 1.0e9 => @page.pdf_page_rotation_of_int(degrees.to_int())
    Some(_) => raise NumberExpected
  }
  let unit = match
    document.lookup_direct(pdf_import_name("/UserUnit"), leaf.page) {
    None => 1.0
    Some(PdfInteger(n)) if n > 0 => n.to_double()
    Some(PdfReal(n) | PdfExactReal(n)) if pdf_import_finite(n) && n > 0.0 => n
    Some(_) => raise BadNumberArgument("/UserUnit is not a positive number")
  }
  { box, rotate, unit, }
}

///|
/// The size, in points, at which a viewer shows `geometry`'s page.
fn PdfImportGeometry::size(self : PdfImportGeometry) -> (Double, Double) {
  let w = (self.box.max_x - self.box.min_x) * self.unit
  let h = (self.box.max_y - self.box.min_y) * self.unit
  match self.rotate {
    Rotate90 | Rotate270 => (h, w)
    Rotate0 | Rotate180 => (w, h)
  }
}

///|
/// The size, in points, at which a viewer shows page `page_number`
/// (1-based): its visible box, the media box clipped to the crop box,
/// scaled by its `/UserUnit`, with width and height swapped when its
/// `/Rotate` is 90 or 270. This is the size `PdfDocument::import_page`
/// reports.
///
/// Raises `BadPageSpecification` when the source has no such page,
/// `RectangleExpected`, `BadRectangle` or `NumberExpected` when its boxes
/// are malformed or the visible box is empty, `PageRotationExpected` for a
/// `/Rotate` that is not a multiple of 90 and `BadNumberArgument` for a
/// `/UserUnit` that is not a positive number.
pub fn PdfPageSource::page_display_size(
  self : PdfPageSource,
  page_number : Int,
) -> (Double, Double) raise @core.PdfError {
  self.geometry(self.leaf(page_number)).size()
}

///|
/// The form matrix that turns the visible box upright with its lower-left
/// corner at the origin, as a viewer applies `/Rotate` (clockwise), then
/// scales it by the user unit.
fn PdfImportGeometry::matrix(self : PdfImportGeometry) -> Array[Double] {
  let box = self.box
  let matrix = match self.rotate {
    Rotate0 => [1.0, 0.0, 0.0, 1.0, -box.min_x, -box.min_y]
    Rotate90 => [0.0, -1.0, 1.0, 0.0, -box.min_y, box.max_x]
    Rotate180 => [-1.0, 0.0, 0.0, -1.0, box.max_x, box.max_y]
    Rotate270 => [0.0, 1.0, -1.0, 0.0, box.max_y, -box.min_x]
  }
  matrix.map(v => v * self.unit)
}

///|
/// `object` with indirect references renumbered through `numbers`; a
/// reference to an object that was not copied becomes `null`. Streams get
/// their raw (still encoded) data and a direct `/Length`. Direct objects
/// nested deeper than `pdf_import_max_nesting` raise `HardError`.
fn PdfDocument::pdf_import_rewrite(
  self : PdfDocument,
  object : @syntax.PdfObject,
  numbers : Map[Int, Int],
  depth? : Int = 0,
) -> @syntax.PdfObject raise @core.PdfError {
  if depth > pdf_import_max_nesting {
    raise HardError("objects nested too deeply to import")
  }
  match object {
    PdfIndirect(number) =>
      match numbers.get(number) {
        Some(renumbered) => PdfIndirect(renumbered)
        None => PdfNull
      }
    PdfArray(items) =>
      PdfArray(
        items.map(item => {
          self.pdf_import_rewrite(item, numbers, depth=depth + 1)
        }),
      )
    PdfDictionary(entries) =>
      PdfDictionary(
        entries.map(entry => {
          (entry.0, self.pdf_import_rewrite(entry.1, numbers, depth=depth + 1))
        }),
      )
    PdfStreamObject(stream) => {
      let data = object.stream_bytes()
      let length = pdf_import_name("/Length")
      let entries : Array[(@core.PdfName, @syntax.PdfObject)] = match
        self.pdf_import_rewrite(stream.dictionary, numbers, depth=depth + 1) {
        PdfDictionary(entries) => entries.filter(entry => entry.0 != length)
        _ => []
      }
      entries.push((length, PdfInteger(data.length())))
      @syntax.pdf_stream(PdfDictionary(entries), StreamGot(data))
    }
    other => other
  }
}

///|
/// The object numbers `object` reaches, in the order first reached:
/// everything but the page tree's nodes (and any other page or page tree
/// node, by its resolved `/Type`), and not through `/Parent` (up a tree
/// the page's resources do not need) or `/Length` (written directly).
fn PdfPageSource::reached(
  self : PdfPageSource,
  object : @syntax.PdfObject,
) -> Array[Int] {
  let document = self.document
  let skipped = [pdf_import_name("/Parent"), pdf_import_name("/Length")]
  let found : Map[Int, Unit] = Map([])
  let excluded : Map[Int, Unit] = Map([])
  let work : Array[@syntax.PdfObject] = [object]
  while work.pop() is Some(next) {
    match next {
      PdfIndirect(number) => {
        if number <= 0 ||
          found.contains(number) ||
          excluded.contains(number) ||
          self.tree.contains(number) {
          continue
        }
        let resolved = document.lookup_object_or_null(number)
        if document.pdf_import_is_page_node(resolved) {
          excluded[number] = ()
          continue
        }
        found[number] = ()
        work.push(resolved)
      }
      PdfArray(items) =>
        for i = items.length() - 1; i >= 0; i = i - 1 {
          work.push(items[i])
        }
      PdfDictionary(entries) =>
        for i = entries.length() - 1; i >= 0; i = i - 1 {
          if !skipped.contains(entries[i].0) {
            work.push(entries[i].1)
          }
        }
      PdfStreamObject(stream) => work.push(stream.dictionary)
      _ => ()
    }
  }
  found.keys().to_array()
}

///|
/// The page's content as one stream: a single content stream keeps its
/// filters and encoded bytes; several are decoded and joined (PDF 32000-1
/// §7.8.2), then Flate-compressed.
fn PdfDocument::pdf_import_content(
  self : PdfDocument,
  page : @syntax.PdfObject,
) -> (Array[(@core.PdfName, @syntax.PdfObject)], Bytes) raise @core.PdfError {
  match self.pdf_page_content_list(self.pdf_page_content_object(page)) {
    [] => ([], Bytes::new(0))
    [single] =>
      match self.direct(single) {
        PdfStreamObject(stream) as object => {
          let kept = [
            pdf_import_name("/Filter"),
            pdf_import_name("/DecodeParms"),
          ]
          let entries = match stream.dictionary {
            PdfDictionary(entries) =>
              entries.filter(entry => kept.contains(entry.0))
            _ => []
          }
          (entries, object.stream_bytes())
        }
        _ => raise ParseStreamExpected
      }
    contents => {
      let merged = pdf_encode_stream_with_encoding(
        PdfStreamFlate,
        self.pdf_page_merged_content_stream(contents),
        only_if_smaller=true,
      )
      match merged {
        PdfStreamObject(stream) as object => {
          let entries = match stream.dictionary {
            PdfDictionary(entries) =>
              entries.filter(entry => entry.0 != pdf_import_name("/Length"))
            _ => []
          }
          (entries, object.stream_bytes())
        }
        _ => raise ParseStreamExpected
      }
    }
  }
}

///|
/// Import page `page_number` (1-based) of `source` into this document as a
/// Form XObject. Like prawn-templates (which asciidoctor-pdf uses), the
/// page and the objects it needs are copied, here into a Form XObject
/// rather than a page: what is drawn is the page's visible box (the media
/// box clipped to the crop box), turned upright by its `/Rotate` and
/// scaled by its `/UserUnit`, with its content and resources.
/// Annotations, the structure tree and other document-level data are not
/// imported.
///
/// The page's content stream keeps its filters and encoded bytes (several
/// content streams are joined and compressed); every object the page's
/// resources (and transparency `/Group`) reach is copied under a new
/// object number, streams with their encoded data, so the source document
/// is left as it was. References to the source's page tree nodes, or to
/// any other page or page tree node, are not followed and become `null`.
/// Importing the same page twice copies it twice.
///
/// Raises what `PdfPageSource::page_display_size` raises, `HardError` for
/// direct objects nested more than 256 deep in a copied object, and the
/// reader's errors for malformed content. Everything is copied before this
/// document changes, so a failed import leaves it as it was: no object
/// added, no object number taken, nothing in its event log.
pub fn PdfDocument::import_page(
  self : PdfDocument,
  source : PdfPageSource,
  page_number : Int,
) -> PdfImportedPage raise @core.PdfError {
  let document = source.document
  let leaf = source.leaf(page_number)
  let geometry = source.geometry(leaf)
  let (filters, data) = document.pdf_import_content(leaf.page)
  let box = geometry.box
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (pdf_import_name("/Type"), PdfNameObject(pdf_import_name("/XObject"))),
    (pdf_import_name("/Subtype"), PdfNameObject(pdf_import_name("/Form"))),
    (pdf_import_name("/FormType"), PdfInteger(1)),
    (
      pdf_import_name("/BBox"),
      PdfArray([
        PdfReal(box.min_x),
        PdfReal(box.min_y),
        PdfReal(box.max_x),
        PdfReal(box.max_y),
      ]),
    ),
    (
      pdf_import_name("/Matrix"),
      PdfArray(geometry.matrix().map(v => PdfReal(v))),
    ),
    (pdf_import_name("/Resources"), leaf.resources.unwrap_or(PdfDictionary([]))),
  ]
  match leaf.page.lookup_immediate(pdf_import_name("/Group")) {
    Some(group) if document.direct(group) != PdfNull =>
      entries.push((pdf_import_name("/Group"), group))
    _ => ()
  }
  entries.append(filters)
  let form = @syntax.pdf_stream(PdfDictionary(entries), StreamGot(data))
  let reached = source.reached(form)
  // copy everything under provisional numbers (1, 2, ...) first: a failure
  // leaves this document exactly as it was, no object allocated
  let provisional : Map[Int, Int] = Map([])
  for i, number in reached {
    provisional[number] = i + 1
  }
  let copies = reached.map(number => {
    document.pdf_import_rewrite(
      document.lookup_object_or_null(number),
      provisional,
    )
  })
  let form = document.pdf_import_rewrite(form, provisional)
  let numbers = reached.map(_ => self.add_object(PdfNull))
  for i, copy in copies {
    self.add_object_given_number(numbers[i], pdf_import_renumber(copy, numbers))
  }
  let object = self.add_object(pdf_import_renumber(form, numbers))
  let (width, height) = geometry.size()
  { object, width, height, }
}

///|
/// `object`, copied with provisional numbers (`k` for the `k`th object
/// copied), with its references to the numbers the copies were added under.
/// The copy was bounded by `pdf_import_max_nesting`, and so is this.
fn pdf_import_renumber(
  object : @syntax.PdfObject,
  numbers : Array[Int],
) -> @syntax.PdfObject {
  match object {
    PdfIndirect(k) => PdfIndirect(numbers[k - 1])
    PdfArray(items) =>
      PdfArray(items.map(item => pdf_import_renumber(item, numbers)))
    PdfDictionary(entries) =>
      PdfDictionary(
        entries.map(entry => (entry.0, pdf_import_renumber(entry.1, numbers))),
      )
    PdfStreamObject(stream) =>
      @syntax.pdf_stream(
        pdf_import_renumber(stream.dictionary, numbers),
        stream.data,
      )
    other => other
  }
}
