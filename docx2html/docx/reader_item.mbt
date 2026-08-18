// PR 2 of the reader unification (#434): the output carrier and the reader IR.
//
// The body reader's recursive component is one strongly connected component
// through `read_children`'s return type. `ReaderItem` is the bridge across
// the migration: 2.0 put it in the spine with everything `Legacy`, 2a moves
// the structural producers onto `New(ReaderTree)`, 2b the atoms, 2c converts
// the transforms and populates effects, and then `Legacy` is deleted with a
// search guard. The four transforms that rebuild structure -- complex
// fields, the checkbox replacement, vMerge, and the deleted-paragraph join
// -- stay as NAMED legacy islands until 2c; their adapters carry `legacy`
// in their names so the final search means something.

///|
/// Which atom a projected text value came from. The projection's
/// contribution kinds, one level earlier.
priv enum ReaderProjectedTextKind {
  FromText
  FromTab
  FromNoBreakHyphen
  FromSoftHyphen
  FromSymbol
} derive(Debug)

///|
/// What one reader decision contributed to the visible story. Emitted at the
/// same decision sites that produce or suppress semantic nodes, AFTER
/// transforms -- which is why the fields stay empty until 2c, when the
/// transforms themselves become IR-aware. The projection adapter then
/// becomes pure restructuring over this stream.
priv enum ReaderEffect {
  ProjectsText(
    source~ : ReaderNode,
    kind~ : ReaderProjectedTextKind,
    value~ : String
  )
  ProjectsVisibleNonText(source~ : ReaderNode)
  TransparentBoundary(source~ : ReaderNode)
  Suppressed(source~ : ReaderNode)
}

///|
/// One item of reader output while the migration is in flight.
priv enum ReaderItem {
  /// A fully built legacy element. Every producer starts here; the
  /// variant's deletion is the signal that PR 2 is complete.
  Legacy(DocumentElement)
  /// A node built through the reader IR.
  New(ReaderTree)
  /// An effect with no surviving semantic output (2c).
  Trace(ReaderEffect)
}

///|
/// A reader-built node. `source` is the reader decision site; PR 4 joins a
/// `SourceElementId` into `ReaderNode` itself, so producers -- which already
/// pass their input node here -- are never touched again.
priv struct ReaderTree {
  source : ReaderNode
  /// Empty through 2a/2b; populated in 2c.
  local_effects : Array[ReaderEffect]
  shape : ReaderTreeShape
}

///|
/// The reachable output shapes. Two deliberate omissions keep impossible
/// reader states unrepresentable: no `ReaderDocument` (assembly stays the
/// erase boundary) and no `ReaderField` (authoring-only; this reader never
/// produces it).
priv enum ReaderTreeShape {
  /// Deleted paragraph-mark prefixes first, terminal paragraph last.
  ReaderParagraph(
    sources~ : Array[ReaderNode],
    children~ : Array[ReaderItem],
    /// Semantically owned by this physical paragraph, erased as SIBLINGS
    /// after it -- the descendants-become-siblings behaviour the extras
    /// passes implement, kept structural here so no conversion can quietly
    /// flatten it into ordinary children.
    extras~ : Array[ReaderItem],
    properties~ : ParagraphProperties
  )
  ReaderRun(children~ : Array[ReaderItem], properties~ : RunProperties)
  ReaderText(String)
  ReaderTab
  ReaderCheckbox(Bool)
  ReaderHyperlink(
    children~ : Array[ReaderItem],
    href~ : String?,
    anchor~ : String?,
    target_frame~ : String?
  )
  ReaderNoteReference(note_type~ : String, note_id~ : String)
  ReaderCommentReference(String)
  ReaderImage(Image)
  ReaderTable(children~ : Array[ReaderItem], properties~ : TableProperties)
  ReaderTableRow(children~ : Array[ReaderItem], is_header~ : Bool)
  ReaderTableCell(
    children~ : Array[ReaderItem],
    col_span~ : Int,
    row_span~ : Int
  )
  ReaderBreak(@document.BreakType)
  ReaderBookmarkStart(String)
}

///|
/// The erase boundary: collapse carrier items into the public tree shape.
/// An accumulator, because a paragraph's extras expand into the CONTAINING
/// array after the paragraph itself.
fn reader_items_to_elements(
  items : Array[ReaderItem],
) -> Array[DocumentElement] {
  let out : Array[DocumentElement] = []
  erase_reader_items_into(items, out)
  out
}

///|
fn erase_reader_items_into(
  items : Array[ReaderItem],
  out : Array[DocumentElement],
) -> Unit {
  for item in items {
    match item {
      Legacy(element) => out.push(element)
      Trace(_) => ()
      New(tree) =>
        match tree.shape {
          ReaderParagraph(sources=_, children~, extras~, properties~) => {
            out.push(
              Paragraph(
                children=reader_items_to_elements(children),
                properties~,
              ),
            )
            erase_reader_items_into(extras, out)
          }
          ReaderRun(children~, properties~) =>
            out.push(
              Run(children=reader_items_to_elements(children), properties~),
            )
          ReaderText(value) => out.push(Text(value))
          ReaderTab => out.push(Tab)
          ReaderCheckbox(checked) => out.push(Checkbox(checked))
          ReaderHyperlink(children~, href~, anchor~, target_frame~) =>
            out.push(
              Hyperlink(
                children=reader_items_to_elements(children),
                href~,
                anchor~,
                target_frame~,
              ),
            )
          ReaderNoteReference(note_type~, note_id~) =>
            out.push(NoteReference(note_type~, note_id~))
          ReaderCommentReference(id) => out.push(CommentReference(id))
          ReaderImage(image) => out.push(Image(image))
          ReaderTable(children~, properties~) =>
            out.push(
              Table(children=reader_items_to_elements(children), properties~),
            )
          ReaderTableRow(children~, is_header~) =>
            out.push(
              TableRow(children=reader_items_to_elements(children), is_header~),
            )
          ReaderTableCell(children~, col_span~, row_span~) =>
            out.push(
              TableCell(
                children=reader_items_to_elements(children),
                col_span~,
                row_span~,
              ),
            )
          ReaderBreak(kind) => out.push(Break(kind))
          ReaderBookmarkStart(name) => out.push(BookmarkStart(name))
        }
    }
  }
}

///|
/// Wrap legacy output while producers migrate.
fn reader_legacy_items(elements : Array[DocumentElement]) -> Array[ReaderItem] {
  elements.map(element => Legacy(element))
}

///|
/// The named unwrap the four legacy islands read through while they still
/// rebuild DocumentElement trees (complex fields, the checkbox replacement,
/// vMerge, the deleted-paragraph join). Deleting this function is part of
/// 2c's search guard: when no island remains, nothing may erase inside the
/// reader.
fn reader_legacy_island_elements(
  items : Array[ReaderItem],
) -> Array[DocumentElement] {
  reader_items_to_elements(items)
}
