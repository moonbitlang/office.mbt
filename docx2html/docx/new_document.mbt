// The write foundation's first brick: a minimal, schema-valid blank
// document, assembled with the OPC builder. Content authoring (paragraphs,
// styles beyond Normal, numbering, media) is deliberately NOT here — the
// F-series adds it behind fail-closed writers. Every emitted package is
// gated by both validation tiers in tests (the portable structural
// validator and the Microsoft SDK).

///|
/// `word/document.xml` of a blank document: one empty paragraph (Word
/// expects a body with at least one block) and the body-final section with
/// Letter page size and one-inch margins — the same shapes as the
/// SDK-validated header-footer fixture, minus the references.
const BLANK_DOCUMENT_XML : String =
  #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:body></w:document>

///|
/// Minimal `word/styles.xml`: document defaults plus the Normal paragraph
/// style every paragraph implicitly uses.
const BLANK_STYLES_XML : String =
  #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:rPrDefault><w:pPrDefault/></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style></w:styles>

///|
/// Builds a minimal, schema-valid blank docx: one empty paragraph, a
/// body-final section (Letter, one-inch margins), and a Normal style. All
/// inputs are compile-time constants, so builder failures are programming
/// errors — hence the abort rather than a raise.
pub fn new_blank_docx() -> Bytes {
  try! blank_docx_builder().build()
}

///|
/// Like `new_blank_docx`, but serialized under `limits` so a fresh-creation
/// transaction can bound the candidate BEFORE allocation (the blank package is
/// a small constant, so this never actually breaches — it keeps the create
/// path on the same bounded-writer contract as authored documents). An over-
/// limit ceiling surfaces as the typed `WriteResourceLimit`.
pub fn new_blank_docx_limited(
  limits : @opc.PackageLimits,
) -> Bytes raise DocxError {
  blank_docx_builder().build_limited(limits) catch {
    @opc.PackageLimitExceeded(kind~, limit~, actual~) =>
      raise WriteResourceLimit(
        kind~,
        limit~,
        actual~,
        message="package \{kind} ceiling exceeded: limit \{limit}, actual \{actual}",
      )
    err =>
      raise Unsupported(message="could not assemble the blank document: \{err}")
  }
}

///|
/// The shared blank-document package assembly. All inputs are compile-time
/// constants, so any `add_*` failure is a programming error.
fn blank_docx_builder() -> @opc.PackageBuilder raise @opc.PackageBuildError {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/styles.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId1",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "styles.xml",
    source="word/document.xml",
  )
  builder.add_part("word/document.xml", @utf8.encode(BLANK_DOCUMENT_XML))
  builder.add_part("word/styles.xml", @utf8.encode(BLANK_STYLES_XML))
  builder
}
