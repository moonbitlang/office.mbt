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
    // Permanently unassigned in every plane.
    if (code & 0xFFFE) == 0xFFFE {
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
  projection : ReaderOrderProjection,
  source : BytesView,
  paragraph_index : Int,
  run_index : Int,
  text : String,
) -> Array[RunSurgeryEdit] raise DocxError {
  guard paragraph_index >= 0 && paragraph_index < projection.paragraphs.length() else {
    raise Unsupported(
      message="no paragraph \{paragraph_index} in this projection",
    )
  }
  let paragraph = projection.paragraphs[paragraph_index]
  let owned : Array[ReaderOrderContribution] = []
  for contribution in paragraph.contributions {
    if contribution.logical_run_index == run_index &&
      contribution.run_identity is Some(_) {
      owned.push(contribution)
    }
  }
  guard owned.length() > 0 else {
    raise Unsupported(
      message="no run \{run_index} in paragraph \{paragraph_index}",
    )
  }
  // A physical run that also contributes to another logical paragraph cannot
  // be edited by naming one of them: the same bytes carry both, so the plan
  // would be incomplete for one and a surprise for the other. No generated
  // document produces this and the projection is asserted not to, but the
  // check is cheap and the failure it prevents is silent.
  let target = owned[0].run_identity
  for index, other in projection.paragraphs {
    if index != paragraph_index {
      for contribution in other.contributions {
        if contribution.run_identity == target {
          raise Unsupported(
            message="run \{run_index} in paragraph \{paragraph_index} also contributes to paragraph \{index}",
          )
        }
      }
    }
  }
  let escaped = run_surgery_escape(text)
  let edits : Array[RunSurgeryEdit] = []
  let texts : Array[ScannedElement] = []
  let removals : Array[ScannedElement] = []
  for contribution in owned {
    let element = projection.source_elements[contribution.source_identity]
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
      _ => ()
    }
    match contribution.kind {
      // A barrier means the projection could not say what this contributes, so
      // it cannot say what removing it would cost either.
      HardBarrier =>
        raise Unsupported(
          message="run \{run_index} in paragraph \{paragraph_index} holds an unclassified element",
        )
      // Seams produce no text. They are the run's own opening marker and the
      // wrappers the reader flattens, and they stay.
      TransparentSeam => ()
      TextAtom =>
        if is_wml_uri(element.uri) && element.local_name == "t" {
          // The projection blanks a contribution the checkbox transform
          // replaced, keeping it so its bytes stay addressable. Writing into
          // one would be answered by that transform blanking it again: the
          // caller would ask to set text and silently get none.
          if contribution.value.length() == 0 &&
            element.content_end > element.content_start {
            raise Unsupported(
              message="run \{run_index} in paragraph \{paragraph_index} holds text the reader replaces, so writing to it would have no effect",
            )
          }
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
      // Tabs, breaks, symbols and the two hyphens all project text of their
      // own, so replacing the run's text means removing them.
      _ => removals.push(element)
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
            edits.push({
              byte_start: from,
              byte_end: to,
              replacement: "xml:space=\"preserve\"",
            })
          }
        None => ()
      }
      let add_space = wants_space && existing is None
      let attribute = if add_space { " xml:space=\"preserve\"" } else { "" }
      if run_surgery_is_self_closing(first) {
        // `<w:t/>` has no content range to write into -- the scanner puts it at
        // the element's end -- so the self-closing marker becomes a body. Only
        // the `/>` is rewritten, which keeps any attributes already there.
        edits.push({
          byte_start: first.byte_end - 2,
          byte_end: first.byte_end,
          replacement: "\{attribute}>\{escaped}</w:t>",
        })
      } else {
        if add_space {
          edits.push({
            byte_start: first.content_start - 1,
            byte_end: first.content_start - 1,
            replacement: attribute,
          })
        }
        edits.push({
          byte_start: first.content_start,
          byte_end: first.content_end,
          replacement: escaped,
        })
      }
      for later in rest {
        // A self-closing `w:t` already contributes nothing.
        if !run_surgery_is_self_closing(later) {
          edits.push({
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
      let run = projection.source_elements[owned[0].source_identity]
      let prefix = run_surgery_qualified_prefix(source, run)
      // Where the text goes matters. Putting it at the run's content end walks
      // it past every seam the run contains, so for
      // `<bookmarkStart/><tab/><bookmarkEnd/>` the tab would be deleted and the
      // replacement would land outside the bookmark -- reading the same and
      // meaning something else. It goes where the first atom it replaces was.
      let anchor = match removals {
        [first, ..] => first.byte_start
        [] => run_surgery_first_content_position(source, projection, run)
      }
      edits.push(
        run_surgery_synthesise_text(run, prefix, escaped, text, anchor~),
      )
    }
  }
  for element in removals {
    edits.push({
      byte_start: element.byte_start,
      byte_end: element.byte_end,
      replacement: "",
    })
  }
  edits.sort_by_key(edit => edit.byte_start)
  edits
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
  while at + needle.length() <= stop {
    let mut matched = true
    for offset in 0..<needle.length() {
      if source[at + offset] != needle[offset] {
        matched = false
        break
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
/// Where content may start inside a run that has no atoms to replace.
///
/// After `w:rPr` if there is one -- run properties have to come first -- and at
/// the start of the run's content otherwise.
fn run_surgery_first_content_position(
  source : BytesView,
  projection : ReaderOrderProjection,
  run : ScannedElement,
) -> Int {
  ignore(source)
  let mut child = run.first_child_index
  let mut position = run.content_start
  while child >= 0 {
    let element = projection.source_elements[child]
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
      let out = StringBuilder::new()
      for unit in prefix {
        out.write_char(unit.to_int().unsafe_to_char())
      }
      return out.to_string() + ":"
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
/// Whether this element's open tag already declares `xml:space`.
fn run_surgery_declares_space(
  source : BytesView,
  element : ScannedElement,
) -> Bool {
  let stop = if run_surgery_is_self_closing(element) {
    element.byte_end - 2
  } else {
    element.content_start
  }
  if stop <= element.byte_start || stop > source.length() {
    return false
  }
  let needle = b"xml:space"
  let mut at = element.byte_start
  while at + needle.length() <= stop {
    let mut matched = true
    for offset in 0..<needle.length() {
      if source[at + offset] != needle[offset] {
        matched = false
        break
      }
    }
    if matched {
      return true
    }
    at = at + 1
  }
  false
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
) -> RunSurgeryEdit {
  let attribute = if run_surgery_needs_space_preserve(raw) {
    " xml:space=\"preserve\""
  } else {
    ""
  }
  // The prefix comes from the run's own tag. A part that binds WML as `x`, or
  // as the default namespace, needs `<x:t>` or `<t>` -- and a hard-coded
  // `</w:r>` against an `<x:r/>` opening would not even be well-formed.
  let synthesised = "<\{prefix}t\{attribute}>\{escaped}</\{prefix}t>"
  if run_surgery_is_self_closing(run) {
    // `<w:r/>` -> `<w:r><w:t>...</w:t></w:r>`, replacing the two bytes `/>`.
    {
      byte_start: run.byte_end - 2,
      byte_end: run.byte_end,
      replacement: ">\{synthesised}</\{prefix}r>",
    }
  } else {
    { byte_start: anchor, byte_end: anchor, replacement: synthesised }
  }
}
