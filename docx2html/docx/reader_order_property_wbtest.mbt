///|
// A generated hostile oracle for the reader-order projection.
//
// The projection exists to say, for a document in the grammar below, exactly
// which source bytes produced which reader-visible text. "For any document" is
// what it is working towards; the exclusions further down are the distance
// still to go. The hand-written tests next to this file
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
// `w:sdt` and `mc:AlternateContent` were both excluded here until their
// transforms landed. Both are now generated, and the pair is worth generating
// together: each suppresses a sibling, but the extras passes treat them
// oppositely, so a projection that handled them alike would be wrong about one.

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
  /// What the generator actually built, recorded as it builds.
  ///
  /// The coverage guard used to search the finished XML for substrings, which
  /// cannot distinguish shapes that differ only in where they sit -- a
  /// content control at block level and one inside a paragraph serialise the
  /// same way, and only the second reaches the paragraph's physical extras
  /// pass. Tagging at the point of construction says which was built.
  tags : Array[String]
}

///|
fn HostileChoices::tag(self : HostileChoices, name : String) -> Unit {
  self.tags.push(name)
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
/// Text that is never empty, for shapes whose meaning depends on there being
/// something to replace.
fn hostile_nonempty_text(choices : HostileChoices) -> String {
  let value = hostile_text(choices)
  if value.length() > 0 {
    value
  } else {
    "x"
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
/// A content control.
///
/// `BodyReader::read_structured_document_tag` reaches the content with
/// `first_or_empty("w:sdtContent")`, so exactly one child contributes and
/// everything else in the control is suppressed -- a second `w:sdtContent`
/// included. The variants below sit either side of that rule.
///
/// The last one is the interaction worth generating: a textbox in the
/// *suppressed* second content. The reader's content pass never reaches it,
/// but `read_paragraph_extra_elements` recurses physically through everything
/// it does not name, so the textbox is still emitted. A projection that skips
/// content controls in its extras pass loses it, and one that reads both
/// contents gains text the reader never produced.
///
/// Checkbox variants are generated at block level only. The reader applies a
/// second transform for those -- replacing the first non-empty text, or
/// discarding the content when there is none.
///
/// Two shapes are known to diverge and are pinned by name in
/// `reader_order_projection_wbtest.mbt`: an *inline* control whose content
/// yields no text, and one wrapping a table cell. Generating either here would
/// re-assert a tracked divergence rather than find a new one. That list is
/// what has been measured, not a proof that nothing else diverges.
fn hostile_sdt(
  choices : HostileChoices,
  depth : Int,
  site : String,
  variant? : Int = -1,
) -> String {
  let first = "<w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r></w:p>"
  choices.tag("sdt@\{site}")
  // `w14:checkbox` replaces the first non-empty text in the content, and
  // discards the content wholesale when there is none. Only offered at block
  // level -- see the note above for why.
  let checkbox = site == "block" && variant < 0 && choices.next(3) == 0
  let properties = if checkbox {
    choices.tag("sdt.checkbox")
    "<w:sdtPr><w14:checkbox><w14:checked w14:val=\"1\"/></w14:checkbox></w:sdtPr>"
  } else {
    "<w:sdtPr><w:alias w:val=\"a\"/></w:sdtPr>"
  }
  let checkbox_properties =
    #|<w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr>
  if variant >= 4 {
    choices.tag("sdt.checkbox")
    match variant {
      // no text at all, so the reader discards the content entirely
      4 => {
        choices.tag("sdt.checkbox.no_text")
        return "<w:sdt>\{checkbox_properties}<w:sdtContent><w:p><w:r><w:tab/></w:r></w:p></w:sdtContent></w:sdt>"
      }
      // nested controls, each contributing a transform: the inner takes the
      // first text, the outer the next one still standing
      5 => {
        choices.tag("sdt.checkbox.nested")
        // Both texts are non-empty by construction. `hostile_text` can return
        // "", and an empty text is skipped rather than replaced -- so with it
        // the tag would not prove two transforms were consumed.
        let one = hostile_nonempty_text(choices)
        let two = hostile_nonempty_text(choices)
        return "<w:sdt>\{checkbox_properties}<w:sdtContent><w:sdt>\{checkbox_properties}<w:sdtContent><w:p><w:r><w:t>\{one}</w:t><w:t>\{two}</w:t></w:r></w:p></w:sdtContent></w:sdt></w:sdtContent></w:sdt>"
      }
      // an atom the reader turns into text even though it is not a `w:t`
      _ => {
        choices.tag("sdt.checkbox.other_text_kind")
        let atom = match choices.next(3) {
          0 => "<w:softHyphen/>"
          1 => "<w:noBreakHyphen/>"
          _ => "<w:sym w:font=\"Wingdings\" w:char=\"F0FC\"/>"
        }
        return "<w:sdt>\{checkbox_properties}<w:sdtContent><w:p><w:r>\{atom}</w:r></w:p></w:sdtContent></w:sdt>"
      }
    }
  }
  if checkbox {
    match choices.next(4) {
      // no text at all, so the reader discards the content entirely
      0 => {
        choices.tag("sdt.checkbox.no_text")
        return "<w:sdt>\{properties}<w:sdtContent><w:p><w:r><w:tab/></w:r></w:p></w:sdtContent></w:sdt>"
      }
      // a control nested inside this one, each contributing a transform: the
      // inner takes the first text, the outer the next one still standing
      1 => {
        choices.tag("sdt.checkbox.nested")
        return "<w:sdt>\{properties}<w:sdtContent><w:sdt>\{properties}<w:sdtContent><w:p><w:r><w:t>\{hostile_text(choices)}</w:t><w:t>\{hostile_text(choices)}</w:t></w:r></w:p></w:sdtContent></w:sdt></w:sdtContent></w:sdt>"
      }
      // an atom the reader turns into text even though it is not a `w:t`
      2 => {
        choices.tag("sdt.checkbox.other_text_kind")
        let atom = match choices.next(3) {
          0 => "<w:softHyphen/>"
          1 => "<w:noBreakHyphen/>"
          _ => "<w:sym w:font=\"Wingdings\" w:char=\"F0FC\"/>"
        }
        return "<w:sdt>\{properties}<w:sdtContent><w:p><w:r>\{atom}</w:r></w:p></w:sdtContent></w:sdt>"
      }
      _ => ()
    }
  }
  // Built inside the branch that uses it, not before the branch is chosen.
  // `hostile_block` records tags of its own, and a variant that discarded this
  // string would have left those tags behind -- so the coverage guard could
  // report an interaction that never reached the document.
  //
  // Inside a paragraph the nested content stays a paragraph rather than an
  // arbitrary block. A table nested inside a paragraph hits a divergence that
  // predates this work and is unrelated to content controls -- the reader
  // finds a textbox in a deleted row through the enclosing paragraph's
  // physical extras pass and this projection does not. It is pinned by name in
  // `reader_order_projection_wbtest.mbt`; generating it here would only
  // re-assert a divergence that is already tracked.
  let nested = fn() -> String {
    if site == "paragraph" {
      "<w:p><w:r>\{hostile_run_content(choices, depth + 1)}</w:r></w:p>"
    } else {
      hostile_block(choices, depth + 1)
    }
  }
  // A caller may pin the variant. The suppressed-textbox shape inside a
  // paragraph is the one the physical extras pass hinges on, and leaving it to
  // the choice stream did not produce it at that site even once in 120
  // samples -- the guard only appeared to cover it because tags leaked from
  // discarded subtrees.
  match (if variant >= 0 { variant } else { choices.next(4) }) {
    // properties before the content, which must not be read as content
    0 => "<w:sdt>\{properties}<w:sdtContent>\{nested()}</w:sdtContent></w:sdt>"
    // no content at all: the control contributes nothing
    1 => "<w:sdt>\{properties}</w:sdt>"
    // a second content, whose text the reader never emits
    2 => {
      choices.tag("sdt.second_content@\{site}")
      "<w:sdt>\{properties}<w:sdtContent>\{first}</w:sdtContent><w:sdtContent><w:p><w:r><w:t>suppressed</w:t></w:r></w:p></w:sdtContent></w:sdt>"
    }
    // a textbox inside that suppressed second content
    _ => {
      choices.tag("sdt.suppressed_textbox@\{site}")
      "<w:sdt>\{properties}<w:sdtContent>\{first}</w:sdtContent><w:sdtContent><w:p><w:r>\{hostile_textbox(choices, depth + 1)}</w:r></w:p></w:sdtContent></w:sdt>"
    }
  }
}

///|
/// A content control wrapping table rows, which is where the *prepass* has to
/// agree with the reader rather than just the walk.
///
/// `collect_reader_order_body_outputs` decides which rows and cells the reader
/// emits, and vertical-merge resolution runs on that decision. A control whose
/// suppressed second content holds a row would, if the prepass flattened both
/// contents, make the table fail open and restore continuation cells the
/// reader removes.
fn hostile_sdt_around_rows(choices : HostileChoices) -> String {
  choices.tag("sdt.around_rows")
  let cell = "<w:tc><w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r></w:p></w:tc>"
  let merged =
    #|<w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>top</w:t></w:r></w:p></w:tc>
  let continued =
    #|<w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>under</w:t></w:r></w:p></w:tc>
  match choices.next(3) {
    0 => {
      choices.tag("sdt.around_rows.suppressed_row")
      "<w:tbl><w:sdt><w:sdtContent><w:tr>\{merged}\{cell}</w:tr><w:tr>\{continued}\{cell}</w:tr></w:sdtContent><w:sdtContent><w:tr>\{cell}\{cell}</w:tr></w:sdtContent></w:sdt></w:tbl>"
    }
    // The shape that decides whether the prepass agrees with the reader: a
    // control inside a row, whose *suppressed* second content holds a stray
    // paragraph. Flattening both contents puts that paragraph among the row's
    // children, the row looks malformed, the table fails open, and the vMerge
    // continuation cell the reader removes is restored instead. The walk would
    // then select the right content out of an already-wrong visibility map.
    1 => {
      choices.tag("sdt.around_rows.stray_paragraph")
      "<w:tbl><w:tr><w:sdt><w:sdtContent>\{merged}</w:sdtContent><w:sdtContent><w:p><w:r><w:t>stray</w:t></w:r></w:p></w:sdtContent></w:sdt></w:tr><w:tr>\{continued}</w:tr></w:tbl>"
    }
    _ =>
      "<w:tbl><w:sdt><w:sdtContent><w:tr>\{merged}\{cell}</w:tr></w:sdtContent></w:sdt><w:tr>\{continued}\{cell}</w:tr></w:tbl>"
  }
}

///|
/// A content control directly under a `w:pict`.
///
/// `read_pict_extra_elements` sends anything it does not name to
/// `read_element`, so a control there contributes in the reader. The picture
/// extras pass is a separate dispatch site from the paragraph one and has to
/// select the first content the same way.
fn hostile_sdt_under_pict(choices : HostileChoices) -> String {
  choices.tag("sdt.under_pict")
  let visible = "<w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r></w:p>"
  "<w:p><w:r><w:pict><v:shape><w:sdt><w:sdtContent>\{visible}</w:sdtContent><w:sdtContent><w:p><w:r><w:t>suppressed</w:t></w:r></w:p></w:sdtContent></w:sdt></v:shape></w:pict></w:r></w:p>"
}

///|
/// Markup Compatibility alternate content.
///
/// The reader always takes the fallback and never looks at a choice, whatever
/// that choice requires: `read_element` reaches it with
/// `first_or_empty("mc:Fallback")`. So a choice branch is suppressed outright.
///
/// The pairing with `hostile_sdt` is the point. Both suppress a sibling, but
/// the extras passes treat them oppositely: a textbox inside a suppressed
/// `w:sdtContent` is still emitted, because the paragraph pass recurses
/// physically through anything it does not name, while a textbox inside an
/// `mc:Choice` is not, because alternate content switches that pass into
/// `read_text_box_elements`, which re-selects the fallback. A projection that
/// treated the two alike would be wrong about one of them.
fn hostile_alternate_content(
  choices : HostileChoices,
  depth : Int,
  site? : String = "block",
  variant? : Int = -1,
) -> String {
  let requires = " Requires=\"wps\""
  let choice = "<mc:Choice\{requires}><w:p><w:r><w:t>choice</w:t></w:r></w:p></mc:Choice>"
  choices.tag("alternate")
  choices.tag("alternate@\{site}")
  // Inside a paragraph the fallback stays a paragraph, for the same reason
  // `hostile_sdt` constrains its nested content -- see the note there.
  //
  // Built inside the branch that uses it, for the same reason `hostile_sdt`
  // does: `hostile_block` records tags, and three of these four variants
  // discard this string, so building it eagerly would leave tags behind for
  // content that never reached the document.
  let nested = fn() -> String {
    if site == "paragraph" {
      "<w:p><w:r>\{hostile_run_content(choices, depth + 1)}</w:r></w:p>"
    } else {
      hostile_block(choices, depth + 1)
    }
  }
  // A caller may pin the variant, for the same reason `hostile_sdt` allows it.
  match (if variant >= 0 { variant } else { choices.next(4) }) {
    // a choice whose text must never appear, before the fallback
    0 =>
      "<mc:AlternateContent>\{choice}<mc:Fallback>\{nested()}</mc:Fallback></mc:AlternateContent>"
    // no fallback: contributes nothing at all
    1 => {
      choices.tag("alternate.no_fallback")
      choices.tag("alternate.no_fallback@\{site}")
      "<mc:AlternateContent>\{choice}</mc:AlternateContent>"
    }
    // a textbox in the choice, which even the physical extras pass must miss
    2 => {
      choices.tag("alternate.textbox_in_choice")
      choices.tag("alternate.textbox_in_choice@\{site}")
      "<mc:AlternateContent><mc:Choice\{requires}><w:p><w:r>\{hostile_textbox(choices, depth + 1)}</w:r></w:p></mc:Choice><mc:Fallback><w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r></w:p></mc:Fallback></mc:AlternateContent>"
    }
    // and a textbox in the fallback, which it must find
    _ => {
      choices.tag("alternate.textbox_in_fallback")
      choices.tag("alternate.textbox_in_fallback@\{site}")
      "<mc:AlternateContent>\{choice}<mc:Fallback><w:p><w:r>\{hostile_textbox(choices, depth + 1)}</w:r></w:p></mc:Fallback></mc:AlternateContent>"
    }
  }
}

///|
/// Alternate content wrapping table rows, the counterpart of
/// `hostile_sdt_around_rows`.
///
/// `is_transparent_container` names `mc:Fallback`, so a second one is flattened
/// into the vMerge prepass while the reader reads only the first. A stray
/// paragraph there makes the row look malformed, the table fail open, and a
/// continuation cell the reader removes get restored.
fn hostile_alternate_around_rows(choices : HostileChoices) -> String {
  choices.tag("alternate.around_rows")
  let merged =
    #|<w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>top</w:t></w:r></w:p></w:tc>
  let continued =
    #|<w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>under</w:t></w:r></w:p></w:tc>
  if choices.next(2) == 0 {
    choices.tag("alternate.around_rows.second_fallback")
    "<w:tbl><w:tr><mc:AlternateContent><mc:Fallback>\{merged}</mc:Fallback><mc:Fallback><w:p><w:r><w:t>stray</w:t></w:r></w:p></mc:Fallback></mc:AlternateContent></w:tr><w:tr>\{continued}</w:tr></w:tbl>"
  } else {
    "<w:tbl><w:tr><mc:AlternateContent><mc:Choice Requires=\"wps\"><w:p><w:r><w:t>stray</w:t></w:r></w:p></mc:Choice><mc:Fallback>\{merged}</mc:Fallback></mc:AlternateContent></w:tr><w:tr>\{continued}</w:tr></w:tbl>"
  }
}

///|
/// One block-level construct: a paragraph, a table, or a revision wrapper
/// around either.
fn hostile_block(choices : HostileChoices, depth : Int) -> String {
  if depth >= 4 {
    return "<w:p><w:r><w:t>leaf</w:t></w:r></w:p>"
  }
  match choices.next(20) {
    // The three checkbox shapes are pinned to their own branches rather than
    // left to the choice stream. Each time one was left to chance the stream
    // shifted and some other shape fell to zero -- the stream is deterministic
    // per position, so a sub-branch of a sub-branch is not sampled, it is
    // decided.
    15 => hostile_sdt(choices, depth, "block", variant=4)
    // an atomless run beside a normal one. It contributes only the seam the
    // walk opens for it, and N0c synthesises a `w:t` into exactly this shape,
    // so it has to keep an address.
    19 => {
      choices.tag("run.atomless")
      "<w:p><w:r/><w:r><w:t>\{hostile_text(choices)}</w:t></w:r><w:r/></w:p>"
    }
    18 =>
      // a textbox inside an mc:Choice, inside a paragraph -- the site whose
      // extras pass switches modes, and the one the choice stream never
      // reached on its own
      "<w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r>\{hostile_alternate_content(choices, depth, site="paragraph", variant=2)}</w:p>"
    16 => hostile_sdt(choices, depth, "block", variant=5)
    17 => hostile_sdt(choices, depth, "block", variant=6)
    13 =>
      // the paragraph-site suppressed-textbox interaction, pinned rather than
      // left to chance: leaving it to the choice stream produced it at that
      // site zero times in 120 samples
      "<w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r>\{hostile_sdt(choices, depth, "paragraph", variant=3)}</w:p>"
    14 => hostile_alternate_around_rows(choices)
    9 => hostile_sdt_around_rows(choices)
    10 => hostile_sdt_under_pict(choices)
    11 => hostile_alternate_content(choices, depth)
    12 =>
      // alternate content inside a paragraph, which is where the extras pass
      // switches modes on it
      "<w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r>\{hostile_alternate_content(choices, depth, site="paragraph")}</w:p>"
    7 => hostile_sdt(choices, depth, "block")
    8 =>
      // a content control inside a paragraph, so the physical extras pass
      // walks through it as well as the content pass
      "<w:p><w:r><w:t>\{hostile_text(choices)}</w:t></w:r>\{hostile_sdt(choices, depth, "paragraph")}</w:p>"
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
  let (document, _) = hostile_document_tagged(seeds)
  document
}

///|
/// The same document, plus what the generator recorded while building it.
fn hostile_document_tagged(seeds : ArrayView[Int]) -> (String, Array[String]) {
  let choices = HostileChoices::{ seeds, at: 0, tags: [] }
  let body = StringBuilder()
  let blocks = choices.next(4) + 1
  for _ in 0..<blocks {
    body.write_string(hostile_block(choices, 0))
  }
  // `mc` has to be bound or the alternate-content branches resolve to an
  // unbound prefix rather than `MC_URI`, and the projection would take its
  // "not markup compatibility" path while the test looked like it passed.
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body>" +
    body.to_string() +
    "</w:body></w:document>"
  (document, choices.tags)
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
  // Raised from 40 when content controls were added: two more block choices
  // diluted every other branch, and at 40 samples deletions fell to one and
  // vMerge pairs to none. The thresholds below are unchanged, so this is the
  // sample count that keeps them honest rather than thresholds lowered to fit.
  let cases : Array[Array[Int]] = @quickcheck.samples(120)
  let mut tables = 0
  let mut deletions = 0
  let mut textboxes = 0
  let mut insertions = 0
  let mut textbox_in_deletion = 0
  let mut vmerge_pairs = 0
  // Content-control coverage comes from what the generator recorded rather
  // than from the finished XML. A control at block level and one inside a
  // paragraph serialise identically, and only the second reaches the
  // paragraph's physical extras pass, so a substring search cannot tell the
  // two apart -- it would report the interaction as covered when only the
  // block form had been built.
  let tag_counts : Map[String, Int] = Map([])
  for case in cases {
    let (_, tags) = hostile_document_tagged(case)
    for tag in tags {
      tag_counts[tag] = tag_counts.get(tag).unwrap_or(0) + 1
    }
  }
  let tagged = fn(name : String) -> Int { tag_counts.get(name).unwrap_or(0) }
  for case in cases {
    let document = hostile_document(case)
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
  // Each content-control site is asserted separately: the block form, the
  // form inside a paragraph (the only one the physical extras pass walks),
  // the form around table rows (which the vMerge prepass must agree about),
  // and the form under a picture (a fourth dispatch site). Before these were
  // separated, the block form alone satisfied the guard.
  println(
    "TAGS " + tag_counts.iter().map(p => "\{p.0}=\{p.1}").collect().join(" "),
  )
  assert_true(tagged("sdt@block") >= 5)
  assert_true(tagged("sdt@paragraph") >= 5)
  assert_true(tagged("sdt.suppressed_textbox@paragraph") >= 1)
  assert_true(tagged("sdt.second_content@paragraph") >= 1)
  assert_true(tagged("sdt.around_rows") >= 3)
  assert_true(tagged("sdt.around_rows.suppressed_row") >= 1)
  assert_true(tagged("sdt.around_rows.stray_paragraph") >= 1)
  assert_true(tagged("sdt.under_pict") >= 3)
  assert_true(tagged("sdt.checkbox") >= 3)
  assert_true(tagged("sdt.checkbox.no_text") >= 1)
  assert_true(tagged("run.atomless") >= 2)
  assert_true(tagged("sdt.checkbox.nested") >= 1)
  assert_true(tagged("sdt.checkbox.other_text_kind") >= 1)
  assert_true(tagged("alternate") >= 10)
  assert_true(tagged("alternate.textbox_in_choice") >= 2)
  // Site and variant together, not each on its own: counting them separately
  // would still pass if every textbox-in-choice had moved to a block site,
  // and the paragraph site is the one whose extras pass switches modes.
  assert_true(tagged("alternate.textbox_in_choice@paragraph") >= 1)
  assert_true(tagged("alternate.textbox_in_fallback") >= 2)
  assert_true(tagged("alternate.no_fallback") >= 2)
  assert_true(tagged("alternate.around_rows") >= 3)
  assert_true(tagged("alternate.around_rows.second_fallback") >= 1)
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
      let source = hostile_document(seeds)
      let projection = scan_reader_order_projection(
        "word/document.xml",
        @utf8.encode(source),
      )
      assert_reader_order_matches_reader(source, projection)
      true
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
      let source = hostile_document(seeds)
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
      let source = hostile_document(seeds)
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

///|
/// The interval claim, over generated documents.
///
/// The hand-written cases next door cover the shapes somebody thought of. This
/// drives the same check over the ones nobody did, and it is the claim that
/// matters most for surgery: an edit addressed by a projection interval lands
/// on the bytes that produced that text, or it lands somewhere else.
test "generated documents keep every interval indexing the reader" {
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let source = hostile_document(seeds)
      assert_reader_order_intervals_index_the_reader(source)
      true
    },
    count=64,
    max_size=60,
    seed=0x696E_7465_7276UL,
  )
}
