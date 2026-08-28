// Implementation-independent reader oracles shared by the projection,
// effects, and surgery suites: the reader's own story text and its
// paragraph partition, both taken from the reader's tree and checked
// against its own renderer.

///|
fn current_reader_story_text(source : String) -> String raise DocxError {
  let root = read_xml_string(source, namespace_map=office_namespace_map())
  let node = ReaderNode::of(root)
  let children = match node.first("w:body") {
    Some(body) => body.element_children()
    None => node.element_children()
  }
  document(
    reader_items_to_elements(
      empty_body_reader({ relationships: [], }).read_children(children),
    ),
  ).to_raw_text()
}

///|
/// The reader's own paragraph partition, taken from its tree and checked
/// against its own renderer.
///
/// Comparing story text compares only the concatenation, and the concatenation
/// is ambiguous: one paragraph reading `a\n\nb` and two reading `a` and `b`
/// serialise identically while offering different addressable paths. Surgery
/// addresses paragraphs, so the partition -- not the join of it -- is what has
/// to agree.
///
/// A `Paragraph` emits its own separator, so a paragraph nested inside another
/// splits the enclosing one: the outer prefix closes with the inner
/// paragraph's content, and the outer suffix becomes a further paragraph. That
/// is why this accumulates into one buffer instead of recursing per node -- it
/// is the flattening the reader already performs, not one invented here.
///
/// What this is NOT. It is an ordered paragraph-text oracle, and paragraph text
/// erases everything inside a paragraph: run boundaries (two reader runs `x`
/// and `y` projected as one run `xy` survive this), atom kind (`Tab` against a
/// `Text` holding a tab, which surgery treats differently), zero-width
/// structure, and paragraph *ownership* -- two paragraphs both reading `x`
/// could have their identities swapped and every check here would still pass
/// while `p[0]` named the other one. Those are the gate's business, not this
/// oracle's.
fn reader_paragraph_texts(source : String) -> Array[String] raise {
  let root = read_xml_string(source, namespace_map=office_namespace_map())
  let node = ReaderNode::of(root)
  let children = match node.first("w:body") {
    Some(body) => body.element_children()
    None => node.element_children()
  }
  let tree = document(
    reader_items_to_elements(
      empty_body_reader({ relationships: [], }).read_children(children),
    ),
  )
  let paragraphs = []
  let buffer = StringBuilder()
  flatten_reader_paragraphs(tree, paragraphs, buffer)
  // No text after the last paragraph boundary: that would be story the
  // partition does not account for, and an address could not name it.
  //
  // This says nothing about text *before* a paragraph. A body-level `w:r` --
  // not schema-valid, but tolerated, and modelled by the projection as a
  // flow-level run -- accumulates into the buffer the next paragraph closes,
  // so the reader's own partition really is one paragraph reading both. That
  // is the reader's behaviour, not a hole here, and
  // "flow-level text before a paragraph joins it" pins it.
  assert_eq(buffer.to_string(), "")
  // A checksum on character emission, not on the boundaries. It catches an arm
  // that emits the wrong characters for a variant, but it cannot hold the
  // boundary-producing arms to `to_raw_text`: splitting a `Text("a\n\nb")` in
  // two reconstructs identically, which is the same non-injectivity that makes
  // the story-text comparison insufficient in the first place. The arms match
  // `to_raw_text` by inspection; this only keeps them from drifting silently in
  // the part it can see.
  let rebuilt = StringBuilder()
  for text in paragraphs {
    rebuilt.write_string(text)
    rebuilt.write_string("\n\n")
  }
  assert_eq(rebuilt.to_string(), tree.to_raw_text())
  paragraphs
}

///|
fn flatten_reader_paragraphs(
  node : DocumentElement,
  paragraphs : Array[String],
  buffer : StringBuilder,
) -> Unit {
  match node {
    Text(value) => buffer.write_string(value)
    Tab => buffer.write_string("\t")
    Field(result~, ..) => buffer.write_string(result)
    Paragraph(children~, ..) => {
      for child in children {
        flatten_reader_paragraphs(child, paragraphs, buffer)
      }
      paragraphs.push(buffer.to_string())
      buffer.reset()
    }
    Document(children~, ..)
    | Run(children~, ..)
    | Hyperlink(children~, ..)
    | Table(children~, ..)
    | TableRow(children~, ..)
    | TableCell(children~, ..) =>
      for child in children {
        flatten_reader_paragraphs(child, paragraphs, buffer)
      }
    _ => ()
  }
}
