///|
// What `render_pdf` can be asked for beyond the page model itself.

///|
/// Everything `render_pdf` takes besides the model. Build one with
/// `RenderOptions::new`, naming only what differs from the default; the
/// default (`RenderOptions::default()`) renders exactly as `render_pdf(model)`
/// always has: bundled fonts, no outline, no metadata, no catalog settings.
pub struct RenderOptions {
  /// The faces the model was measured with. Registered families are drawn
  /// (and, when the face has TrueType outlines, embedded) from here; every
  /// other family from the bundle. Rendering seals the registry.
  fonts : @fonts.FontRegistry
  /// The document outline (bookmarks), in document order.
  outline : Array[OutlineEntry]
  /// The document information dictionary.
  info : DocumentInfo
  /// How the first page fits the window when the document opens.
  initial_zoom : InitialZoom?
  /// The catalog's `/PageMode`. None writes `/UseOutlines` when there is an
  /// outline and nothing otherwise.
  page_mode : PageMode?
  /// Always write `/ViewerPreferences /DisplayDocTitle true` (it is written
  /// anyway when `info` has a title).
  display_doc_title : Bool
  /// Write every page's crop, bleed, trim and art boxes explicitly (equal to
  /// its media box) instead of leaving them to their defaults.
  page_boxes : Bool
  /// Literal page labels, one per page: page `i` is labelled
  /// `page_labels[i]`. Empty writes no labels; any other length than the
  /// model's page count is rejected, since a PDF label range runs on to the
  /// end of the document and would repeat the last label over every page it
  /// did not name.
  page_labels : Array[String]
  /// Declare glyph widths truncated to whole thousandths of an em, as Prawn
  /// does, instead of rounded: a layout that places glyphs by Prawn's widths
  /// then needs no displacements.
  truncate_widths : Bool
}

///|
/// Options for `render_pdf`; everything left out takes its default.
pub fn RenderOptions::new(
  fonts? : @fonts.FontRegistry = @fonts.FontRegistry::new(),
  outline? : Array[OutlineEntry] = [],
  info? : DocumentInfo = DocumentInfo::new(),
  initial_zoom? : InitialZoom,
  page_mode? : PageMode,
  display_doc_title? : Bool = false,
  page_boxes? : Bool = false,
  page_labels? : Array[String] = [],
  truncate_widths? : Bool = false,
) -> RenderOptions {
  {
    fonts,
    outline,
    info,
    initial_zoom,
    page_mode,
    display_doc_title,
    page_boxes,
    page_labels,
    truncate_widths,
  }
}

///|
/// Same as `RenderOptions::new()`.
pub impl Default for RenderOptions with fn default() {
  RenderOptions::new()
}

///|
/// Options `render_pdf` cannot honour; nothing is written. The payload
/// says what was wrong.
pub(all) suberror RenderOptionError {
  RenderOptionError(String)
} derive(Eq)

///|
pub extend RenderOptionError with Eq::{not_equal, equal}

///|
pub extend RenderOptionError with Show::{to_string, output}

///|
pub impl Show for RenderOptionError with fn output(self, logger) {
  let RenderOptionError(message) = self
  logger.write_string("invalid PDF render options: \{message}")
}

///|
/// How the first page fits the window when the document opens (the
/// `/OpenAction` destination): the whole page, its width, or its height.
pub(all) enum InitialZoom {
  Fit
  FitH
  FitV
} derive(Eq, Debug)

///|
/// The catalog's `/PageMode` (PDF 32000-1, Table 28): what the viewer shows
/// beside the pages when the document opens.
pub(all) enum PageMode {
  /// Neither the outline nor thumbnails (`/UseNone`).
  UseNone
  /// The outline panel (`/UseOutlines`).
  UseOutlines
  /// Page thumbnails (`/UseThumbs`).
  UseThumbs
  /// Full-screen mode, no menu bar or window controls (`/FullScreen`).
  FullScreen
  /// The optional content group panel (`/UseOC`).
  UseOC
  /// The attachments panel (`/UseAttachments`).
  UseAttachments
} derive(Eq, Debug)

///|
fn PageMode::pdf_name(self : PageMode) -> String {
  match self {
    UseNone => "/UseNone"
    UseOutlines => "/UseOutlines"
    UseThumbs => "/UseThumbs"
    FullScreen => "/FullScreen"
    UseOC => "/UseOC"
    UseAttachments => "/UseAttachments"
  }
}

///|
/// Where an outline entry jumps.
pub(all) enum OutlineDest {
  /// The `AnchorItem` of this name (its named destination). An anchor name
  /// the model does not define leaves the entry without a destination: it
  /// is still listed, and opens nothing.
  Named(String)
  /// A place no anchor marks: page index `page` (0-based), with the point
  /// (`x`, `y` down from the page top, points) at the window's top left. A
  /// page the model does not have leaves the entry without a destination.
  Position(page~ : Int, x~ : Double, y~ : Double)
} derive(Eq, Debug)

///|
/// One entry of the document outline (bookmarks). `level` 0 is the top
/// level, and each entry nests under the nearest preceding entry of a lower
/// level (a jump of several levels nests directly under that entry). An
/// `open` entry shows its children when the document opens (a positive
/// `/Count`); otherwise they start collapsed.
pub(all) struct OutlineEntry {
  title : String
  level : Int
  dest : OutlineDest
  open : Bool
} derive(Eq, Debug)

///|
/// The document's `/Trapped` entry (PDF 32000-1, Table 317): whether it has
/// been trapped for printing.
pub(all) enum Trapped {
  /// `/True`: fully trapped.
  Yes
  /// `/False`: not trapped.
  No
  /// `/Unknown`: not known, or partly trapped.
  Unknown
} derive(Eq, Debug)

///|
/// The document information dictionary (PDF 32000-1, §14.3.3), typed as the
/// standard requires: text strings, dates and the `/Trapped` name. Absent
/// fields are not written.
///
/// Dates are PDF date strings (`D:YYYYMMDDHHmmSS+HH'mm'`, see `pdf_date`);
/// `render_pdf` rejects any other form. `custom` holds further entries,
/// written as text strings; a custom key naming a standard entry is
/// rejected (set the typed field instead), as is an empty key.
pub struct DocumentInfo {
  title : String?
  author : String?
  subject : String?
  keywords : String?
  creator : String?
  producer : String?
  creation_date : String?
  mod_date : String?
  trapped : Trapped?
  custom : Array[(String, String)]
} derive(Eq, Debug)

///|
/// Document information; every field left out is not written.
pub fn DocumentInfo::new(
  title? : String,
  author? : String,
  subject? : String,
  keywords? : String,
  creator? : String,
  producer? : String,
  creation_date? : String,
  mod_date? : String,
  trapped? : Trapped,
  custom? : Array[(String, String)] = [],
) -> DocumentInfo {
  {
    title,
    author,
    subject,
    keywords,
    creator,
    producer,
    creation_date,
    mod_date,
    trapped,
    custom,
  }
}

///|
/// Whether nothing would be written.
fn DocumentInfo::is_empty(self : DocumentInfo) -> Bool {
  self.title is None &&
  self.author is None &&
  self.subject is None &&
  self.keywords is None &&
  self.creator is None &&
  self.producer is None &&
  self.creation_date is None &&
  self.mod_date is None &&
  self.trapped is None &&
  self.custom.is_empty()
}

///|
/// The keys Table 317 defines, which `custom` may not use.
let standard_info_keys : Array[String] = [
  "Title", "Author", "Subject", "Keywords", "Creator", "Producer", "CreationDate",
  "ModDate", "Trapped",
]

///|
/// The information dictionary's entries, in Table 317's order, then the
/// custom ones.
fn DocumentInfo::entries(
  self : DocumentInfo,
) -> Array[(@core.PdfName, @syntax.PdfObject)] raise RenderOptionError {
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = []
  let text = fn(key : String, value : String?) {
    match value {
      Some(v) => entries.push((name("/" + key), PdfString(text_string(v))))
      None => ()
    }
  }
  text("Title", self.title)
  text("Author", self.author)
  text("Subject", self.subject)
  text("Keywords", self.keywords)
  text("Creator", self.creator)
  text("Producer", self.producer)
  for date in [("CreationDate", self.creation_date), ("ModDate", self.mod_date)] {
    match date.1 {
      Some(value) => {
        if !is_pdf_date(value) {
          raise RenderOptionError(
            "info \{date.0} is not a PDF date (D:YYYYMMDDHHmmSS+HH'mm'): \{value}",
          )
        }
        entries.push((name("/" + date.0), PdfString(@utf8.encode(value))))
      }
      None => ()
    }
  }
  match self.trapped {
    Some(trapped) => {
      let value = match trapped {
        Yes => "/True"
        No => "/False"
        Unknown => "/Unknown"
      }
      entries.push((name("/Trapped"), PdfNameObject(name(value))))
    }
    None => ()
  }
  for entry in self.custom {
    let (key, value) = entry
    if key.is_empty() {
      raise RenderOptionError("info entry with an empty key")
    }
    if standard_info_keys.contains(key) {
      raise RenderOptionError(
        "info key \{key} is a standard entry; set DocumentInfo's field instead",
      )
    }
    entries.push((name("/" + key), PdfString(text_string(value))))
  }
  entries
}

///|
/// Whether `text` is a PDF date string (PDF 32000-1, §7.9.4):
/// `D:YYYY`, then optionally `MM`, `DD`, `HH`, `mm`, `SS` in turn, then
/// optionally a zone — `Z`, or `+`/`-` with `HH`, optionally `'mm`, and
/// optionally a trailing apostrophe.
fn is_pdf_date(text : String) -> Bool {
  let bytes = @utf8.encode(text)
  let digit = fn(i : Int) {
    i < bytes.length() && bytes[i] >= b'0' && bytes[i] <= b'9'
  }
  if bytes.length() < 6 || bytes[0] != b'D' || bytes[1] != b':' {
    return false
  }
  for i in 2..<6 {
    if !digit(i) {
      return false
    }
  }
  let mut i = 6
  // MM DD HH mm SS, each optional but only in order
  for _ in 0..<5 {
    if digit(i) && digit(i + 1) {
      i += 2
    } else {
      break
    }
  }
  if i == bytes.length() {
    return true
  }
  let zone = bytes[i]
  if zone != b'Z' && zone != b'+' && zone != b'-' {
    return false
  }
  i += 1
  let apostrophe = fn(i : Int) { i < bytes.length() && bytes[i] == b'\'' }
  if digit(i) && digit(i + 1) {
    i += 2
    if apostrophe(i) {
      i += 1
    }
    if digit(i) && digit(i + 1) {
      i += 2
      if apostrophe(i) {
        i += 1
      }
    }
  } else if zone != b'Z' {
    // an offset needs its hours
    return false
  }
  i == bytes.length()
}
