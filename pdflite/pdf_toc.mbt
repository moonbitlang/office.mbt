///|
fn pdf_toc_ascii(text : String) -> @core.PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_toc_type_font_id(font_index : Int) -> String {
  font_index.to_string()
}

///|
/// Font source options for table-of-contents generation.
///
/// This ports the non-embedding cpdftoc font-source dispatch. TrueType
/// `EmbedInfo` remains a separate embedding slice.
pub(all) enum PdfTocFontSource {
  PdfTocPreMadeFontPack(PdfFontPack)
  PdfTocExistingNamedFont
} derive(Debug, Eq, ToJson)

///|
/// Add a table of contents using an already prepared font pack.
///
/// This composes the non-structure-tree cpdftoc path: read existing bookmarks
/// and labels, typeset TOC pages, prepend them, shift page labels, and
/// optionally add the generated TOC bookmark. Documents without bookmarks are
/// returned unchanged.
pub fn PdfDocument::toc_with_fontpack(
  self : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  bookmark? : Bool = false,
  dotleader? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  let source_bookmarks = self.read_bookmarks(preserve_actions=true)
  if source_bookmarks.length() == 0 {
    self
  } else {
    let labels = self.read_page_labels()
    let row_bookmarks = self.read_bookmarks(preserve_actions=false)
    let result = self.toc_typeset_pages(
      fontpack, font_size, title, dotleader, false, labels, row_bookmarks,
    )
    let inserted = self.toc_insert_pages(result.pages, labels)
    if bookmark {
      inserted.toc_add_bookmark(title)
    } else {
      inserted
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::toc_with_fontpack`.
pub fn pdf_toc_with_fontpack(
  document : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  bookmark? : Bool = false,
  dotleader? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  document.toc_with_fontpack(fontpack, font_size, title, bookmark~, dotleader~)
}

///|
fn pdf_toc_fontpack_of_source(
  source : PdfTocFontSource,
) -> PdfFontPack raise @core.PdfError {
  match source {
    PdfTocPreMadeFontPack(pack) => pack
    PdfTocExistingNamedFont =>
      raise SoftError("Cannot use existing font with -table-of-contents")
  }
}

///|
/// Add a table of contents using a cpdftoc font source.
///
/// Existing named fonts are rejected for TOCs, matching cpdf. Embeddable
/// TrueType font sources will be handled by a later embedding slice.
pub fn PdfDocument::toc_with_source(
  self : PdfDocument,
  source : PdfTocFontSource,
  font_size : Double,
  title : BytesView,
  bookmark? : Bool = false,
  dotleader? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  self.toc_with_fontpack(
    pdf_toc_fontpack_of_source(source),
    font_size,
    title,
    bookmark~,
    dotleader~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::toc_with_source`.
pub fn pdf_toc_with_source(
  document : PdfDocument,
  source : PdfTocFontSource,
  font_size : Double,
  title : BytesView,
  bookmark? : Bool = false,
  dotleader? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  document.toc_with_source(source, font_size, title, bookmark~, dotleader~)
}

///|
/// Source-spelled high-level cpdftoc wrapper for non-structured TOC output.
///
/// The structured/PDF-UA table-of-contents path still needs full source-tree
/// preservation, so this wrapper rejects that mode instead of dropping existing
/// structure entries.
pub fn PdfDocument::typeset_table_of_contents(
  self : PdfDocument,
  source : PdfTocFontSource,
  font_size : Double,
  title : BytesView,
  bookmark : Bool,
  dotleader : Bool,
  process_struct_tree : Bool,
  subformat? : PdfUASubformat? = None,
) -> PdfDocument raise @core.PdfError {
  if process_struct_tree || subformat != None {
    raise SoftError(
      "typeset_table_of_contents: structured TOC output is not implemented",
    )
  }
  self.toc_with_source(source, font_size, title, bookmark~, dotleader~)
}

///|
/// Compatibility wrapper matching cpdftoc's `typeset_table_of_contents` name.
pub fn pdf_typeset_table_of_contents(
  source : PdfTocFontSource,
  font_size : Double,
  title : BytesView,
  bookmark : Bool,
  dotleader : Bool,
  process_struct_tree : Bool,
  document : PdfDocument,
  subformat? : PdfUASubformat? = None,
) -> PdfDocument raise @core.PdfError {
  document.typeset_table_of_contents(
    source,
    font_size,
    title,
    bookmark,
    dotleader,
    process_struct_tree,
    subformat~,
  )
}
