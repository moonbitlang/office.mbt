// N0c1 -- whole-run surgery.
//
// Turns "replace the text of `p[i]/r[j]`" into byte edits against the source
// part. The projection says which bytes produced which reader-visible text;
// this says which bytes to change so the reader produces something else.
//
// A request this slice cannot carry out safely is refused by raising, with a
// message naming the reason: an unaddressable run, text drawn from CDATA, an
// element the projection could not classify, or replacement text XML cannot
// represent. Each is a case where the edit's byte footprint is not knowable
// from the projection alone, and approximating it would corrupt a document.
//
// Everything here works on physical byte ranges taken from the projection's
// source elements. Nothing reconstructs XML: the first `w:t`'s *content* range
// is rewritten in place, which leaves its tag, namespace prefix and any
// existing `xml:space` untouched.

///|
/// One byte-range replacement in the source part.
#warnings("-unused_field")
priv struct RunSurgeryEdit {
  byte_start : Int
  byte_end : Int
  replacement : String
}

///|
/// The XML characters that cannot appear literally in element content.
///
/// `>` does not strictly require escaping outside `]]>`, but escaping it
/// unconditionally is what every writer here already does and keeps the output
/// stable under later re-reads.
fn run_surgery_escape(text : String) -> String raise DocxError {
  let out = StringBuilder::new()
  for char in text {
    let code = char.to_int()
    // XML 1.0 forbids most C0 controls outright. Tab, newline and carriage
    // return are the exceptions, and they survive as themselves.
    if code < 0x20 && code != 0x09 && code != 0x0A && code != 0x0D {
      raise Unsupported(
        message="replacement text contains a control character U+\{code} that XML cannot represent",
      )
    }
    // Surrogate code points are not characters. A lone one cannot be encoded
    // as UTF-8 and would produce a part no parser accepts.
    if code >= 0xD800 && code <= 0xDFFF {
      raise Unsupported(
        message="replacement text contains an unpaired surrogate U+\{code}",
      )
    }
    // XML 1.0 excludes `U+FFFE` and `U+FFFF` from Char. The supplementary
    // planes' equivalents are discouraged but permitted, and refusing them
    // would reject text a conforming parser accepts.
    if code == 0xFFFE || code == 0xFFFF {
      raise Unsupported(
        message="replacement text contains the non-character U+\{code}",
      )
    }
    match char {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      // A literal carriage return does not survive: XML end-of-line handling
      // turns CR and CRLF into LF when the part is read back. Writing it as a
      // character reference is what keeps the text the caller asked for.
      '\r' => out.write_string("&#xD;")
      _ => out.write_char(char)
    }
  }
  out.to_string()
}

///|
/// Whether replacing a `w:t`'s content with this text needs
/// `xml:space="preserve"` to survive a round trip.
///
/// Word strips leading and trailing whitespace from a `w:t` without it, so
/// text that starts or ends with a space would come back different.
fn run_surgery_needs_space_preserve(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  fn is_space(unit : Int) -> Bool {
    unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D
  }

  let first = text.view(start_offset=0, end_offset=1).to_owned()
  let last = text.view(start_offset=text.length() - 1).to_owned()
  fn leading(one : String) -> Int {
    let mut code = 0
    for char in one {
      code = char.to_int()
    }
    code
  }

  is_space(leading(first)) || is_space(leading(last))
}

///|
/// True when this element is written in the self-closing form.
///
/// The scanner puts an empty content range at the element's end for `<w:r/>`,
/// where a paired `<w:r></w:r>` would have its content range start after the
/// open tag. That difference is what tells a run with no children from a run
/// that was written without a body.
fn run_surgery_is_self_closing(element : ScannedElement) -> Bool {
  element.content_start == element.byte_end
}

///|
/// Plan the byte edits that replace the whole projecting content of one run.
///
/// The run is named by its position in the reader's story -- `paragraph_index`
/// among the projection's paragraphs, `run_index` among that paragraph's runs
/// -- which is the address the projection assigns and the only one stable
/// across the transforms the reader applies.
///
/// What the reader ends up seeing is `text` and nothing else from this run:
/// the first `w:t` carries it, every later `w:t` is emptied, and every other
/// projecting atom the run contributed is removed. Transparent seams are left
/// alone; they produce no text and removing them would change the run's
/// structure for no reason.
#warnings("-unused_value")
fn plan_whole_run_replacement(
  projection : ReaderProjection,
  source : BytesView,
  paragraph_index : Int,
  run_index : Int,
  text : String,
  // Every refusal below still runs; the EDIT RECORDS and the synthesised
  // run body are what is withheld. A caller replacing a run's text with
  // itself needs the run's writability established and the plan
  // discarded, and the refusal rules stay in one copy because this is
  // the same walk, not a second one.
  //
  // Escaping is NOT withheld, and must not be: it is where a control
  // character, an unpaired surrogate and a non-character are refused, so
  // deferring it would make the mode lose validation, which is the one
  // thing it may never do.
  validate_only? : Bool = false,
) -> Array[RunSurgeryEdit] raise DocxError {
  guard paragraph_index >= 0 && paragraph_index < projection.paragraphs.length() else {
    raise Unsupported(
      message="no paragraph \{paragraph_index} in this projection",
    )
  }
  let paragraph = projection.paragraphs[paragraph_index]
  // A logical paragraph joined from several physical `w:p` nodes cannot
  // be mutated: the locked rule in the roadmap says so, and the reason
  // is that the address names ONE paragraph while the bytes belong to
  // several, so a plan is complete for none of them. N0c2 has always
  // refused this; N0c1 accepted it, and N0c1 is the one the public
  // surface reaches.
  guard paragraph.sources.length() == 1 else {
    raise Unsupported(
      message="paragraph \{paragraph_index} joins \{paragraph.sources.length()} physical paragraphs, which cannot be edited as one",
    )
  }
  // The address is STRUCTURAL: the run record exists whether or not the
  // run contributed anything, so an atomless `<w:r/>` is addressable.
  guard run_index >= 0 && run_index < paragraph.runs.length() else {
    raise Unsupported(
      message="no run \{run_index} in paragraph \{paragraph_index}",
    )
  }
  let elements = projection.scan.elements()
  let target_run = paragraph.runs[run_index]
  let target = target_run.source
  let SourceElementId(target_identity) = target
  let run_element = elements[target_identity]
  // The run's OWN region guards the empty-run hole: a run with no
  // contributions still sits somewhere, and synthesizing text into a
  // field's instruction region would change what the field computes.
  match target_run.field_region {
    FieldInstruction =>
      raise Unsupported(
        message="run \{run_index} in paragraph \{paragraph_index} carries field instruction text",
      )
    MalformedField =>
      raise Unsupported(
        message="run \{run_index} in paragraph \{paragraph_index} sits in a malformed field",
      )
    _ => ()
  }
  // A refusal is not a region: truncation is discovered at story END,
  // after regions are assigned, so a truncated field's result run keeps
  // FieldResult and carries only the refusal. A field the classifier
  // refused has unreliable boundaries; nothing in it is writable.
  match target_run.field_refusal {
    Some(_) =>
      raise Unsupported(
        message="run \{run_index} in paragraph \{paragraph_index} sits in a field the classifier refused",
      )
    None => ()
  }
  // The cached-result region is checked AFTER the classifier's refusal,
  // not inside the region match above. A refused field's boundaries are
  // unreliable, so NOTHING in it is writable for a stronger reason than
  // "the next recalculation discards this" -- and a truncated field's
  // result run carries FieldResult and the refusal together, so region
  // order alone would report the weaker reason.
  //
  // The run slot carries this separately from the contributions because
  // an atomless run inside a field result is addressable, and
  // synthesising into one writes text the recalculation discards.
  if target_run.field_region is FieldResult {
    raise Unsupported(
      message="run \{run_index} in paragraph \{paragraph_index} holds a field's cached result, which the next recalculation discards",
    )
  }
  let owned : Array[ReaderProjectionContribution] = []
  for contribution in paragraph.contributions {
    if contribution.run_source == Some(target) {
      owned.push(contribution)
    }
  }
  // A content control that declares a checkbox rewrites whatever its content
  // projects, so no run inside one can be edited by writing bytes.
  //
  // Inferring this from a blanked contribution was not enough. The transform
  // replaces the *first* text in the whole control, so editing an earlier run
  // that had none moves the replacement onto the new text and lets the text it
  // had been hiding through. Measured on a control holding a tab-only run and
  // then `secret`: asked to set the first run to "MINE", the document went from
  // showing a tab to showing "secret". The caller's text vanished and hidden
  // text appeared, which is worse than either alone.
  //
  // So the whole construct is refused, by ancestry rather than by symptom.
  if run_surgery_inside_checkbox_control(elements, run_element) {
    raise Unsupported(
      message="run \{run_index} in paragraph \{paragraph_index} sits inside a checkbox content control, whose content the reader rewrites",
    )
  }
  // Restricted ancestry, checked AFTER the checkbox case so the more
  // specific refusal keeps precedence over the general one. The run slot
  // carries this on its own because an atomless run is addressable and
  // synthesising into a restricted region is the same mistake as writing
  // over one.
  if run_surgery_restricted_ancestor(elements, run_element) is Some(construct) {
    raise Unsupported(
      message="run \{run_index} in paragraph \{paragraph_index} sits in \{construct}, which the reader may match but must not rewrite",
    )
  }
  // A physical run that also contributes to another logical paragraph cannot
  // be edited by naming one of them: the same bytes carry both, so the plan
  // would be incomplete for one and a surprise for the other. No generated
  // document produces this and the projection is asserted not to, but the
  // check is cheap and the failure it prevents is silent.
  for index, other in projection.paragraphs {
    if index != paragraph_index {
      for candidate in other.runs {
        if candidate.source == target {
          raise Unsupported(
            message="run \{run_index} in paragraph \{paragraph_index} also contributes to paragraph \{index}",
          )
        }
      }
    }
  }
  let escaped = run_surgery_escape(text)
  let edits : Array[RunSurgeryEdit] = []
  // The one place the mode is observed. It takes a THUNK, not an edit:
  // MoonBit is strict, so passing the edit itself would build the record
  // and the synthesised run body before the flag was ever consulted.
  //
  // Refusals are raised by the walk itself, so withholding an edit
  // cannot withhold a refusal.
  let emit = build => if !validate_only { edits.push(build()) }
  let texts : Array[ScannedElement] = []
  let removals : Array[ScannedElement] = []
  // The same physical bytes must not be planned twice: two contributions
  // sharing a source would compose two edits over one span.
  let planned_sources : Array[Int] = []
  for contribution in owned {
    let SourceElementId(source_identity) = contribution.source
    let element = elements[source_identity]
    // A field's instruction text is machinery, not content: rewriting it
    // changes what the field computes rather than what it shows. A malformed
    // field has no reliable boundaries at all. Neither is safe to write
    // through, and the projection already classified both.
    match contribution.field_region {
      FieldInstruction =>
        raise Unsupported(
          message="run \{run_index} in paragraph \{paragraph_index} carries field instruction text",
        )
      MalformedField =>
        raise Unsupported(
          message="run \{run_index} in paragraph \{paragraph_index} sits in a malformed field",
        )
      // A field's CACHED RESULT reads like ordinary content and is not:
      // the next recalculation recomputes it and discards whatever was
      // written here. Nothing in this repository can detect that loss --
      // the reader projects the cached result, so a caller's read-back
      // confirms an edit that will not survive.
      FieldResult =>
        raise Unsupported(
          message="run \{run_index} in paragraph \{paragraph_index} holds a field's cached result, which the next recalculation discards",
        )
      _ => ()
    }
    // A restricted container may enclose one contribution of an
    // otherwise ordinary run, so the run slot's own check above is not
    // sufficient.
    if run_surgery_restricted_ancestor(elements, element) is Some(construct) {
      raise Unsupported(
        message="run \{run_index} in paragraph \{paragraph_index} draws text from \{construct}, which the reader may match but must not rewrite",
      )
    }
    match contribution.kind {
      // Visible non-text -- a break, a reference mark, an image, a
      // synthesized checkbox glyph -- is reader-visible content this plan
      // has no representation for, so it cannot say what removing it
      // would cost.
      VisibleNonText =>
        raise Unsupported(
          message="run \{run_index} in paragraph \{paragraph_index} holds visible non-text content",
        )
      // Boundaries produce no text: the run's own opening marker and the
      // wrappers the reader flattens. They stay -- unless the boundary is
      // an empty drawing or embedded object, which the inventory calls a
      // hard barrier and this plan has no more representation for than it
      // does for a visible atom.
      Transparent =>
        if run_surgery_is_hard_barrier_container(element) {
          raise Unsupported(
            message="run \{run_index} in paragraph \{paragraph_index} holds visible non-text content",
          )
        }
      // Suppressed content projects no TEXT, which is not the same as
      // being no CONTENT. The run-level suppressed set is dominated by
      // things a reader of the document can still see or that this
      // reader could not model: `w:pict`, a `w:sym` whose character it
      // could not map, `w:footnoteRef`/`w:endnoteRef`, `w:txbxContent`,
      // `w:del`, and -- widest of all -- any element it did not
      // recognise, which it suppresses with a warning.
      //
      // Replacing the run's text while leaving those bytes puts the
      // caller's text next to content they never saw. That is the same
      // failure the checkbox-control refusal above documents: the
      // caller's text appears AND hidden content survives, which is
      // worse than either alone. `VisibleNonText` is already refused for
      // exactly this reason; suppression is not a weaker case, only a
      // less legible one.
      SuppressedContent =>
        raise Unsupported(
          message="run \{run_index} in paragraph \{paragraph_index} holds suppressed content the reader could not model",
        )
      ProjectedText(FromText) => {
        if planned_sources.contains(source_identity) {
          raise Unsupported(
            message="run \{run_index} in paragraph \{paragraph_index} projects the same physical element twice",
          )
        }
        planned_sources.push(source_identity)
        if is_wml_uri(element.uri) && element.local_name == "t" {
          match element.text_map {
            Some(map) =>
              if map.contains_cdata {
                raise Unsupported(
                  message="run \{run_index} in paragraph \{paragraph_index} draws text from a CDATA section",
                )
              }
            None => ()
          }
          texts.push(element)
        } else {
          removals.push(element)
        }
      }
      // Tabs, symbols and the two hyphens all project text of their own,
      // so replacing the run's text means removing their atoms.
      ProjectedText(FromTab | FromNoBreakHyphen | FromSoftHyphen | FromSymbol) => {
        if planned_sources.contains(source_identity) {
          raise Unsupported(
            message="run \{run_index} in paragraph \{paragraph_index} projects the same physical element twice",
          )
        }
        planned_sources.push(source_identity)
        removals.push(element)
      }
    }
  }
  match texts {
    // The common case: the first `w:t` takes the new text in place, so its tag,
    // prefix and any existing `xml:space` are untouched.
    [first, .. rest] => {
      let wants_space = run_surgery_needs_space_preserve(text)
      let existing = run_surgery_space_declaration(source, first)
      // An existing declaration is replaced rather than joined: it may say
      // `default`, which is the opposite of what edge whitespace needs.
      match existing {
        Some((from, to)) =>
          if wants_space {
            match
              run_surgery_space_declaration_is_preserve(source, (from, to)) {
              Some(true) => ()
              Some(false) =>
                emit(() => {
                  byte_start: from,
                  byte_end: to,
                  replacement: "xml:space=\"preserve\"",
                })
              None =>
                raise Unsupported(
                  message="run \{run_index} in paragraph \{paragraph_index} carries an xml:space declaration whose value cannot be decoded",
                )
            }
          }
        None => ()
      }
      let add_space = wants_space && existing is None
      let attribute = if add_space { " xml:space=\"preserve\"" } else { "" }
      let text_prefix = run_surgery_qualified_prefix(source, first)
      if run_surgery_is_self_closing(first) {
        // `<w:t/>` has no content range to write into -- the scanner puts it at
        // the element's end -- so the self-closing marker becomes a body. Only
        // the `/>` is rewritten, which keeps any attributes already there.
        emit(() => {
          byte_start: first.byte_end - 2,
          byte_end: first.byte_end,
          replacement: "\{attribute}>\{escaped}</\{text_prefix}t>",
        })
      } else {
        if add_space {
          emit(() => {
            byte_start: first.content_start - 1,
            byte_end: first.content_start - 1,
            replacement: attribute,
          })
        }
        emit(() => {
          byte_start: first.content_start,
          byte_end: first.content_end,
          replacement: escaped,
        })
      }
      for later in rest {
        // A self-closing `w:t` already contributes nothing.
        if !run_surgery_is_self_closing(later) {
          emit(() => {
            byte_start: later.content_start,
            byte_end: later.content_end,
            replacement: "",
          })
        }
      }
    }
    // No `w:t` at all: an atom-only run, an empty one, or `<w:r/>`. One has to
    // be synthesised, and the run's own element says where it goes.
    [] => {
      let prefix = run_surgery_qualified_prefix(source, run_element)
      // Where the text goes matters. Putting it at the run's content end walks
      // it past every seam the run contains, so for
      // `<bookmarkStart/><tab/><bookmarkEnd/>` the tab would be deleted and the
      // replacement would land outside the bookmark -- reading the same and
      // meaning something else. It goes where the first atom it replaces was.
      // The first atom is *replaced* rather than removed-and-inserted-at.
      // Two edits sharing a byte offset would have their order decided by a
      // sort documented as unstable, and the splice requires the insertion
      // first.
      let (anchor, consumed) = match removals {
        [first, ..] => (first.byte_start, first.byte_end)
        [] => {
          let at = run_surgery_first_content_position(elements, run_element)
          (at, at)
        }
      }
      emit(() => {
        run_surgery_synthesise_text(
          run_element,
          prefix,
          escaped,
          text,
          anchor~,
          consumed~,
        )
      })
      if removals.length() > 0 {
        removals.remove(0) |> ignore
      }
    }
  }
  for element in removals {
    emit(() => {
      byte_start: element.byte_start,
      byte_end: element.byte_end,
      replacement: "",
    })
  }
  if !validate_only {
    edits.sort_by_key(edit => edit.byte_start)
  }
  edits
}

///|
/// Whether an existing declaration's value is already `preserve`.
///
/// The locked rule ensures `xml:space="preserve"` by ADDING it, or by
/// replacing a `default` value-span — an existing `preserve` is left
/// byte-identical. Rewriting it anyway would change quote style or
/// spacing for no reason and put bytes the caller never asked about
/// inside the declared footprint.
///
/// The comparison is against the NORMALIZED value, not the raw bytes.
/// XML resolves references inside an attribute value before the value
/// means anything, so `xml:space="pre&#x73;erve"` already says
/// `preserve` and must be left alone. `None` means the value could not
/// be decoded at all; the caller refuses rather than guessing, because
/// the alternative is rewriting bytes whose meaning is unknown.
///
/// Normalization also folds literal whitespace to spaces, which this
/// does not do. It cannot change the answer: `preserve` holds no
/// whitespace, so a value carrying any differs from it either way.
fn run_surgery_space_declaration_is_preserve(
  source : BytesView,
  span : (Int, Int),
) -> Bool? {
  let (from, to) = span
  let mut at = from
  while at < to && source[at] != b'"' && source[at] != b'\'' {
    at = at + 1
  }
  if at >= to {
    return None
  }
  let quote = source[at]
  let start = at + 1
  let mut end = start
  while end < to && source[end] != quote {
    end = end + 1
  }
  if end >= to {
    return None
  }
  let decoded = StringBuilder()
  let mut cursor = start
  while cursor < end {
    if source[cursor] == b'&' {
      // The reader's own decoder, which admits the five predefined
      // entities and strict numeric references — the same set the
      // scanner documents for attribute values. Nothing wider can
      // arrive: the strict gate rejects any DOCTYPE, so a document
      // declaring its own entities never reaches a surgery.
      let decoded_reference = decode_entity_token(source, cursor, end) catch {
        _ => return None
      }
      let (character, _, next) = decoded_reference
      // The scan must make progress on every iteration. The decoder
      // always returns a position past the `;`, but this walks
      // attacker-controlled bytes, and a decoder that ever failed to
      // advance would hang the surgery rather than refuse it.
      if next <= cursor {
        return None
      }
      decoded.write_char(character)
      cursor = next
    } else {
      // Everything outside a reference is literal, so the raw byte run
      // up to the next `&` decodes as UTF-8 exactly once.
      let mut run_end = cursor
      while run_end < end && source[run_end] != b'&' {
        run_end = run_end + 1
      }
      let text = @utf8.decode(source[cursor:run_end]) catch { _ => return None }
      decoded.write_string(text)
      cursor = run_end
    }
  }
  Some(decoded.to_string() == "preserve")
}

///|
/// Whether a Transparent contribution is really a HARD BARRIER wearing a
/// seam's clothes.
///
/// The reader routes `w:drawing` and `w:object` through the
/// transparent-boundary path, so an EMPTY one projects a single
/// Transparent contribution — indistinguishable, by kind alone, from a
/// bookmark or a run boundary. The five-class inventory calls drawings
/// and embedded objects hard barriers, and both surgeries already refuse
/// visible non-text; they simply could not recognise this shape.
fn run_surgery_is_hard_barrier_container(element : ScannedElement) -> Bool {
  // WML `drawing` and `object`, and every VML container the reader
  // dispatches through the same transparent path. `w:pict` is NOT here:
  // the reader emits it as Suppressed, so it never reaches a Transparent
  // branch, and the suppressed-content hole is recorded N0 debt rather
  // than something this predicate can close.
  if is_wml_uri(element.uri) {
    return element.local_name == "drawing" || element.local_name == "object"
  }
  element.uri == "urn:schemas-microsoft-com:vml" &&
  (
    element.local_name == "shape" ||
    element.local_name == "rect" ||
    element.local_name == "roundrect" ||
    element.local_name == "textbox" ||
    element.local_name == "group"
  )
}

///|
/// Where an element's open tag ends: just before its content, or before the
/// `/>` when it is self-closing.
fn run_surgery_open_tag_end(element : ScannedElement) -> Int {
  if run_surgery_is_self_closing(element) {
    element.byte_end - 2
  } else {
    element.content_start
  }
}

///|
/// The byte range of an existing `xml:space` declaration in this open tag, if
/// there is one.
///
/// Detecting the attribute is not enough: `xml:space="default"` declares the
/// opposite of what edge whitespace needs, so a plan that only avoided
/// duplicates would leave the text to be stripped. The declaration is replaced
/// wholesale when it is there and appended when it is not.
fn run_surgery_space_declaration(
  source : BytesView,
  element : ScannedElement,
) -> (Int, Int)? {
  let stop = run_surgery_open_tag_end(element)
  if stop <= element.byte_start || stop > source.length() {
    return None
  }
  let needle = b"xml:space"
  let mut at = element.byte_start
  // Quote state, so a match is only ever considered where an attribute
  // NAME can appear. Another attribute's VALUE can carry the whole shape
  // -- `data='x xml:space = "bogus"'` satisfies both the name-start and
  // `=` checks below -- and rewriting there corrupts that attribute while
  // leaving the element with no real declaration at all.
  let mut quote = b'\x00'
  while at + needle.length() <= stop {
    if quote != b'\x00' {
      if source[at] == quote {
        quote = b'\x00'
      }
      at = at + 1
      continue
    }
    if source[at] == b'"' || source[at] == b'\'' {
      quote = source[at]
      at = at + 1
      continue
    }
    let mut matched = true
    for offset in 0..<needle.length() {
      if source[at + offset] != needle[offset] {
        matched = false
        break
      }
    }
    // Only where an attribute name can start. The same text occurs inside
    // another attribute's *value* -- `w:id="xml:space"` -- and matching there
    // produced a range running from the middle of one value to the quote of
    // the next. Replacing it wrote `w:id="xml:space="preserve"x"`, which does
    // not parse.
    if matched {
      let before = source[at - 1]
      let starts_name = at > element.byte_start &&
        (
          before == b' ' ||
          before == b'\t' ||
          before == b'\n' ||
          before == b'\r'
        )
      let mut after = at + needle.length()
      while after < stop &&
            (
              source[after] == b' ' ||
              source[after] == b'\t' ||
              source[after] == b'\n' ||
              source[after] == b'\r'
            ) {
        after = after + 1
      }
      if !starts_name || after >= stop || source[after] != b'=' {
        matched = false
      }
    }
    if matched {
      // run to the end of the quoted value
      let mut cursor = at + needle.length()
      while cursor < stop && source[cursor] != b'"' && source[cursor] != b'\'' {
        cursor = cursor + 1
      }
      if cursor >= stop {
        return None
      }
      let quote = source[cursor]
      cursor = cursor + 1
      while cursor < stop && source[cursor] != quote {
        cursor = cursor + 1
      }
      if cursor >= stop {
        return None
      }
      return Some((at, cursor + 1))
    }
    at = at + 1
  }
  None
}

///|
/// Which restricted construct encloses this element, if any.
///
/// The Phase-3 inventory calls these regions PROJECTING-RESTRICTED: their
/// text MATCHES, so an agent can find it, but it must not be MUTATED.
/// Each fails for its own reason, and the surgeries name the construct
/// rather than a shared "restricted" so a caller learns what they hit.
///
/// Ancestry is walked over the PHYSICAL scan, not the projection. The
/// reader splices `mc:Fallback` and drops `mc:Choice`, so by projection
/// time the distinction is gone; the scan still carries the real parent
/// chain. The walk is INCLUSIVE -- an owned contribution can be sourced
/// at the container itself, not only beneath it.
fn run_surgery_restricted_ancestor(
  elements : Array[ScannedElement],
  element : ScannedElement,
) -> String? {
  let mut at = element.identity
  while at >= 0 && at < elements.length() {
    let ancestor = elements[at]
    if is_wml_uri(ancestor.uri) {
      match ancestor.local_name {
        // Tracked insertion. Writing here does not lose the text; it
        // reattributes it, so the document records that the insertion's
        // named author wrote words they never wrote.
        "ins" => return Some("a tracked insertion")
        // A content control. A data-bound one is repopulated from the
        // custom XML part when the document opens, discarding the edit
        // silently -- and this reader cannot tell a bound one from a
        // plain one, so the whole construct is refused.
        "sdt" => return Some("a content control")
        // Textbox content. The same text is commonly carried twice, once
        // per AlternateContent branch, so editing the projected copy
        // leaves the other saying something else.
        "txbxContent" => return Some("textbox content")
        _ => ()
      }
    }
    // The branch this reader projects is the one a consumer that
    // UNDERSTANDS the Choice will ignore, so an edit here is invisible
    // to modern Word and visible to older consumers.
    if ancestor.uri == MC_NAMESPACE && ancestor.local_name == "Fallback" {
      return Some("markup-compatibility fallback content")
    }
    at = ancestor.parent_index
  }
  None
}

///|
/// Whether any ancestor of this element is a content control declaring a
/// checkbox.
fn run_surgery_inside_checkbox_control(
  elements : Array[ScannedElement],
  element : ScannedElement,
) -> Bool {
  let mut at = element.parent_index
  while at >= 0 && at < elements.length() {
    let ancestor = elements[at]
    if is_wml_uri(ancestor.uri) && ancestor.local_name == "sdt" {
      let mut child = ancestor.first_child_index
      while child >= 0 {
        let properties = elements[child]
        if is_wml_uri(properties.uri) && properties.local_name == "sdtPr" {
          let mut declared = properties.first_child_index
          while declared >= 0 {
            let marker = elements[declared]
            if marker.uri == W14_NAMESPACE && marker.local_name == "checkbox" {
              return true
            }
            declared = marker.next_sibling_index
          }
          break
        }
        child = properties.next_sibling_index
      }
    }
    at = ancestor.parent_index
  }
  false
}

///|
/// Where content may start inside a run that has no atoms to replace.
///
/// After `w:rPr` if there is one -- run properties have to come first -- and at
/// the start of the run's content otherwise.
fn run_surgery_first_content_position(
  elements : Array[ScannedElement],
  run : ScannedElement,
) -> Int {
  let mut child = run.first_child_index
  let mut position = run.content_start
  while child >= 0 {
    let element = elements[child]
    if is_wml_uri(element.uri) && element.local_name == "rPr" {
      position = element.byte_end
    }
    child = element.next_sibling_index
  }
  position
}

///|
/// The qualified name an element is written with, taken from the source.
///
/// Synthesising `<w:t>` is only right when the document happens to bind `w` to
/// the WML namespace with that prefix. A part that binds it as `x`, or as the
/// default namespace, needs the prefix its own runs use -- and a hard-coded
/// closing `</w:r>` against an `<x:r/>` opening would not even be well-formed.
fn run_surgery_qualified_prefix(
  source : BytesView,
  element : ScannedElement,
) -> String {
  let stop = run_surgery_open_tag_end(element)
  let mut at = element.byte_start + 1
  let prefix : Array[Byte] = []
  while at < stop && at < source.length() {
    let byte = source[at]
    if byte == b':' {
      // Decoded, not walked byte by byte: XML permits non-ASCII prefixes, and
      // reinterpreting each UTF-8 byte as a character would spell a different
      // name. These bytes came from a part the scanner already accepted, so a
      // decode failure here is not reachable; an undecodable prefix falls back
      // to none, which the caller answers by binding the default namespace.
      return (try? @utf8.decode(Bytes::from_array(prefix)))
        .map(name => name + ":")
        .unwrap_or("")
    }
    if byte == b' ' ||
      byte == b'\t' ||
      byte == b'\n' ||
      byte == b'\r' ||
      byte == b'/' ||
      byte == b'>' {
      break
    }
    prefix.push(byte)
    at = at + 1
  }
  ""
}

///|
/// Put a `w:t` into a run that has none.
///
/// A self-closing `<w:r/>` has to become a paired element to hold anything, so
/// its `/>` is rewritten. A paired run keeps its tags and gains the element at
/// the end of its content, after whatever properties it already declares --
/// `w:rPr` has to stay first.
fn run_surgery_synthesise_text(
  run : ScannedElement,
  prefix : String,
  escaped : String,
  raw : String,
  anchor~ : Int,
  consumed~ : Int,
) -> RunSurgeryEdit {
  let attribute = if run_surgery_needs_space_preserve(raw) {
    " xml:space=\"preserve\""
  } else {
    ""
  }
  // The prefix comes from the run's own tag: a part that binds WML as `x`, or
  // as the default namespace, needs `<x:t>` or `<t>`, and a hard-coded
  // `</w:r>` closing an `<x:r>` would not even be well-formed.
  //
  // The prefix alone is not enough, though. Synthesis can land inside a
  // wrapper that rebound it, in which case the element would carry the run's
  // spelling and somebody else's namespace -- text the reader cannot see. The
  // binding travels with the element so it means WML wherever it lands.
  // The run's own namespace, not a constant. This project reads both the
  // Transitional and Strict WML vocabularies, and binding the Transitional URI
  // into a Strict document would produce a run whose text element belongs to a
  // different vocabulary than the run around it.
  let wml = run.uri
  let binding = if prefix == "" {
    " xmlns=\"\{wml}\""
  } else {
    let name = prefix.view(end_offset=prefix.length() - 1).to_owned()
    " xmlns:\{name}=\"\{wml}\""
  }
  let synthesised = "<\{prefix}t\{binding}\{attribute}>\{escaped}</\{prefix}t>"
  if run_surgery_is_self_closing(run) {
    // `<w:r/>` -> `<w:r><w:t>...</w:t></w:r>`, replacing the two bytes `/>`.
    {
      byte_start: run.byte_end - 2,
      byte_end: run.byte_end,
      replacement: ">\{synthesised}</\{prefix}r>",
    }
  } else {
    { byte_start: anchor, byte_end: consumed, replacement: synthesised }
  }
}
