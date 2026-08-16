///|
// A generated hostile oracle for the reader-order projection.
//
// The projection exists to say, for any document, exactly which source bytes
// produced which reader-visible text. The hand-written tests next to this file
// each pin one construct the reader treats specially -- vMerge continuation,
// deleted rows, textboxes inside deletions, flattened inline wrappers. Each is
// a case somebody thought of.
//
// This drives the same two oracles over documents nobody thought of:
//
//   * the projection's story text must equal what BodyReader produces, which
//     is the entire claim the index makes. Not "looks plausible" -- equal to
//     the engine it is a model of.
//   * every contribution must point inside the source span of the element it
//     claims to come from, and name a paragraph and run the projection itself
//     declared.
//
// Nesting is where this earns its keep. The reader's treatment of a run
// depends on what encloses it -- a `w:del` suppresses inline text but is still
// walked for textboxes, a table cell fails open when malformed, a `w:pict`
// flattens some children and not others -- and the interesting failures come
// from combinations of those, at depths a hand-written fixture does not reach.
//
// Two constructs are deliberately absent: `w:sdt` and `mc:AlternateContent`.
// The projection does not yet perform those transforms (N0b4, #234), so
// generating them would assert a divergence that is known and tracked rather
// than finding one. Adding them means adding branches to `hostile_block` and
// `hostile_run_content` and extending the coverage guard -- so what these
// properties establish is the *supported* grammar, not every document.

///|
/// A deterministic stream of choices, so a generated document is a pure
/// function of its seed and any counterexample reproduces exactly.
///
/// Shrinking is worth being precise about, because the obvious claim is
/// wrong. Mixing each value with its position -- which is what stops the
/// generator collapsing to one trivial paragraph -- means removing an element
/// shifts every later value into a new position and changes unrelated
/// choices. So a shrunk seed array reproduces a *smaller input*, not a
/// structurally simpler document: `[0, 0, 1, 1]` shrunk to `[1, 1]` produces
/// longer XML containing a table. What shrinking buys here is a smaller,
/// exactly reproducible seed to re-run, not a minimal document to read.
/// Getting the latter needs a document AST with its own Shrink instance,
/// which is a larger change than this file.
priv struct HostileChoices {
  seeds : ArrayView[Int]
  mut at : Int
}

///|
fn HostileChoices::next(self : HostileChoices, bound : Int) -> Int {
  // Running out of choices returns 0, and every 0 branch below is the simple
  // or terminating one, so a seed array always yields a finite document.
  if self.at >= self.seeds.length() || bound <= 1 {
    return 0
  }
  let raw = self.seeds[self.at]
  // Mixed with the position, not used raw. QuickCheck's Int values cluster
  // near zero at small sizes, so using them directly as choice indices made
  // every generated document the same trivial paragraph -- 40 samples
  // produced no table, no revision, no textbox and no nesting, and the
  // properties passed without testing anything. Position keeps the choices
  // varied even when every seed is 0; the seed still decides, so the document
  // stays a pure function of the input.
  let mixed = ((raw ^ (self.at * 0x9E3779B9)) * 1103515245 + 12345) & 0x7FFFFFFF
  self.at = self.at + 1
  (mixed >> 11) % bound
}

///|
/// Text with the characters that have to survive escaping, plus a couple that
/// exercise the reader's whitespace handling.
fn hostile_text(choices : HostileChoices) -> String {
  match choices.next(8) {
    0 => "A"
    1 => "hello world"
    2 => "&amp; &lt; &gt;"
    3 => "  leading and trailing  "
    4 => "line1"
    5 => "tab\there"
    6 => ""
    _ => "Z"
  }
}

///|
/// One run's worth of inline children.
fn hostile_run_content(choices : HostileChoices, depth : Int) -> String {
  let out = StringBuilder()
  let count = choices.next(3) + 1
  for _ in 0..<count {
    match choices.next(9) {
      0 => out.write_string("<w:t>\{hostile_text(choices)}</w:t>")
      1 =>
        out.write_string(
          "<w:t xml:space=\"preserve\">\{hostile_text(choices)}</w:t>",
        )
      2 => out.write_string("<w:tab/>")
      3 => out.write_string("<w:br/>")
      4 => out.write_string("<w:noBreakHyphen/>")
      5 => out.write_string("<w:softHyphen/>")
      6 => out.write_string("<w:sym w:font=\"Wingdings\" w:char=\"F0FC\"/>")
      7 =>
        // a nested run: the reader flattens these, and the projection has to
        // agree about which paragraph the inner text belongs to
        if depth < 3 {
          out.write_string(
            "<w:r>\{hostile_run_content(choices, depth + 1)}</w:r>",
          )
        } else {
          out.write_string("<w:t>d</w:t>")
        }
      _ =>
        if depth < 3 {
          out.write_string(hostile_textbox(choices, depth))
        } else {
          out.write_string("<w:t>p</w:t>")
        }
    }
  }
  out.to_string()
}

///|
/// A textbox carrying a nested block. Factored out because it has to be
/// reachable from inside a deletion as well as from ordinary run content --
/// the reader suppresses deleted inline text while still walking the deletion
/// for textboxes, and that interaction is one of the more surprising things
/// the projection has to mirror.
fn hostile_textbox(choices : HostileChoices, depth : Int) -> String {
  "<w:pict><v:shape><v:textbox><w:txbxContent>" +
  hostile_block(choices, depth + 1) +
  "</w:txbxContent></v:textbox></v:shape></w:pict>"
}

///|
/// One block-level construct: a paragraph, a table, or a revision wrapper
/// around either.
fn hostile_block(choices : HostileChoices, depth : Int) -> String {
  if depth >= 4 {
    return "<w:p><w:r><w:t>leaf</w:t></w:r></w:p>"
  }
  match choices.next(7) {
    0 => "<w:p><w:r>\{hostile_run_content(choices, depth)}</w:r></w:p>"
    1 =>
      // hyperlink wraps runs and is flattened by the reader
      "<w:p><w:hyperlink><w:r>\{hostile_run_content(choices, depth)}</w:r></w:hyperlink></w:p>"
    2 =>
      // an insertion contributes its text; a deletion suppresses inline text
      // but is still walked for textboxes
      "<w:p><w:ins><w:r>\{hostile_run_content(choices, depth)}</w:r></w:ins></w:p>"
    3 =>
      // a deletion whose run also carries a textbox: the inline text is
      // suppressed, the textbox is not
      "<w:p><w:del><w:r><w:delText>\{hostile_text(choices)}</w:delText>\{hostile_textbox(choices, depth)}</w:r></w:del><w:r>\{hostile_run_content(choices, depth)}</w:r></w:p>"
    4 => hostile_table(choices, depth)
    5 =>
      "<w:p><w:r>\{hostile_run_content(choices, depth)}</w:r></w:p><w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r></w:p>"
    _ =>
      // smartTag is another transparent wrapper
      "<w:p><w:smartTag><w:r>\{hostile_run_content(choices, depth)}</w:r></w:smartTag></w:p>"
  }
}

///|
/// A table, sometimes with a vertical merge or a deleted row, because both
/// change which cells the reader emits.
fn hostile_table(choices : HostileChoices, depth : Int) -> String {
  let out = StringBuilder()
  out.write_string("<w:tbl>")
  let rows = choices.next(2) + 1
  for _ in 0..<rows {
    let deleted = choices.next(4) == 0
    out.write_string("<w:tr>")
    if deleted {
      out.write_string("<w:trPr><w:del/></w:trPr>")
    }
    let cells = choices.next(2) + 1
    for _ in 0..<cells {
      out.write_string("<w:tc>")
      match choices.next(3) {
        0 => out.write_string("<w:tcPr><w:vMerge w:val=\"restart\"/></w:tcPr>")
        1 => out.write_string("<w:tcPr><w:vMerge/></w:tcPr>")
        _ => ()
      }
      out.write_string(hostile_block(choices, depth + 1))
      out.write_string("</w:tc>")
    }
    out.write_string("</w:tr>")
  }
  out.write_string("</w:tbl>")
  out.to_string()
}

///|
/// A whole document, from a seed.
fn hostile_document(seeds : ArrayView[Int]) -> String {
  let choices = HostileChoices::{ seeds, at: 0 }
  let body = StringBuilder()
  let blocks = choices.next(4) + 1
  for _ in 0..<blocks {
    body.write_string(hostile_block(choices, 0))
  }
  "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>" +
  body.to_string() +
  "</w:body></w:document>"
}

///|
/// The generator has to keep producing documents worth testing.
///
/// This is not decoration. The first version of this file used QuickCheck's
/// Int values directly as choice indices; those cluster near zero at small
/// sizes, so every generated document came out as one plain paragraph. All
/// three properties below passed, over a corpus containing no table, no
/// revision, no textbox and no nesting -- green, and testing nothing.
///
/// The interactions are asserted, not just the constructs. Finding a `w:del`
/// and a textbox somewhere in the same document says nothing about the case
/// that actually surprises the reader, which is a textbox *inside* a
/// deletion: the inline text is suppressed and the textbox is not. Likewise a
/// vMerge restart is only interesting paired with a continuation, since that
/// pair is what makes the reader drop a cell.
test "the generator keeps producing documents worth testing" {
  let cases : Array[Array[Int]] = @quickcheck.samples(40)
  let mut tables = 0
  let mut deletions = 0
  let mut textboxes = 0
  let mut insertions = 0
  let mut textbox_in_deletion = 0
  let mut vmerge_pairs = 0
  for case in cases {
    let document = hostile_document(case[:])
    if document.contains("<w:tbl>") {
      tables = tables + 1
    }
    if document.contains("<w:del>") {
      deletions = deletions + 1
    }
    if document.contains("txbxContent") {
      textboxes = textboxes + 1
    }
    if document.contains("<w:ins>") {
      insertions = insertions + 1
    }
    // the deletion branch is the only place a textbox follows delText, so
    // this substring identifies the nested case rather than co-occurrence
    if document.contains("</w:delText><w:pict>") {
      textbox_in_deletion = textbox_in_deletion + 1
    }
    if document.contains("<w:vMerge w:val=\"restart\"/>") &&
      document.contains("<w:vMerge/>") {
      vmerge_pairs = vmerge_pairs + 1
    }
  }
  assert_true(tables >= 2)
  assert_true(deletions >= 2)
  assert_true(textboxes >= 2)
  assert_true(insertions >= 2)
  assert_true(textbox_in_deletion >= 1)
  assert_true(vmerge_pairs >= 1)
}

///|
/// The claim the projection makes, over documents nobody wrote by hand.
///
/// A failure reports the seed array that produced it, which re-runs exactly.
/// It is not a minimal document -- see `HostileChoices::next` for why
/// shrinking cannot simplify one here -- so reading a counterexample means
/// printing the generated XML from that seed.
test "the projection matches the reader on generated documents" {
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let source = hostile_document(seeds[:])
      let projection = scan_reader_order_projection(
        "word/document.xml",
        @utf8.encode(source),
      )
      provisional_story_text(projection) == current_reader_story_text(source)
    },
    count=64,
    max_size=60,
    seed=0x646F_6378_70UL,
  )
}

///|
/// Every contribution has to sit inside the element it names, and name a
/// paragraph and run the projection declared. Surgery will address bytes
/// through these, so an interval that points outside its element is not a
/// cosmetic defect -- it is an edit landing in the wrong place.
test "generated documents keep every contribution inside its source element" {
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let source = hostile_document(seeds[:])
      let projection = scan_reader_order_projection(
        "word/document.xml",
        @utf8.encode(source),
      )
      assert_reader_order_identity_mapping(projection)
      true
    },
    count=64,
    max_size=60,
    seed=0x646F_6378_71UL,
  )
}

///|
/// Source spans have to be real slices of the input, not merely in range.
///
/// The identity check above proves a contribution's interval lies within its
/// element's interval. This proves the element's own interval is where the
/// element actually is, by cutting the bytes out and looking at both ends.
///
/// Both ends, deliberately. An earlier version matched only the four bytes
/// `<w:p` at the start, which `<w:pict>` and `<w:pPr>` also satisfy, and never
/// looked at `byte_end` at all -- so the off-by-one this test exists to catch
/// would have passed it. The start must be a `w:p` element and not merely a
/// tag whose name begins that way, and the span must end where that element
/// closes.
test "generated documents keep element spans addressable in the source" {
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let source = hostile_document(seeds[:])
      let bytes = @utf8.encode(source)
      let projection = scan_reader_order_projection("word/document.xml", bytes)
      for paragraph in projection.paragraphs {
        for element in paragraph.sources {
          let span = element.source_span
          guard span.byte_start >= 0 &&
            span.byte_end <= bytes.length() &&
            span.byte_start < span.byte_end else {
            return false
          }
          // the QName has to end here, or `<w:pict>` and `<w:pPr>` qualify too
          guard bytes[span.byte_start:span.byte_start + 4] == b"<w:p" else {
            return false
          }
          let after = bytes[span.byte_start + 4]
          guard after == b'>' || after == b' ' || after == b'/' else {
            return false
          }
          // and the span has to reach that element's own close, which is what
          // makes byte_end load-bearing rather than merely well-ordered
          guard span.byte_end >= span.byte_start + 6 else { return false }
          guard bytes[span.byte_end - 6:span.byte_end] == b"</w:p>" else {
            return false
          }
        }
      }
      true
    },
    count=48,
    max_size=60,
    seed=0x646F_6378_72UL,
  )
}
