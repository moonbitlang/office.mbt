///|
// Theme font resolution. Real Word documents almost never name a font
// directly in docDefaults: they write `w:asciiTheme="minorHAnsi"` and let
// `word/theme/theme1.xml` supply the family. Without this, every such
// document resolves to whatever the hardcoded default happens to be —
// silently right when that matches the theme, silently wrong otherwise
// (Word 365's Aptos, any corporate template, and every `majorHAnsi`
// heading).

///|
/// The `a:latin` typefaces of a theme's major (heading) and minor (body)
/// font schemes.
pub(all) struct ThemeFonts {
  major : String?
  minor : String?
} derive(Eq, Debug, ToJson)

///|
/// A theme that names no fonts — used when the package has no theme
/// part, so the cascade falls through to the engine defaults.
pub fn ThemeFonts::empty() -> ThemeFonts {
  { major: None, minor: None, }
}

///|
fn scheme_latin(scheme : @xml.XmlElement) -> String? {
  match scheme.first("a:latin") {
    Some(latin) =>
      match latin.attributes.get("typeface") {
        Some(face) if face.length() > 0 => Some(face)
        _ => None
      }
    None => None
  }
}

///|
/// Parse an `a:theme` root element.
pub fn read_theme(root : @xml.XmlElement) -> ThemeFonts {
  let elements = root.first_or_empty("a:themeElements")
  let font_scheme = elements.first_or_empty("a:fontScheme")
  {
    major: match font_scheme.first("a:majorFont") {
      Some(s) => scheme_latin(s)
      None => None
    },
    minor: match font_scheme.first("a:minorFont") {
      Some(s) => scheme_latin(s)
      None => None
    },
  }
}

///|
/// Resolve an OOXML theme font reference. The `*HAnsi`/`*Ascii` and
/// East-Asian variants all select between the major and minor schemes;
/// anything unrecognized resolves to nothing so the cascade falls
/// through to a lower level.
pub fn ThemeFonts::resolve(self : ThemeFonts, reference : String) -> String? {
  if reference.has_prefix("major") {
    self.major
  } else if reference.has_prefix("minor") {
    self.minor
  } else {
    None
  }
}
