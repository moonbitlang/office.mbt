// PR 2 of the reader unification (#434): the output carrier and the reader IR.
//
// The body reader's recursive component is one strongly connected component
// through `read_children`'s return type. Every producer builds `New`
// reader-IR nodes with provenance, transforms rewrite the IR in place, and
// erasing to `DocumentElement` happens exactly once, in
// `reader_items_to_elements` -- the reader itself never erases.

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
/// same decision sites that produce or suppress semantic nodes, after every
/// transform has run: a text atom the checkbox transform replaced carries
/// `Suppressed` + `ProjectsVisibleNonText`, not its original `ProjectsText`.
/// The old projection's `TransparentSeam` maps to `TransparentBoundary`; its
/// `HardBarrier` conflated the last two kinds, which this stream separates.
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
  /// A node built through the reader IR.
  New(ReaderTree)
  /// An effect with no surviving semantic output.
  Trace(ReaderEffect)
}

///|
/// A reader-built node. `source` is the reader decision site; PR 4 joins a
/// `SourceElementId` into `ReaderNode` itself, so producers -- which already
/// pass their input node here -- are never touched again.
priv struct ReaderTree {
  source : ReaderNode
  /// What this node's decision site contributed to the story, in order,
  /// ahead of the children's own effects.
  local_effects : Array[ReaderEffect]
  shape : ReaderTreeShape
}

///|
/// The reachable output shapes. Two deliberate omissions keep impossible
/// reader states unrepresentable: no `ReaderDocument` (assembly stays the
/// erase boundary) and no `ReaderField` (authoring-only; this reader never
/// produces it).
priv struct ReaderParagraphInput {
  /// The physical `w:p` element itself -- a deleted prefix or the
  /// surviving terminal paragraph.
  paragraph : ReaderNode
  /// Its DIRECT child elements in order: the field-carrier sequence the
  /// projection's field classification observes per physical paragraph.
  carriers : Array[ReaderNode]
}

///|
priv enum ReaderTreeShape {
  /// Deleted paragraph-mark prefixes first, terminal paragraph last, each
  /// with its own ordered carriers.
  ReaderParagraph(
    inputs~ : Array[ReaderParagraphInput],
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
      Trace(_) => ()
      New(tree) =>
        match tree.shape {
          ReaderParagraph(inputs=_, children~, extras~, properties~) => {
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
/// The effect stream in document order: a tree's own effects come before its
/// children's (the decision happens at the node), and a paragraph's extras
/// follow its children, matching the erase order.
fn collect_reader_effects(items : Array[ReaderItem]) -> Array[ReaderEffect] {
  let out : Array[ReaderEffect] = []
  collect_reader_effects_into(items, out)
  out
}

///|
fn collect_reader_effects_into(
  items : Array[ReaderItem],
  out : Array[ReaderEffect],
) -> Unit {
  for item in items {
    match item {
      Trace(effect) => out.push(effect)
      New(tree) => {
        out.append(tree.local_effects)
        match tree.shape {
          ReaderParagraph(inputs=_, children~, extras~, properties=_) => {
            collect_reader_effects_into(children, out)
            collect_reader_effects_into(extras, out)
          }
          ReaderRun(children~, properties=_) =>
            collect_reader_effects_into(children, out)
          ReaderHyperlink(children~, ..) =>
            collect_reader_effects_into(children, out)
          ReaderTable(children~, properties=_) =>
            collect_reader_effects_into(children, out)
          ReaderTableRow(children~, is_header=_) =>
            collect_reader_effects_into(children, out)
          ReaderTableCell(children~, ..) =>
            collect_reader_effects_into(children, out)
          ReaderText(_)
          | ReaderTab
          | ReaderCheckbox(_)
          | ReaderNoteReference(..)
          | ReaderCommentReference(_)
          | ReaderImage(_)
          | ReaderBreak(_)
          | ReaderBookmarkStart(_) => ()
        }
      }
    }
  }
}
