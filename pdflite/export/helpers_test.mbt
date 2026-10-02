// Shared helpers of the black-box tests: write documents with the exporter,
// read them back with pdflite's reader and render compact, deterministic
// summaries of the parsed objects.

///|
/// Settings used by most tests: uncompressed content streams, no XMP
/// metadata and no tagging, so that the summaries stay small.
fn plain_settings() -> @export.SerializeSettings {
  {
    ..@export.SerializeSettings::default(),
    compress_content_streams: false,
    xmp_metadata: false,
    enable_tagging: false,
  }
}

///|
/// Settings with a validator.
fn settings_with(
  a? : @export.Archival? = None,
  ua? : @export.Accessibility? = None,
  version? : @export.PdfVersion = Pdf17,
) -> @export.SerializeSettings {
  { ..plain_settings(), configuration: { version, validators: { a, ua, }, }, }
}

///|
/// A path from a rectangle.
fn rect_path(x : Double, y : Double, w : Double, h : Double) -> @export.Path {
  let pb = @export.PathBuilder::new()
  pb.push_rect(@export.Rect::from_xywh(x, y, w, h).unwrap())
  pb.finish().unwrap()
}

///|
fn solid(r : Int, g : Int, b : Int) -> @export.Paint {
  Color(@export.Color::rgb(r, g, b))
}

///|
fn stroke_of(paint : @export.Paint, width : Double) -> @export.Stroke {
  {
    paint,
    width,
    miter_limit: 10.0,
    line_cap: Butt,
    line_join: Miter,
    opacity: 1.0,
    dash: None,
  }
}

///|
/// Write a single page document; `draw` draws on the page surface.
fn one_page(
  draw : (@export.Surface) -> Unit raise,
  settings? : @export.SerializeSettings = plain_settings(),
  width? : Double = 200.0,
  height? : Double = 100.0,
) -> Bytes raise {
  let doc = @export.Document::new_with(settings)
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(width, height).unwrap(),
  )
  let surface = page.surface()
  draw(surface)
  surface.finish()
  page.finish()
  doc.finish()
}

///|
/// A parsed PDF.
struct Parsed {
  doc : @pdflite.PdfDocument
  bytes : Bytes
}

///|
fn parse(bytes : Bytes) -> Parsed raise {
  { doc: @pdflite.pdf_read_document_from_bytes(bytes), bytes, }
}

///|
fn name(s : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(ascii("/" + s))
}

///|
fn ascii(s : String) -> Bytes {
  let arr : Array[Byte] = []
  for c in s {
    arr.push(c.to_int().to_byte())
  }
  Bytes::from_array(arr)
}

///|
fn latin1(b : BytesView) -> String {
  let sb = StringBuilder()
  for x in b {
    sb.write_char(x.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Resolve an object.
fn Parsed::resolve(self : Parsed, obj : @syntax.PdfObject) -> @syntax.PdfObject {
  self.doc.direct(obj)
}

///|
/// Look up a dictionary entry (resolving references); fails if missing.
fn Parsed::get(
  self : Parsed,
  obj : @syntax.PdfObject,
  key : String,
) -> @syntax.PdfObject raise {
  let obj = match self.resolve(obj) {
    PdfStreamObject(s) => s.dictionary
    o => o
  }
  match self.doc.lookup_direct(name(key), obj) {
    Some(v) => v
    None => fail("missing /\{key}")
  }
}

///|
/// Whether a dictionary has an entry.
fn Parsed::has(self : Parsed, obj : @syntax.PdfObject, key : String) -> Bool {
  let obj = match self.resolve(obj) {
    PdfStreamObject(s) => s.dictionary
    o => o
  }
  self.doc.lookup_direct(name(key), obj) is Some(_)
}

///|
/// Follow a path of dictionary keys.
fn Parsed::path(
  self : Parsed,
  obj : @syntax.PdfObject,
  keys : Array[String],
) -> @syntax.PdfObject raise {
  let mut cur = obj
  for k in keys {
    cur = self.get(cur, k)
  }
  self.resolve(cur)
}

///|
/// Array elements (resolved).
fn Parsed::items(
  self : Parsed,
  obj : @syntax.PdfObject,
) -> Array[@syntax.PdfObject] raise {
  match self.resolve(obj) {
    PdfArray(items) => items.map(i => self.resolve(i))
    _ => fail("expected an array")
  }
}

///|
/// The keys of a dictionary (or stream dictionary), in file order.
fn Parsed::keys(self : Parsed, obj : @syntax.PdfObject) -> Array[String] raise {
  let obj = match self.resolve(obj) {
    PdfStreamObject(s) => s.dictionary
    o => o
  }
  match obj {
    PdfDictionary(entries) => entries.map(e => latin1(e.0.bytes()[1:]))
    _ => fail("expected a dictionary")
  }
}

///|
fn Parsed::catalog(self : Parsed) -> @syntax.PdfObject raise {
  self.doc.catalog()
}

///|
fn Parsed::trailer(self : Parsed) -> @syntax.PdfObject {
  self.doc.trailer_dict()
}

///|
/// The page dictionaries in order.
fn Parsed::pages(self : Parsed) -> Array[@syntax.PdfObject] raise {
  self.items(self.path(self.catalog(), ["Pages", "Kids"]))
}

///|
fn Parsed::page(self : Parsed, i : Int) -> @syntax.PdfObject raise {
  self.pages()[i]
}

///|
/// The decoded data of a stream.
fn Parsed::stream_data(self : Parsed, obj : @syntax.PdfObject) -> Bytes raise {
  let obj = self.resolve(obj)
  guard obj is PdfStreamObject(_) else { fail("expected a stream") }
  @pdflite.pdf_decode_stream(obj).stream_bytes()
}

///|
/// The decoded content stream of a page (or form XObject) as text.
fn Parsed::content(self : Parsed, page : @syntax.PdfObject) -> String raise {
  let page = self.resolve(page)
  let data = match page {
    PdfStreamObject(_) => self.stream_data(page)
    _ => self.stream_data(self.get(page, "Contents"))
  }
  latin1(data)
}

///|
/// A compact rendering of an object. References are shown as `R` (not
/// resolved), so that the output doesn't depend on object numbers.
fn Parsed::show(self : Parsed, obj : @syntax.PdfObject) -> String {
  let sb = StringBuilder()
  self.show_into(sb, obj, false)
  sb.to_string()
}

///|
/// Like `show`, but resolving references (one level deep per reference).
fn Parsed::show_deep(self : Parsed, obj : @syntax.PdfObject) -> String {
  let sb = StringBuilder()
  self.show_into(sb, obj, true)
  sb.to_string()
}

///|
fn Parsed::show_into(
  self : Parsed,
  sb : StringBuilder,
  obj : @syntax.PdfObject,
  deep : Bool,
) -> Unit {
  match obj {
    PdfNull => sb.write_string("null")
    PdfBoolean(b) => sb.write_string(b.to_string())
    PdfInteger(i) => sb.write_string(i.to_string())
    PdfReal(r) | PdfExactReal(r) => sb.write_string(@export.format_real(r))
    PdfString(s) => {
      let mut printable = true
      for b in s {
        if b < b'\x20' || b > b'\x7E' {
          printable = false
        }
      }
      if printable {
        sb.write_string("(\{latin1(s)})")
      } else {
        sb.write_char('<')
        for b in s {
          let hex = "0123456789ABCDEF"
          sb.write_char(hex[b.to_int() >> 4].unsafe_to_char())
          sb.write_char(hex[b.to_int() & 0xF].unsafe_to_char())
        }
        sb.write_char('>')
      }
    }
    PdfNameObject(n) => sb.write_string(latin1(n.bytes()))
    PdfArray(items) => {
      sb.write_char('[')
      for i, item in items {
        if i > 0 {
          sb.write_char(' ')
        }
        self.show_into(sb, item, deep)
      }
      sb.write_char(']')
    }
    PdfDictionary(entries) => {
      sb.write_string("<<")
      for i, e in entries {
        if i > 0 {
          sb.write_char(' ')
        }
        sb.write_string(latin1(e.0.bytes()))
        sb.write_char(' ')
        self.show_into(sb, e.1, deep)
      }
      sb.write_string(">>")
    }
    PdfStreamObject(s) => {
      sb.write_string("stream")
      self.show_into(sb, s.dictionary, deep)
    }
    PdfIndirect(_) =>
      if deep {
        self.show_into(sb, self.resolve(obj), false)
      } else {
        sb.write_char('R')
      }
  }
}

///|
/// Whether `s` contains `pat`.
fn contains(s : String, pat : String) -> Bool {
  s.contains(pat)
}

///|
/// The name of a validation error.
fn validation_error_name(e : @export.ValidationError) -> String {
  match e {
    TooLongString => "TooLongString"
    TooLongName => "TooLongName"
    TooLongArray => "TooLongArray"
    TooLongDictionary => "TooLongDictionary"
    TooLargeFloat => "TooLargeFloat"
    TooManyIndirectObjects => "TooManyIndirectObjects"
    TooHighQNestingLevel => "TooHighQNestingLevel"
    ContainsPostScript(_) => "ContainsPostScript"
    MissingCMYKProfile => "MissingCMYKProfile"
    InconsistentSeparationFallback(_) => "InconsistentSeparationFallback"
    ContainsNotDefGlyph(_, _, t) => "ContainsNotDefGlyph(\{t})"
    NoCodepointMapping(_, g, _) => "NoCodepointMapping(\{g})"
    InvalidCodepointMapping(_, g, c, _) =>
      "InvalidCodepointMapping(\{g}, U+\{c.to_int().to_string(radix=16)})"
    UnicodePrivateArea(_, g, c, _) =>
      "UnicodePrivateArea(\{g}, U+\{c.to_int().to_string(radix=16)})"
    RestrictedLicense(_) => "RestrictedLicense"
    NoDocumentLanguage => "NoDocumentLanguage"
    NoDocumentTitle => "NoDocumentTitle"
    MissingAltText(_) => "MissingAltText"
    MissingHeadingTitle => "MissingHeadingTitle"
    MissingDocumentOutline => "MissingDocumentOutline"
    MissingAnnotationAltText(_) => "MissingAnnotationAltText"
    MissingDocumentDate => "MissingDocumentDate"
    Transparency(_) => "Transparency"
    ImageInterpolation(_) => "ImageInterpolation"
    EmbeddedFile(kind, _) => "EmbeddedFile(\{@debug.to_string(kind)})"
    MissingTagging => "MissingTagging"
    EmbeddedPDF(_) => "EmbeddedPDF"
    RequiresNewerPdfVersion(f, _) =>
      "RequiresNewerPdfVersion(\{@debug.to_string(f)})"
  }
}

///|
/// A summary of an export error.
fn export_error_summary(e : Error) -> String {
  match e {
    @export.Validation(errors) =>
      "Validation: " +
      errors
      .map(e => {
        let vs = e.1.to_array().map(v => v.as_str()).join(", ")
        "\{validation_error_name(e.0)} by \{vs}"
      })
      .join("; ")
    @export.FontError(_, msg) => "FontError: \{msg}"
    @export.ImageError(_, msg) => "ImageError: \{msg}"
    @export.DuplicateTagId(id, _) => "DuplicateTagId: \{latin1(id)}"
    @export.UnknownTagId(id, _) => "UnknownTagId: \{latin1(id)}"
    @export.DuplicateNamedDestination(n) => "DuplicateNamedDestination: \{n}"
    e => "other: \{e}"
  }
}

///|
/// Run an export and summarize its error (or `ok`).
fn export_result(f : () -> Bytes raise) -> String {
  try f() catch {
    e => export_error_summary(e)
  } noraise {
    _ => "ok"
  }
}
