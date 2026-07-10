// Package-level document structure beyond the body story: header/footer
// parts and the sections that reference them. These are NEW additive types —
// `DocumentElement` itself is deliberately untouched (it is `pub(all)`;
// extending the enum would break downstream exhaustive matches).

///|
/// One header or footer part: a block-level story like the body.
pub(all) struct HeaderFooterPart {
  body : Array[DocumentElement]
} derive(Debug, Eq)

///|
/// A section's reference to a header/footer part. `variant` is the OOXML
/// reference type (`default`, `first`, or `even`); `part` is a 0-based index
/// into the package's `headers` or `footers` array (parts are shared —
/// several sections may reference the same part).
pub(all) struct SectionRef {
  variant : String
  part : Int
} derive(Debug, Eq)

///|
/// One document section. `ends_after_paragraph` is the 1-based index of the
/// section's last direct body paragraph (a paragraph-level `w:sectPr`
/// section break); `None` means the section runs to the end of the body.
/// Indices count the raw body's direct paragraphs in document order. Every
/// document has at least one section (the final section exists even without
/// an explicit body-final `w:sectPr`). `headers`/`footers` are the
/// section's EFFECTIVE references — OOXML inheritance applied: a section
/// without an explicit reference for a variant uses the previous section's,
/// and an explicit-but-unreadable reference blocks inheritance for that
/// variant. Ordering is deterministic: explicit references in XML order,
/// then inherited entries in the previous section's effective order.
pub(all) struct DocumentSection {
  ends_after_paragraph : Int?
  headers : Array[SectionRef]
  footers : Array[SectionRef]
} derive(Debug, Eq)
