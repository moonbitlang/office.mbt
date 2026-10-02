// Export configuration: PDF versions, validators and validation errors
// (port of krilla's `configure` module).

///|
/// A PDF version.
pub(all) enum PdfVersion {
  Pdf14
  Pdf15
  Pdf16
  Pdf17
  Pdf20
} derive(Eq, Compare, Show)

///|
pub fn PdfVersion::as_str(self : PdfVersion) -> String {
  match self {
    Pdf14 => "PDF 1.4"
    Pdf15 => "PDF 1.5"
    Pdf16 => "PDF 1.6"
    Pdf17 => "PDF 1.7"
    Pdf20 => "PDF 2.0"
  }
}

///|
/// The version in the file header (e.g. `1.7`).
pub fn PdfVersion::header(self : PdfVersion) -> String {
  match self {
    Pdf14 => "1.4"
    Pdf15 => "1.5"
    Pdf16 => "1.6"
    Pdf17 => "1.7"
    Pdf20 => "2.0"
  }
}

///|
pub fn PdfVersion::deprecates_cid_set(self : PdfVersion) -> Bool {
  self >= Pdf20
}

///|
pub fn PdfVersion::specifies_associated_files(self : PdfVersion) -> Bool {
  self == Pdf20
}

///|
/// An archival (PDF/A) validator.
pub(all) enum Archival {
  A1_A
  A1_B
  A2_A
  A2_B
  A2_U
  A3_A
  A3_B
  A3_U
  A4
  A4F
  A4E
} derive(Eq, Show)

///|
/// An accessibility (PDF/UA) validator.
pub(all) enum Accessibility {
  UA1
} derive(Eq, Show)

///|
/// A validator.
pub(all) enum Validator {
  A(Archival)
  Ua(Accessibility)
} derive(Eq, Show)

///|
pub fn Validator::as_str(self : Validator) -> String {
  match self {
    A(a) => a.as_str()
    Ua(UA1) => "PDF/UA-1"
  }
}

///|
pub fn Validator::max(self : Validator) -> PdfVersion {
  match self {
    A(A1_A | A1_B) => Pdf14
    A(A2_A | A2_B | A2_U | A3_A | A3_B | A3_U) => Pdf17
    A(A4 | A4F | A4E) => Pdf20
    Ua(UA1) => Pdf17
  }
}

///|
pub fn Archival::as_str(self : Archival) -> String {
  match self {
    A1_A => "PDF/A-1a"
    A1_B => "PDF/A-1b"
    A2_A => "PDF/A-2a"
    A2_B => "PDF/A-2b"
    A2_U => "PDF/A-2u"
    A3_A => "PDF/A-3a"
    A3_B => "PDF/A-3b"
    A3_U => "PDF/A-3u"
    A4 => "PDF/A-4"
    A4F => "PDF/A-4f"
    A4E => "PDF/A-4e"
  }
}

///|
/// The active validators: at most one archival and one accessibility
/// validator.
pub(all) struct Validators {
  a : Archival?
  ua : Accessibility?
} derive(Eq, Show)

///|
pub fn Validators::empty() -> Validators {
  { a: None, ua: None, }
}

///|
pub fn Validators::is_empty(self : Validators) -> Bool {
  self.a is None && self.ua is None
}

///|
/// The validators in order (archival first).
pub fn Validators::to_array(self : Validators) -> Array[Validator] {
  let out = []
  if self.a is Some(a) {
    out.push(Validator::A(a))
  }
  if self.ua is Some(ua) {
    out.push(Validator::Ua(ua))
  }
  out
}

///|
/// The validators that prohibit the error, if any.
pub fn Validators::prohibits(
  self : Validators,
  error : ValidationError,
) -> Validators? {
  let a = match self.a {
    Some(a) if archival_prohibits(a, error) => Some(a)
    _ => None
  }
  let ua = match self.ua {
    Some(ua) if accessibility_prohibits(ua, error) => Some(ua)
    _ => None
  }
  if a is None && ua is None {
    None
  } else {
    Some({ a, ua, })
  }
}

///|
pub fn Validators::requires_codepoint_mappings(self : Validators) -> Bool {
  (match self.a {
    Some(A1_A | A2_A | A2_U | A3_A | A3_U | A4 | A4F | A4E) => true
    _ => false
  }) ||
  self.ua is Some(_)
}

///|
pub fn Validators::requires_display_doc_title(self : Validators) -> Bool {
  self.ua is Some(_)
}

///|
pub fn Validators::requires_tagging(self : Validators) -> Bool {
  self.a is Some(A1_A | A2_A | A3_A) || self.ua is Some(_)
}

///|
pub fn Validators::requires_annotation_flags(self : Validators) -> Bool {
  self.a is Some(_)
}

///|
pub fn Validators::prohibits_info_dict(self : Validators) -> Bool {
  self.a is Some(A4 | A4F | A4E)
}

///|
pub fn Validators::requires_embedded_files_when_empty(
  self : Validators,
) -> Bool {
  self.a is Some(A4F)
}

///|
pub fn Validators::specifies_associated_files(self : Validators) -> Bool {
  self.a is Some(A3_A | A3_B | A3_U)
}

///|
/// A configuration: a PDF version and validators.
pub(all) struct Configuration {
  version : PdfVersion
  validators : Validators
} derive(Eq, Show)

///|
pub fn Configuration::default() -> Configuration {
  { version: Pdf17, validators: Validators::empty(), }
}

///|
/// A feature that requires a minimum PDF version.
pub(all) enum VersionedFeature {
  StructureOrderTabbing
  HeaderFooterArtifactSubtypes
  TableHeaderScope
} derive(Eq, Show)

///|
pub fn VersionedFeature::minimum_pdf_version(
  self : VersionedFeature,
) -> PdfVersion {
  match self {
    StructureOrderTabbing => Pdf15
    HeaderFooterArtifactSubtypes => Pdf17
    TableHeaderScope => Pdf15
  }
}

///|
/// An error raised when embedding a file.
pub(all) enum EmbedError {
  Existence
  MissingDate
  MissingDescription
  MissingMimeType
} derive(Eq, Show)

///|
/// A location: an opaque identifier provided by the user (Typst passes raw
/// spans).
pub type Location = UInt64

///|
/// An error that violates a validator.
pub(all) enum ValidationError {
  TooLongString
  TooLongName
  TooLongArray
  TooLongDictionary
  TooLargeFloat
  TooManyIndirectObjects
  TooHighQNestingLevel
  ContainsPostScript(Location?)
  MissingCMYKProfile
  InconsistentSeparationFallback(SeparationColorant)
  ContainsNotDefGlyph(Font, Location?, String)
  NoCodepointMapping(Font, Int, Location?)
  InvalidCodepointMapping(Font, Int, Char, Location?)
  UnicodePrivateArea(Font, Int, Char, Location?)
  RestrictedLicense(Font)
  NoDocumentLanguage
  NoDocumentTitle
  MissingAltText(Location?)
  MissingHeadingTitle
  MissingDocumentOutline
  MissingAnnotationAltText(Location?)
  MissingDocumentDate
  Transparency(Location?)
  ImageInterpolation(Location?)
  EmbeddedFile(EmbedError, Location?)
  MissingTagging
  EmbeddedPDF(Location?)
  RequiresNewerPdfVersion(VersionedFeature, Location?)
}

///|
/// Structural equality of validation errors (fonts by identity), used to
/// deduplicate errors.
pub fn ValidationError::same(
  self : ValidationError,
  other : ValidationError,
) -> Bool {
  match (self, other) {
    (TooLongString, TooLongString)
    | (TooLongName, TooLongName)
    | (TooLongArray, TooLongArray)
    | (TooLongDictionary, TooLongDictionary)
    | (TooLargeFloat, TooLargeFloat)
    | (TooManyIndirectObjects, TooManyIndirectObjects)
    | (TooHighQNestingLevel, TooHighQNestingLevel)
    | (MissingCMYKProfile, MissingCMYKProfile)
    | (NoDocumentLanguage, NoDocumentLanguage)
    | (NoDocumentTitle, NoDocumentTitle)
    | (MissingHeadingTitle, MissingHeadingTitle)
    | (MissingDocumentOutline, MissingDocumentOutline)
    | (MissingDocumentDate, MissingDocumentDate)
    | (MissingTagging, MissingTagging) => true
    (ContainsPostScript(a), ContainsPostScript(b)) => a == b
    (InconsistentSeparationFallback(a), InconsistentSeparationFallback(b)) =>
      a == b
    (ContainsNotDefGlyph(f, l, t), ContainsNotDefGlyph(g, m, u)) =>
      physical_equal(f, g) && l == m && t == u
    (NoCodepointMapping(f, a, l), NoCodepointMapping(g, b, m)) =>
      physical_equal(f, g) && a == b && l == m
    (InvalidCodepointMapping(f, a, c, l), InvalidCodepointMapping(g, b, d, m)) =>
      physical_equal(f, g) && a == b && c == d && l == m
    (UnicodePrivateArea(f, a, c, l), UnicodePrivateArea(g, b, d, m)) =>
      physical_equal(f, g) && a == b && c == d && l == m
    (RestrictedLicense(f), RestrictedLicense(g)) => physical_equal(f, g)
    (MissingAltText(a), MissingAltText(b)) => a == b
    (MissingAnnotationAltText(a), MissingAnnotationAltText(b)) => a == b
    (Transparency(a), Transparency(b)) => a == b
    (ImageInterpolation(a), ImageInterpolation(b)) => a == b
    (EmbeddedFile(e, a), EmbeddedFile(f, b)) => e == f && a == b
    (EmbeddedPDF(a), EmbeddedPDF(b)) => a == b
    (RequiresNewerPdfVersion(f, a), RequiresNewerPdfVersion(g, b)) =>
      f == g && a == b
    _ => false
  }
}

///|
fn archival_prohibits(a : Archival, error : ValidationError) -> Bool {
  let self_ = a
  match a {
    A1_A | A1_B =>
      match error {
        TooLongString
        | TooLongName
        | TooLongArray
        | TooLongDictionary
        | TooLargeFloat
        | TooManyIndirectObjects
        | TooHighQNestingLevel
        | ContainsPostScript(_)
        | MissingCMYKProfile
        | RestrictedLicense(_)
        | MissingDocumentDate
        | Transparency(_)
        | ImageInterpolation(_)
        | EmbeddedFile(Existence, _)
        | EmbeddedPDF(_) => true
        InconsistentSeparationFallback(_)
        | InvalidCodepointMapping(_, _, _, _)
        | UnicodePrivateArea(_, _, _, _)
        | NoDocumentTitle
        | MissingHeadingTitle
        | MissingDocumentOutline
        | EmbeddedFile(_, _)
        | RequiresNewerPdfVersion(_, _) => false
        ContainsNotDefGlyph(_, _, _)
        | NoCodepointMapping(_, _, _)
        | NoDocumentLanguage
        | MissingAltText(_)
        | MissingAnnotationAltText(_)
        | MissingTagging => self_ == A1_A
      }
    A2_A | A2_B | A2_U | A3_A | A3_B | A3_U =>
      match error {
        TooLongString
        | TooLongName
        | TooManyIndirectObjects
        | TooHighQNestingLevel
        | ContainsPostScript(_)
        | MissingCMYKProfile
        | InconsistentSeparationFallback(_)
        | ContainsNotDefGlyph(_, _, _)
        | RestrictedLicense(_)
        | MissingDocumentDate
        | ImageInterpolation(_)
        | EmbeddedPDF(_) => true
        TooLongArray
        | TooLongDictionary
        | TooLargeFloat
        | NoDocumentTitle
        | Transparency(_)
        | MissingHeadingTitle
        | MissingDocumentOutline
        | RequiresNewerPdfVersion(_, _) => false
        EmbeddedFile(Existence, _) => self_ is (A2_A | A2_B | A2_U)
        EmbeddedFile(_, _) => self_ is (A3_A | A3_B | A3_U)
        UnicodePrivateArea(_, _, _, _)
        | NoDocumentLanguage
        | MissingAltText(_)
        | MissingAnnotationAltText(_)
        | MissingTagging => self_ is (A2_A | A3_A)
        NoCodepointMapping(_, _, _) | InvalidCodepointMapping(_, _, _, _) =>
          self_ is (A2_A | A2_U | A3_A | A3_U)
      }
    A4 | A4F | A4E =>
      match error {
        MissingCMYKProfile
        | InconsistentSeparationFallback(_)
        | ContainsNotDefGlyph(_, _, _)
        | NoCodepointMapping(_, _, _)
        | InvalidCodepointMapping(_, _, _, _)
        | UnicodePrivateArea(_, _, _, _)
        | RestrictedLicense(_)
        | MissingDocumentDate
        | ImageInterpolation(_)
        | EmbeddedPDF(_) => true
        EmbeddedFile(Existence, _) => self_ == A4
        EmbeddedFile(MissingDescription, _) => self_ == A4
        _ => false
      }
  }
}

///|
fn accessibility_prohibits(_a : Accessibility, error : ValidationError) -> Bool {
  match error {
    ContainsNotDefGlyph(_, _, _)
    | NoCodepointMapping(_, _, _)
    | InvalidCodepointMapping(_, _, _, _)
    | RestrictedLicense(_)
    | NoDocumentTitle
    | MissingAltText(_)
    | MissingHeadingTitle
    | MissingDocumentOutline
    | MissingAnnotationAltText(_)
    | EmbeddedFile(MissingDescription, _)
    | MissingTagging
    | EmbeddedPDF(_)
    | RequiresNewerPdfVersion(_, _) => true
    _ => false
  }
}
