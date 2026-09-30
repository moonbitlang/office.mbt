///|
// Fonts of the caller's own, beside the bundled ones.
//
// A `FontRegistry` is an explicit value: a frontend creates one per
// document (or per set of documents sharing a font catalog), registers its
// faces, and hands the same value to whatever measures text and to the
// renderer that embeds the fonts (`@pdf.RenderOptions`). Nothing about it
// is process-wide, so two documents with different faces under the same
// family name cannot see each other's.
//
// Its lifetime has two phases. While it is *open*, faces can be added. The
// first lookup of any kind *seals* it, and from then on registration
// raises `FontRegistryError::Sealed`. That is what keeps measurement and
// rendering in step: once layout has asked for a face, the answer can no
// longer change underneath a laid-out model — a bold face registered after
// the layout measured bold with the regular fallback would otherwise be
// drawn at widths nobody measured. Registering the same family and style
// twice raises `FontRegistryError::Duplicate` for the same reason; nothing
// is ever replaced.
//
// A registry is a plain mutable value with no locking. Register from one
// task; once sealed it is read-only and may be shared freely.

///|
/// Why a `FontRegistry` refused a face.
pub(all) suberror FontRegistryError {
  /// The registry was already consulted, so its answers are fixed. The
  /// payload names the face (`family|bold|italic`) that came too late.
  Sealed(String)
  /// A face of this family and style (`family|bold|italic`) is already
  /// registered.
  Duplicate(String)
  /// `register_standard` was given a name that is not one of the twelve
  /// Latin standard fonts it supports (`standard_fonts`): a misspelling,
  /// an alias such as `Arial`, or one of the symbolic `Symbol` and
  /// `ZapfDingbats`, whose built-in encodings are not WinAnsi. The payload
  /// is the name.
  UnsupportedStandard(String)
} derive(Eq)

///|
pub extend FontRegistryError with Eq::{not_equal, equal}

///|
pub extend FontRegistryError with Show::{to_string, output}

///|
pub impl Show for FontRegistryError with fn output(self, logger) {
  match self {
    Sealed(face) =>
      logger.write_string(
        "font registry already in use; cannot register \{face}",
      )
    Duplicate(face) => logger.write_string("font already registered: \{face}")
    UnsupportedStandard("Symbol" | "ZapfDingbats" as standard) =>
      logger.write_string(
        "unsupported PDF standard font: \{standard} (a symbolic font, not WinAnsi-encoded)",
      )
    UnsupportedStandard(standard) => {
      let names = standard_fonts()
      let expected = names[:names.length() - 1].join(", ") +
        " or " +
        names[names.length() - 1]
      logger.write_string(
        "not a PDF standard font: \{standard} (expected \{expected})",
      )
    }
  }
}

///|
/// The PDF standard fonts `FontRegistry::register_standard` accepts, by
/// PostScript name: the twelve Latin faces of Helvetica, Times and Courier,
/// all declared with `/WinAnsiEncoding`. The two symbolic standard fonts,
/// `Symbol` and `ZapfDingbats`, are not among them: their text would be
/// encoded in each font's own built-in encoding (Prawn omits `/Encoding`
/// for them), which the renderer does not implement.
pub fn standard_fonts() -> Array[String] {
  [
    "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique",
    "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic", "Courier", "Courier-Bold",
    "Courier-Oblique", "Courier-BoldOblique",
  ]
}

///|
/// One registered face: the metrics layout measures with and how a PDF
/// draws it. A face registered from an sfnt (`register`) takes both its
/// metrics and its program from the same bytes, so that they cannot
/// disagree about glyph ids or widths. A standard font
/// (`register_standard`) has no program: the viewer draws it with its own
/// copy of the font, whose widths the metrics must be (see
/// `register_standard`).
pub struct RegisteredFace {
  metrics : FaceMetrics
  /// The complete sfnt to embed, or None when the bytes carry no TrueType
  /// outlines (no `glyf`/`loca`, as in a metrics-only sfnt or a CFF-flavoured
  /// OpenType font). A face without a program is declared in a PDF by name
  /// and drawn by whatever the viewer substitutes.
  program : Bytes?
  /// The PDF standard font the face is, when it is one: one of the twelve
  /// Latin faces of `standard_fonts` (`Helvetica`, `Times-Bold`, ...),
  /// declared by that name as a Type1 font with `/WinAnsiEncoding` and no
  /// program.
  standard : String?
}

///|
/// A set of faces registered by the caller, consulted before the bundled
/// ones. See the module comment for its open/sealed lifetime.
pub struct FontRegistry {
  priv faces : Map[String, RegisteredFace]
  priv mut closed : Bool
}

///|
/// An empty, open registry. With nothing registered it resolves exactly
/// as the package-level functions do: bundled faces only.
pub fn FontRegistry::new() -> FontRegistry {
  { faces: Map([]), closed: false, }
}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend FontRegistry with Default::{default}

///|
/// Same as `FontRegistry::new`.
pub impl Default for FontRegistry with fn default() {
  FontRegistry::new()
}

///|
/// Register a face from a complete, uncompressed sfnt (a `.ttf` file's
/// bytes) and return its metrics. Metrics and program are registered
/// together, from the same bytes.
///
/// A registered family resolves to itself (matched exactly, case and all)
/// and shadows a bundled family of the same name — Noto Sans SC, the CJK
/// fallback, included (see `cjk_fallback`). Raises
/// `FontRegistryError` when the registry is sealed or the face is already
/// registered, and a parse error when the bytes are not a usable sfnt.
pub fn FontRegistry::register(
  self : FontRegistry,
  family : String,
  sfnt : Bytes,
  bold? : Bool = false,
  italic? : Bool = false,
) -> FaceMetrics raise {
  let key = face_key(family, bold, italic)
  if self.closed {
    raise FontRegistryError::Sealed(key)
  }
  if self.faces.contains(key) {
    raise FontRegistryError::Duplicate(key)
  }
  let metrics = parse_sfnt(family, bold, italic, sfnt)
  let program = if @pdflite.pdf_truetype_table(sfnt, "glyf") is Some(_) &&
    @pdflite.pdf_truetype_table(sfnt, "loca") is Some(_) {
    Some(sfnt)
  } else {
    None
  }
  self.faces[key] = { metrics, program, standard: None, }
  metrics
}

///|
/// Register a PDF standard font under `family` and return the metrics
/// layout will measure it with. `standard` is its PostScript name, one of
/// the twelve Latin faces of `standard_fonts` (`Helvetica`,
/// `Helvetica-Bold`, `Times-Roman`, `Courier-Oblique`, ...); `metrics` are
/// its metrics, built with `FaceMetrics::new` from the font's AFM.
///
/// A PDF declares the font by name as a Type1 font with `/WinAnsiEncoding`
/// and embeds nothing, so a viewer draws it with its own copy of the font
/// and advances each glyph by that copy's width. Its text is encoded over
/// the whole of WinAnsi (0x80–0x9F included: `€`, `’`, `™`, ...);
/// characters WinAnsi lacks are dropped, their advances kept. For glyphs to
/// land where the layout put them, `metrics` must measure each character
/// WinAnsi encodes with the font's AFM width: conventionally a `cmap` from
/// each such character to its WinAnsi code and `advances` indexed by code,
/// at 1000 units per em. Kerning is not part of the metrics; a caller that
/// kerns puts the kerned advances in its runs (`GlyphRun::advances_pt`) and
/// the renderer shows the difference as a displacement.
///
/// Like `register`, the face is registered under `family` and the style
/// given: the returned metrics are `metrics` with that family, bold and
/// italic (the tables unchanged), so that a run laid out with them names
/// the registered family and is drawn in this face — not in whatever
/// `metrics.family` (say `Helvetica`) would otherwise resolve to.
///
/// Raises `FontRegistryError` when the registry is sealed, the face is
/// already registered, or `standard` is not a supported name
/// (`UnsupportedStandard`).
pub fn FontRegistry::register_standard(
  self : FontRegistry,
  family : String,
  metrics : FaceMetrics,
  standard~ : String,
  bold? : Bool = false,
  italic? : Bool = false,
) -> FaceMetrics raise FontRegistryError {
  let key = face_key(family, bold, italic)
  if self.closed {
    raise Sealed(key)
  }
  if self.faces.contains(key) {
    raise Duplicate(key)
  }
  if !standard_fonts().contains(standard) {
    raise UnsupportedStandard(standard)
  }
  // the face's identity is its registration, as `register` gives it; the
  // tables are immutable and shared
  let metrics = { ..metrics, family, bold, italic, }
  self.faces[key] = { metrics, program: None, standard: Some(standard), }
  metrics
}

///|
/// Stop accepting faces. Every lookup does this implicitly; calling it
/// makes the point explicit (before sharing the registry, say).
pub fn FontRegistry::seal(self : FontRegistry) -> Unit {
  self.closed = true
}

///|
/// Whether the registry has stopped accepting faces.
pub fn FontRegistry::is_sealed(self : FontRegistry) -> Bool {
  self.closed
}

///|
/// Whether any face of `family` (matched exactly) is registered. Seals.
pub fn FontRegistry::is_registered(
  self : FontRegistry,
  family : String,
) -> Bool {
  self.closed = true
  self.has_family(family)
}

///|
fn FontRegistry::has_family(self : FontRegistry, family : String) -> Bool {
  self.faces.contains(face_key(family, false, false)) ||
  self.faces.contains(face_key(family, true, false)) ||
  self.faces.contains(face_key(family, false, true)) ||
  self.faces.contains(face_key(family, true, true))
}

///|
/// `resolve_family`, with registered families passed through unchanged.
/// Seals.
pub fn FontRegistry::resolve_family(
  self : FontRegistry,
  name : String,
) -> String {
  self.closed = true
  if self.has_family(name) {
    name
  } else {
    resolve_family(name)
  }
}

///|
/// The registered face that stands for `family` in the requested style, or
/// None when no face of `family` is registered. Seals.
///
/// A missing style falls back within the family, never outside it: the
/// exact face, then the face without italic, then without bold, then the
/// regular face, then whichever face the family does have. Metrics and
/// program always come from that one face, so a document asking for a
/// style the catalog lacks is measured and drawn in the same substitute.
pub fn FontRegistry::registered_face(
  self : FontRegistry,
  family : String,
  bold? : Bool = false,
  italic? : Bool = false,
) -> RegisteredFace? {
  self.closed = true
  let candidates = [
    (bold, italic),
    (bold, false),
    (false, italic),
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]
  for candidate in candidates {
    match self.faces.get(face_key(family, candidate.0, candidate.1)) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
/// The metrics for a family name as `resolve_family` returns it: the
/// registered face (see `registered_face` for style fallback), else the
/// bundled one (see the package-level `face`). Seals.
pub fn FontRegistry::face(
  self : FontRegistry,
  family : String,
  bold? : Bool = false,
  italic? : Bool = false,
) -> FaceMetrics {
  match self.registered_face(family, bold~, italic~) {
    Some(registered) => registered.metrics
    None => face(family, bold~, italic~)
  }
}

///|
/// The face for CJK codepoints the requested face lacks, as this registry
/// resolves it: the fallback family (Noto Sans SC) through `face`, so a
/// registered face of that family is the fallback — style fallback
/// included — and shadows the bundled one entirely. Seals.
///
/// This is exactly the face a renderer resolves for a run the layout
/// placed in the fallback family with this style, so a fallback character
/// is measured with the metrics it is drawn with. When the registered
/// fallback lacks a character, the bundled one is *not* consulted: a run
/// cannot name it apart from the registered face. See `uncovered`.
pub fn FontRegistry::cjk_fallback(
  self : FontRegistry,
  bold? : Bool = false,
  italic? : Bool = false,
) -> FaceMetrics {
  let family = cjk_fallback().family
  self.face(self.resolve_family(family), bold~, italic~)
}

///|
/// The package-level `uncovered`, asked of this registry's faces: the
/// requested face as `face` resolves it, then `cjk_fallback` in the same
/// style — the two faces layout measures with. Seals.
pub fn FontRegistry::uncovered(
  self : FontRegistry,
  text : String,
  family : String,
  bold? : Bool = false,
  italic? : Bool = false,
) -> Array[(Int, Int)] {
  uncovered_by(
    text,
    self.face(self.resolve_family(family), bold~, italic~),
    self.cjk_fallback(bold~, italic~),
  )
}
