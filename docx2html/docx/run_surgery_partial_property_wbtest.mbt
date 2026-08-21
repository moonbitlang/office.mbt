///|
/// N0c2 B3: general multi-edit composition, proved over documents nobody
/// wrote by hand. The hostile grammar (reader_projection_property_wbtest)
/// generates the documents; this suite derives edit batches from each
/// document's OWN projection — so the boundary-pair matrix is covered by
/// construction rather than by hand-listed fixtures — and holds every
/// planned batch to the acceptance claims of #236:
///
///   1. the re-read paragraph projection equals an expectation the TEST
///      computes (never the planner's own receipt alone — the receipt is
///      then held to the same independent string),
///   2. every byte edit falls inside what a correct partial plan may touch,
///      derived from the SOURCE TREE (the trap N0c1 documents: bounding by
///      the plan's own union lets a widened edit pass),
///   3. every byte outside the declared union survives at its shifted
///      offset,
///   4. the edited document still reads,
///   5. every refusal names a class from the stable taxonomy and returns
///      no plan.
///
/// Coverage is accounted as ORDERED (start-kind, end-kind) pairs, with
/// text endpoints resolved to token granularity (raw interior, raw edge,
/// entity edge, numeric-reference edge), because a planner can reject one
/// ordered pair while every marginal endpoint total stays green.
priv struct PartialBatchPlan {
  paragraph_index : Int
  edits : Array[ParagraphTextEdit]
  pairs : Array[String]
}

///|
/// Every class an offset falls into, finest first. Text interiors are
/// resolved against the host's token map so an entity boundary is not
/// reported as ordinary raw text.
fn partial_offset_classes(
  paragraph : ReaderProjectionParagraph,
  elements : Array[ScannedElement],
  offset : Int,
) -> Array[String] {
  let classes : Array[String] = []
  for contribution in paragraph.contributions {
    let start = contribution.projection_start - paragraph.projection_start
    let end = contribution.projection_end - paragraph.projection_start
    match contribution.kind {
      ProjectedText(FromText) => {
        if offset < start || offset > end {
          continue
        }
        let SourceElementId(identity) = contribution.source
        let local = offset - start
        match elements[identity].text_map {
          Some(map) => {
            let mut named = false
            for token in map.tokens {
              let token_start = token.projection_start
              let token_end = token.projection_end
              let kind = match token.kind {
                RawText => "raw"
                EntityRef => "entity"
                NumericCharRef => "numref"
                CData => "cdata"
              }
              if local == token_start || local == token_end {
                classes.push("\{kind}-edge")
                named = true
              } else if local > token_start && local < token_end {
                classes.push("\{kind}-interior")
                named = true
              }
            }
            if !named {
              classes.push("empty-text")
            }
          }
          None => classes.push("closed-text")
        }
        if offset == start {
          classes.push("text-start-edge")
        }
        if offset == end {
          classes.push("text-end-edge")
        }
      }
      ProjectedText(_) =>
        if offset == start {
          classes.push("atom-start-edge")
        } else if offset == end {
          classes.push("atom-end-edge")
        } else if offset > start && offset < end {
          classes.push("atom-interior")
        }
      VisibleNonText => if offset == start { classes.push("barrier-edge") }
      Transparent => if offset == start { classes.push("seam-edge") }
      SuppressedContent =>
        if offset == start {
          classes.push("suppressed-edge")
        }
    }
  }
  if classes.length() == 0 {
    classes.push("bare")
  }
  classes
}

///|
/// The single most specific class of an offset, so an ordered pair key is
/// well defined even where several contributions meet.
fn partial_primary_class(classes : Array[String]) -> String {
  for
    candidate in [
      "entity-interior", "numref-interior", "cdata-interior", "atom-interior", "entity-edge",
      "numref-edge", "cdata-edge", "raw-interior", "atom-start-edge", "atom-end-edge",
      "raw-edge", "empty-text", "closed-text", "text-start-edge", "text-end-edge",
      "barrier-edge", "suppressed-edge", "seam-edge",
    ] {
    if classes.contains(candidate) {
      return candidate
    }
  }
  "bare"
}

///|
/// Derive a batch from a paragraph's own projection. Every geometry runs on
/// every paragraph: selecting one by document index would leave whole
/// geometries unexercised on documents whose shapes only they reach.
/// EXHAUSTIVE single-range batches over one paragraph: every (i, j) with
/// i <= j, as a replacement and — when non-empty — as a deletion. Sampled
/// geometries can only demonstrate the pairs they happen to hit, which is
/// why the identity set they produced was not the permitted set.
fn partial_exhaustive_batches_for(
  projection : ReaderProjection,
  elements : Array[ScannedElement],
  paragraph_index : Int,
) -> Array[PartialBatchPlan] {
  let paragraph = projection.paragraphs[paragraph_index]
  let width = paragraph.projection_end - paragraph.projection_start
  let batches : Array[PartialBatchPlan] = []
  fn build(requested : Array[(Int, Int, String)]) -> Unit {
    let edits : Array[ParagraphTextEdit] = []
    let pairs : Array[String] = []
    for entry in requested {
      let (start, end, replacement) = entry
      edits.push({ start, end, replacement })
      let start_class = partial_primary_class(
        partial_offset_classes(paragraph, elements, start),
      )
      let end_class = partial_primary_class(
        partial_offset_classes(paragraph, elements, end),
      )
      let shape = if start == end {
        "insert"
      } else if replacement == "" {
        "delete"
      } else {
        "replace"
      }
      pairs.push("\{shape}:\{start_class}>\{end_class}")
    }
    if edits.length() > 0 {
      batches.push({ paragraph_index, edits, pairs })
    }
  }

  for i in 0..<=width {
    for j in i..<=width {
      if i == j {
        build([(i, j, "X")])
      } else {
        build([(i, j, "X")])
        build([(i, j, "")])
      }
    }
  }
  // Composition shapes the single-range sweep cannot express.
  if width >= 3 {
    build([(0, 1, "A"), (2, 3, "C")])
    build([(0, 0, "P"), (1, width - 1, "M"), (width, width, "S")])
  }
  batches
}

///|
fn partial_batches_for(
  projection : ReaderProjection,
  elements : Array[ScannedElement],
  paragraph_index : Int,
) -> Array[PartialBatchPlan] {
  let paragraph = projection.paragraphs[paragraph_index]
  let width = paragraph.projection_end - paragraph.projection_start
  let batches : Array[PartialBatchPlan] = []
  fn build(requested : Array[(Int, Int, String)]) -> Unit {
    let edits : Array[ParagraphTextEdit] = []
    let pairs : Array[String] = []
    for entry in requested {
      let (start, end, replacement) = entry
      edits.push({ start, end, replacement })
      let start_class = partial_primary_class(
        partial_offset_classes(paragraph, elements, start),
      )
      let end_class = partial_primary_class(
        partial_offset_classes(paragraph, elements, end),
      )
      let shape = if start == end {
        "insert"
      } else if replacement == "" {
        "delete"
      } else {
        "replace"
      }
      pairs.push("\{shape}:\{start_class}>\{end_class}")
    }
    if edits.length() > 0 {
      batches.push({ paragraph_index, edits, pairs })
    }
  }

  if width == 0 {
    // A paragraph that projects nothing still has one insertion position:
    // the atomless-run synthesis path — singly, and composed, since two
    // insertions there share one carrier and one anchor.
    build([(0, 0, "N0c2")])
    build([(0, 0, "X"), (0, 0, "Y")])
    return batches
  }
  build([(width / 3, width - width / 3, "N0c2")])
  build([(0, width / 2, "head"), (width / 2, width, "")])
  if width >= 2 {
    build([(0, 0, "pre"), (1, width - 1, "mid"), (width, width, "post")])
  } else {
    build([(0, 0, "pre"), (width, width, "post")])
  }
  // Single-unit steps walk EVERY internal boundary, which is what turns
  // the pair accounting from a sample into a sweep.
  for at in 0..<width {
    build([(at, at + 1, "u")])
    build([(at, at, "i")])
  }
  build([(width, width, "tail")])
  batches
}

///|
/// The bytes a correct partial plan may touch, derived from the SOURCE
/// TREE rather than from the plan: each mapped `w:t`'s content range and
/// its open tag (where `xml:space` lives), each atom's whole element, and
/// each run's synthesis anchors.
fn partial_space_declaration_span(
  source : BytesView,
  element : ScannedElement,
) -> (Int, Int)? {
  // `xml:space = '...'` inside an open tag, located by the test. Quote
  // style and spacing around `=` both vary in real documents, and a scan
  // that only knew one spelling would reject correct plans over the
  // others.
  let name = "xml:space"
  let limit = element.content_start
  let mut at = element.byte_start
  // Quote state: another attribute's VALUE can contain the whole shape.
  let mut quote = 0
  while at + name.length() <= limit {
    if quote != 0 {
      if source[at].to_int() == quote {
        quote = 0
      }
      at = at + 1
      continue
    }
    if source[at].to_int() == 0x22 || source[at].to_int() == 0x27 {
      quote = source[at].to_int()
      at = at + 1
      continue
    }
    let mut matched = true
    for offset in 0..<name.length() {
      if source[at + offset].to_int() != name[offset].to_int() {
        matched = false
        break
      }
    }
    // `xml:space` must be a whole attribute NAME, not the tail of one:
    // `notxml:space='default'` is a different attribute entirely.
    if matched && at > element.byte_start {
      let previous = source[at - 1].to_int()
      let name_char = (previous >= 0x41 && previous <= 0x5A) ||
        (previous >= 0x61 && previous <= 0x7A) ||
        (previous >= 0x30 && previous <= 0x39) ||
        previous == 0x2D ||
        previous == 0x2E ||
        previous == 0x5F ||
        previous == 0x3A
      if name_char {
        at = at + 1
        continue
      }
    }
    if matched {
      let mut cursor = at + name.length()
      while cursor < limit && is_partial_space_byte(source[cursor]) {
        cursor = cursor + 1
      }
      if cursor >= limit || source[cursor].to_int() != 0x3D {
        at = at + 1
        continue
      }
      cursor = cursor + 1
      while cursor < limit && is_partial_space_byte(source[cursor]) {
        cursor = cursor + 1
      }
      if cursor >= limit {
        return None
      }
      let quote = source[cursor].to_int()
      if quote != 0x22 && quote != 0x27 {
        return None
      }
      let mut close = cursor + 1
      while close < limit && source[close].to_int() != quote {
        close = close + 1
      }
      if close < limit {
        return Some((at, close + 1))
      }
      return None
    }
    at = at + 1
  }
  None
}

///|
fn is_partial_space_byte(value : Byte) -> Bool {
  let code = value.to_int()
  code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D
}

///|
/// The escaping a correct plan applies, reimplemented here so the oracle
/// can predict payloads without borrowing production's escaper.
fn partial_escape(text : String) -> String {
  let out = StringBuilder()
  for char in text {
    match char {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '\r' => out.write_string("&#xD;")
      _ => out.write_char(char)
    }
  }
  out.to_string()
}

///|
fn partial_paragraph_projection(
  paragraph : ReaderProjectionParagraph,
) -> String {
  let out = StringBuilder()
  for contribution in paragraph.contributions {
    out.write_string(contribution.value)
  }
  out.to_string()
}

///|
/// The qualified prefix a run is written with, read from the source the
/// way a synthesized element must reproduce it.
fn partial_run_prefix(
  source : BytesView,
  element : ScannedElement,
) -> String raise {
  // The element NAME only: stop at any XML whitespace, `/` or `>`, and
  // decode the name as UTF-8 rather than byte-by-byte, so a non-ASCII
  // prefix is reproduced rather than mangled. Stopping late would let an
  // ATTRIBUTE's colon be mistaken for the element's prefix.
  let mut end = element.byte_start + 1
  while end < element.content_start {
    let code = source[end].to_int()
    if code == 0x20 ||
      code == 0x09 ||
      code == 0x0A ||
      code == 0x0D ||
      code == 0x2F ||
      code == 0x3E {
      break
    }
    end = end + 1
  }
  let name = @utf8.decode(source[element.byte_start + 1:end].to_bytes())
  match name.find(":") {
    Some(index) => name.view(end_offset=index + 1).to_owned()
    None => ""
  }
}

///|
/// The EXACT element synthesis writes, modelled here so the license can
/// demand it verbatim rather than by substring — a content check would
/// accept an empty write into one host and a doubled write into another.
fn partial_synthesised_element(
  source : BytesView,
  run_element : ScannedElement,
  text : String,
) -> String raise {
  let prefix = partial_run_prefix(source, run_element)
  let binding = if prefix == "" {
    " xmlns=\"" + run_element.uri + "\""
  } else {
    let name = prefix.view(end_offset=prefix.length() - 1).to_owned()
    " xmlns:" + name + "=\"" + run_element.uri + "\""
  }
  let attribute = if partial_needs_space(text) {
    " xml:space=\"preserve\""
  } else {
    ""
  }
  let element = "<" +
    prefix +
    "t" +
    binding +
    attribute +
    ">" +
    partial_escape(text) +
    "</" +
    prefix +
    "t>"
  if run_element.content_start == run_element.byte_end {
    ">" + element + "</" + prefix + "r>"
  } else {
    element
  }
}

///|
fn partial_needs_space(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  fn edge(one : String) -> Bool {
    let mut code = 0
    for char in one {
      code = char.to_int()
    }
    code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D
  }

  edge(text.view(start_offset=0, end_offset=1).to_owned()) ||
  edge(text.view(start_offset=text.length() - 1).to_owned())
}

///|
/// The licenses a correct plan may consume for THIS request, derived from
/// the source tree and the requested ranges with exact multiplicity.
///
/// Placement is modelled the way production places: the FIRST projecting
/// contribution a range consumes carries the replacement, and every later
/// one it reaches is trimmed or emptied. Modelling the replacement into
/// every intersected host instead would compute the wrong post-batch
/// content, and so grant `xml:space` licenses where production needs none
/// and withhold them where it does.
fn partial_expected_licenses(
  source : BytesView,
  paragraph : ReaderProjectionParagraph,
  elements : Array[ScannedElement],
  requested : Array[ParagraphTextEdit],
) -> Array[(Int, Int, Bool, String)] raise {
  // (from, to, exact, payload). Binding the PAYLOAD is what stops a plan
  // from spending the right permissions on the wrong writes: deleting one
  // host and writing the replacement into the next consumes exactly the
  // same spans, reprojects identically and keeps every count, yet
  // violates first-consumed placement and changes which run's formatting
  // the text inherits. A leading `?` marks a payload matched by CONTENT,
  // used where synthesis composes the run's own prefix and namespace.
  let licenses : Array[(Int, Int, Bool, String)] = []
  // Insertion sites, and where each one's license sits, so several
  // requests at one site accumulate into the single coalesced payload
  // production emits there.
  let insertion_sites : Array[Int] = []
  let insertion_license_at : Array[Int] = []
  // Sites accumulate the RAW text of every request that lands there, and
  // the payload is composed once at the end: production coalesces the
  // requests and then escapes (or synthesizes) the combined text, so
  // concatenating already-composed payloads would predict the wrong
  // bytes.
  let insertion_raw : Array[String] = []
  let insertion_synth : Array[Int] = []
  fn note_insertion(site : Int, text : String, synth_run : Int) -> Unit {
    for index, existing in insertion_sites {
      if existing == site {
        insertion_raw[index] = insertion_raw[index] + text
        return
      }
    }
    insertion_sites.push(site)
    insertion_raw.push(text)
    insertion_synth.push(synth_run)
  }

  // Ordered projecting contributions, so "first consumed" is well defined.
  let projecting : Array[(ReaderProjectionContribution, Int, Int)] = []
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(_) {
      projecting.push(
        (
          contribution,
          contribution.projection_start - paragraph.projection_start,
          contribution.projection_end - paragraph.projection_start,
        ),
      )
    }
  }
  fn run_of(contribution : ReaderProjectionContribution) -> SourceElementId {
    match contribution.run_source {
      Some(source_id) => source_id
      None => contribution.source
    }
  }

  fn first_consumed(edit : ParagraphTextEdit) -> SourceElementId? {
    for entry in projecting {
      let (contribution, start, end) = entry
      if edit.start < end && edit.end > start {
        return Some(contribution.source)
      }
    }
    None
  }

  for entry in projecting {
    let (contribution, start, end) = entry
    let SourceElementId(identity) = contribution.source
    let element = elements[identity]
    match contribution.kind {
      ProjectedText(FromText) => {
        guard is_wml_uri(element.uri) && element.local_name == "t" else {
          continue
        }
        // A self-closing `<w:t/>` is refused outright by partial surgery,
        // so no plan exists and no license is owed.
        if element.content_start == element.byte_end {
          continue
        }
        guard element.text_map is Some(map) else { continue }
        let after = StringBuilder()
        let mut cursor = 0
        let mut touched = false
        for edit in requested {
          let touches = if edit.start == edit.end {
            start <= edit.start && edit.start <= end
          } else {
            edit.start < end && edit.end > start
          }
          if !touches {
            continue
          }
          // Logical no-ops emit nothing at all, so they earn nothing:
          // an empty insertion, and a consuming range whose current
          // projected slice already equals its replacement.
          if edit.start == edit.end && edit.replacement == "" {
            continue
          }
          if edit.start != edit.end &&
            partial_paragraph_projection(paragraph)
            .view(start_offset=edit.start, end_offset=edit.end)
            .to_owned() ==
            edit.replacement {
            continue
          }
          touched = true
          let clipped_start = if edit.start > start {
            edit.start
          } else {
            start
          }
          let clipped_end = if edit.end < end { edit.end } else { end }
          let range_start = clipped_start - start
          let range_end = clipped_end - start
          // Only the FIRST consumed contribution carries the text.
          let carries = edit.start == edit.end ||
            first_consumed(edit) == Some(contribution.source)
          let written = if carries { edit.replacement } else { "" }
          match
            (map.byte_offset_at(range_start), map.byte_offset_at(range_end)) {
            (Some(from), Some(to)) =>
              if from == to {
                // Equal-offset insertions COALESCE into one edit, so one
                // site earns one license however many requests share it.
                note_insertion(from, written, -1)
              } else {
                licenses.push((from, to, true, partial_escape(written)))
              }
            _ => ()
          }
          after.write_string(
            contribution.value
            .view(start_offset=cursor, end_offset=range_start)
            .to_owned(),
          )
          after.write_string(written)
          cursor = range_end
        }
        if !touched {
          continue
        }
        after.write_string(
          contribution.value.view(start_offset=cursor).to_owned(),
        )
        if partial_needs_space(after.to_string()) {
          match partial_space_declaration_span(source, element) {
            Some((from, to)) =>
              licenses.push((from, to, true, "xml:space=\"preserve\""))
            None =>
              licenses.push(
                (
                  element.content_start - 1,
                  element.content_start - 1,
                  true,
                  " xml:space=\"preserve\"",
                ),
              )
          }
        }
      }
      ProjectedText(_) =>
        for edit in requested {
          // A no-op over an atom (replacing a tab with a tab) plans
          // nothing, exactly as over text.
          if edit.start != edit.end &&
            partial_paragraph_projection(paragraph)
            .view(start_offset=edit.start, end_offset=edit.end)
            .to_owned() ==
            edit.replacement {
            continue
          }
          if edit.start != edit.end && edit.start <= start && end <= edit.end {
            // Consumed whole: deleted, or replaced by a synthesized
            // element carrying the text. The payload is the exact
            // element synthesis writes, modelled below.
            let carries = first_consumed(edit) == Some(contribution.source)
            let payload = if carries && edit.replacement != "" {
              let SourceElementId(owner) = run_of(contribution)
              partial_synthesised_element(
                source,
                elements[owner],
                edit.replacement,
              )
            } else {
              ""
            }
            licenses.push((element.byte_start, element.byte_end, true, payload))
          }
          if edit.start == edit.end && edit.replacement != "" {
            let SourceElementId(owner) = run_of(contribution)
            if edit.start == start {
              note_insertion(element.byte_start, edit.replacement, owner)
            }
            if edit.start == end {
              note_insertion(element.byte_end, edit.replacement, owner)
            }
          }
        }
      _ => ()
    }
  }
  for index, site in insertion_sites {
    let text = insertion_raw[index]
    let synth_run = insertion_synth[index]
    let payload = if synth_run >= 0 {
      partial_synthesised_element(source, elements[synth_run], text)
    } else {
      partial_escape(text)
    }
    licenses.push((site, site, true, payload))
  }
  // A paragraph that projects nothing: ONE synthesis license, however
  // many non-empty insertions ask for it — production coalesces them.
  let mut occupied = false
  for contribution in paragraph.contributions {
    match contribution.kind {
      VisibleNonText | SuppressedContent => occupied = true
      Transparent => {
        let SourceElementId(seam_identity) = contribution.source
        if run_surgery_is_hard_barrier_container(elements[seam_identity]) {
          occupied = true
        }
      }
      _ => ()
    }
  }
  if projecting.length() == 0 && !occupied && paragraph.runs.length() == 1 {
    let SourceElementId(run_identity) = paragraph.runs[0].source
    let run_element = elements[run_identity]
    let mut wanted = false
    for edit in requested {
      if edit.start == edit.end && edit.replacement != "" {
        wanted = true
      }
    }
    let mut synthesis_text = ""
    for edit in requested {
      if edit.start == edit.end && edit.replacement != "" {
        synthesis_text = synthesis_text + edit.replacement
      }
    }
    if wanted {
      if run_element.content_start == run_element.byte_end {
        licenses.push(
          (
            run_element.byte_end - 2,
            run_element.byte_end,
            true,
            partial_synthesised_element(source, run_element, synthesis_text),
          ),
        )
      } else {
        let mut anchor = run_element.content_start
        let mut child = run_element.first_child_index
        while child >= 0 {
          let candidate = elements[child]
          if is_wml_uri(candidate.uri) && candidate.local_name == "rPr" {
            anchor = candidate.byte_end
          }
          child = candidate.next_sibling_index
        }
        licenses.push(
          (
            anchor,
            anchor,
            true,
            partial_synthesised_element(source, run_element, synthesis_text),
          ),
        )
      }
    }
  }
  licenses
}

///|
/// Every stable refusal class, so a refusal cannot pass by merely carrying
/// the prefix.
let partial_refusal_class_names : Array[String] = [
  "InvalidParagraph", "InvalidRange", "UnorderedEdits", "LogicalOverlap", "MultiPhysicalParagraph",
  "NonScalarBoundary", "AmbiguousBoundary", "CDataContext", "VisibleBarrier", "SuppressedRegion",
  "RestrictedRegion", "PartialFieldInstruction", "PartialMalformedField", "RefusedField",
  "PartialCheckboxControl", "DuplicateSource", "CrossParagraphSourceReuse", "UnsupportedTextSource",
  "NoSynthesisCarrier", "InvalidReplacement", "PartialBudgetExceeded", "InternalPlanConflict",
]

///|
/// Plan a batch and hold it to every acceptance claim, or accept a typed
/// refusal. Returns (planned pairs, refusal class) — exactly one is
/// non-empty.
fn assert_partial_batch(
  source : String,
  projection : ReaderProjection,
  batch : PartialBatchPlan,
) -> (Array[String], String, Int) raise {
  let bytes = @utf8.encode(source)
  let elements = projection.scan.elements()
  let paragraph = projection.paragraphs[batch.paragraph_index]
  // The expectation the TEST owns: the paragraph's own projection with the
  // requested ranges substituted. Nothing here consults the planner.
  let before = StringBuilder()
  for contribution in paragraph.contributions {
    before.write_string(contribution.value)
  }
  let before_projection = before.to_string()
  let independent = StringBuilder()
  let mut cursor = 0
  for edit in batch.edits {
    independent.write_string(
      before_projection
      .view(start_offset=cursor, end_offset=edit.start)
      .to_owned(),
    )
    independent.write_string(edit.replacement)
    cursor = edit.end
  }
  independent.write_string(
    before_projection.view(start_offset=cursor).to_owned(),
  )
  let expected = independent.to_string()
  let licenses = partial_expected_licenses(
    bytes[:],
    paragraph,
    elements,
    batch.edits,
  )
  let planned = plan_paragraph_text_edits(
    projection,
    bytes[:],
    batch.paragraph_index,
    batch.edits,
  ) catch {
    Unsupported(message~) => {
      // Claim 5: a typed refusal names a class from the taxonomy.
      assert_true(
        message.has_prefix("partial surgery ["),
        msg="untyped refusal: \{message}",
      )
      let mut named = ""
      for name in partial_refusal_class_names {
        if message.has_prefix("partial surgery [\{name}]") {
          named = name
        }
      }
      assert_true(named != "", msg="unknown refusal class: \{message}")
      return ([], named, 0)
    }
    // A resource limit is not a partial-surgery refusal class: it
    // propagates rather than counting toward refusal diversity.
    error => raise error
  }
  let (byte_edits, receipt) = planned
  // Claim 2: every edit CONSUMES a license derived from the request. A
  // license is spent when it is used, so a plan cannot pay for two edits
  // with one permission — the multiplicity matters as much as the spans.
  let spent : Array[Bool] = []
  for _ in licenses {
    spent.push(false)
  }
  for edit in byte_edits {
    let mut paid = false
    for index, license in licenses {
      if spent[index] {
        continue
      }
      let (from, to, exact, payload) = license
      let span_ok = if exact {
        edit.byte_start == from && edit.byte_end == to
      } else {
        edit.byte_start >= from && edit.byte_end <= to
      }
      // The payload has to match too: identical spans with swapped text
      // reproject identically while violating placement.
      let payload_ok = edit.replacement == payload
      if span_ok && payload_ok {
        spent[index] = true
        paid = true
        break
      }
    }
    assert_true(
      paid,
      msg="edit [\{edit.byte_start},\{edit.byte_end}) has no unspent license",
    )
  }
  // And no license may go UNSPENT: a permission the plan never used is
  // work the oracle predicted and the plan omitted.
  for index, license in licenses {
    let (from, to, _, _) = license
    assert_true(spent[index], msg="license [\{from},\{to}) was never spent")
  }
  let spliced_bytes = apply_run_surgery_edits(bytes, byte_edits)
  let spliced = @utf8.decode(spliced_bytes)
  // Claim 4: the edited document still reads.
  current_reader_story_text(spliced) |> ignore
  // Claim 1: the re-read projection equals the TEST's expectation, and the
  // receipt agrees with it too.
  let reprojected = surgery_native_projection(spliced)
  assert_true(batch.paragraph_index < reprojected.paragraphs.length())
  let after = StringBuilder()
  for
    contribution in reprojected.paragraphs[batch.paragraph_index].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), expected, msg="re-read projection")
  assert_eq(receipt.expected_projection, expected, msg="receipt projection")
  // Claim 3: every byte outside the declared union survives.
  assert_untouched_bytes_survive(bytes, spliced_bytes, byte_edits)
  (batch.pairs, "", receipt.touched_source_count)
}

///|
test "generated documents compose partial edits over every boundary pair" {
  let pairs : Map[String, Int] = Map([])
  let refusals : Map[String, Int] = Map([])
  let cases : Array[Array[Int]] = @quickcheck.samples(48)
  let mut planned = 0
  for case in cases {
    let source = hostile_document(case[:])
    guard hostile_native_projection(source) is Some(projection) else {
      continue
    }
    let elements = projection.scan.elements()
    for paragraph_index in 0..<projection.paragraphs.length() {
      for batch in partial_batches_for(projection, elements, paragraph_index) {
        // A FRESH projection per batch: planning mutates nothing, but a
        // shared projection would let one batch's receipt describe
        // another's document.
        let fresh = surgery_native_projection(source)
        let (planned_pairs, refusal, carriers) = assert_partial_batch(
          source, fresh, batch,
        )
        if refusal != "" {
          refusals[refusal] = refusals.get(refusal).unwrap_or(0) + 1
        } else {
          planned += 1
          for pair in planned_pairs {
            pairs[pair] = pairs.get(pair).unwrap_or(0) + 1
          }
        }
      }
    }
  }
  // The batches have to be worth testing: without these floors the suite
  // would pass just as happily on a corpus where every batch refused, or
  // where only one geometry ever planned. Measured margins are far above
  // them (see the probe recorded in the PR); a collapse fails here.
  let planned_pairs = pairs.size()
  let refusal_classes = refusals.size()
  // Measured on this corpus: 971 batches planned across 16 distinct
  // ordered pairs, with refusal classes MultiPhysicalParagraph 264,
  // AmbiguousBoundary 17, NoSynthesisCarrier 11, PartialCheckboxControl
  // 10. Floors sit under those so generator drift does not break the
  // build, while a collapse to trivial batches — or to a corpus where
  // everything refuses — fails here.
  assert_true(planned >= 300, msg="only \{planned} batches planned")
  assert_true(
    planned_pairs >= 16,
    msg="only \{planned_pairs} distinct ordered pairs planned",
  )
  assert_true(
    refusal_classes >= 3,
    msg="only \{refusal_classes} refusal classes exercised",
  )
  let seen = (pair : String) => pairs.get(pair).unwrap_or(0)
  // Ordered pairs a marginal endpoint histogram cannot distinguish: the
  // same endpoint kinds in both orders, and atoms consumed whole.
  assert_true(seen("replace:raw-interior>raw-interior") >= 40)
  assert_true(seen("insert:raw-interior>raw-interior") >= 40)
  assert_true(seen("replace:raw-edge>raw-edge") >= 50)
  assert_true(seen("insert:raw-edge>raw-edge") >= 100)
  assert_true(seen("delete:raw-edge>raw-edge") >= 20)
  assert_true(seen("replace:raw-edge>raw-interior") >= 8)
  assert_true(seen("replace:raw-interior>raw-edge") >= 5)
  assert_true(seen("replace:atom-start-edge>atom-end-edge") >= 5)
  assert_true(seen("delete:atom-start-edge>atom-end-edge") >= 3)
  assert_true(seen("insert:atom-start-edge>atom-start-edge") >= 5)
}

///|
/// The hostile GRAMMAR's alphabet does not reach the whole lexical matrix
/// — it produces no numeric character references, no CDATA, no astral
/// characters, and no atomless-run paragraph — so those boundary kinds
/// would otherwise be covered only by hand-written fixtures. This family
/// composes them locally and drives them through the SAME derivation and
/// the SAME assertions, so the lexical matrix is proved by the identical
/// oracle rather than by a weaker one.
let partial_lexical_bodies : Array[(String, String)] = [
  ("entities", "<w:p><w:r><w:t>a&amp;b&lt;c&gt;d</w:t></w:r></w:p>"),
  ("numeric-refs", "<w:p><w:r><w:t>x&#38;y&#x41;z</w:t></w:r></w:p>"),
  ("astral", "<w:p><w:r><w:t>a😀b𝄞c</w:t></w:r></w:p>"),
  ("cdata", "<w:p><w:r><w:t><![CDATA[secret]]></w:t></w:r></w:p>"),
  (
    "mixed-atoms", "<w:p><w:r><w:t>ab</w:t><w:tab/><w:noBreakHyphen/><w:t>cd</w:t></w:r></w:p>",
  ),
  ("barrier", "<w:p><w:r><w:t>ab</w:t><w:br/><w:t>cd</w:t></w:r></w:p>"),
  (
    "cr-and-ptab", "<w:p><w:r><w:t>ab</w:t><w:cr/><w:ptab/><w:t>cd</w:t></w:r></w:p>",
  ),
  ("atomless-run", "<w:p><w:r/></w:p>"),
  ("rpr-only-run", "<w:p><w:r><w:rPr><w:b/></w:rPr></w:r></w:p>"),
  ("cross-run", "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p>"),
  (
    "space-preserve", "<w:p><w:r><w:t xml:space=\"preserve\"> ab </w:t></w:r></w:p>",
  ),
  ("empty-text", "<w:p><w:r><w:t></w:t><w:t>ab</w:t></w:r></w:p>"),
  ("runless-text", "<w:p><w:r><w:t>ab</w:t></w:r><w:t>cd</w:t></w:p>"),
  // An isolated empty host: with a raw host beside it the raw edge masks
  // the empty-text class, so its insertion key never entered the census.
  ("empty-text-alone", "<w:p><w:r><w:t></w:t></w:r></w:p>"),
  // The corrected oracle branches, driven through the SAME census rather
  // than only through production-specific tests: a quoted decoy value, an
  // atom-only paragraph whose no-ops must plan nothing, and a run with a
  // non-'w:' prefix so the synthesis prefix model is exercised.
  (
    "quoted-decoy", "<w:p><w:r><w:t data='x xml:space = \"bogus\"'>ab</w:t></w:r></w:p>",
  ),
  ("atom-only", "<w:p><w:r><w:tab/><w:noBreakHyphen/></w:r></w:p>"),
  (
    "alternate-prefix", "<x:p xmlns:x=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><x:r><x:tab/><x:t>ab</x:t></x:r></x:p>",
  ),
  // The xml:space spellings a document may actually carry: single
  // quotes, and space around `=`. Without these the scanner's tolerance
  // is unpinned and could regress to the one spelling it first knew.
  (
    "space-single-quoted", "<w:p><w:r><w:t xml:space='preserve'> ab </w:t></w:r></w:p>",
  ),
  (
    "space-spaced-equals", "<w:p><w:r><w:t xml:space = \"default\">ab</w:t></w:r></w:p>",
  ),
  (
    "space-lookalike-attribute", "<w:p><w:r><w:t notxml:space='default' xmlns:notxml='urn:decoy'>ab</w:t></w:r></w:p>",
  ),
  // Isolated fixtures give only category-vs-raw pairs. This one puts an
  // entity, a numeric reference and atoms adjacent to each other so the
  // CROSS-category ordered pairs (entity>numref, numref>atom, ...) enter
  // the corpus at all.
  (
    "mixed-categories", "<w:p><w:r><w:t>&amp;&#38;</w:t><w:tab/><w:noBreakHyphen/><w:t>&#60;z</w:t></w:r></w:p>",
  ),
  // Two mixed fixtures, not one: which ordered pairs a sweep can express
  // depends on the paragraph's WIDTH (the geometries are computed from
  // it), so a single arrangement reaches some cross-category keys and
  // not others.
  // atom-start>entity needs an ATOM boundary on the left and an entity
  // edge on the right, which only this arrangement produces.
  (
    "atom-then-entity", "<w:p><w:r><w:t>&amp;</w:t><w:tab/><w:noBreakHyphen/><w:t>&amp;</w:t></w:r></w:p>",
  ),
  (
    "entity-atoms-raw", "<w:p><w:r><w:t>&amp;</w:t><w:tab/><w:noBreakHyphen/><w:t>abc</w:t></w:r></w:p>",
  ),
  // Reference-adjacent-to-raw in BOTH orders, and a numeric reference
  // beside atoms: combinations the isolated fixtures cannot express.
  ("numref-then-raw", "<w:p><w:r><w:t>&#38;abc</w:t></w:r></w:p>"),
  ("raw-then-entity", "<w:p><w:r><w:t>abc&amp;</w:t></w:r></w:p>"),
  ("raw-then-numref", "<w:p><w:r><w:t>abc&#38;</w:t></w:r></w:p>"),
  ("entity-then-raw", "<w:p><w:r><w:t>&amp;abc</w:t></w:r></w:p>"),
  (
    "atom-then-numref", "<w:p><w:r><w:t>&#38;</w:t><w:tab/><w:noBreakHyphen/><w:t>&#38;</w:t></w:r></w:p>",
  ),
  (
    "mixed-references", "<w:p><w:r><w:t>&amp;&#38;</w:t><w:tab/><w:t>&#60;&gt;</w:t><w:noBreakHyphen/><w:t>&amp;z</w:t></w:r></w:p>",
  ),
]

///|
test "the lexical matrix the grammar does not reach is proved the same way" {
  let pairs : Map[String, Int] = Map([])
  let refusals : Map[String, Int] = Map([])
  let mut planned = 0
  let mut multi_carrier = 0
  for entry in partial_lexical_bodies {
    let (label, body) = entry
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
    let projection = surgery_native_projection(source)
    let elements = projection.scan.elements()
    for paragraph_index in 0..<projection.paragraphs.length() {
      for
        batch in partial_exhaustive_batches_for(
          projection, elements, paragraph_index,
        ) {
        let fresh = surgery_native_projection(source)
        let (planned_pairs, refusal, carriers) = assert_partial_batch(
          source, fresh, batch,
        )
        if refusal != "" {
          refusals[refusal] = refusals.get(refusal).unwrap_or(0) + 1
        } else {
          planned += 1
          if batch.edits.length() > 1 && carriers > 1 {
            multi_carrier += 1
          }
          for pair in planned_pairs {
            pairs[pair] = pairs.get(pair).unwrap_or(0) + 1
          }
        }
      }
    }
    ignore(label)
  }
  let seen = (pair : String) => pairs.get(pair).unwrap_or(0)
  let refused = (name : String) => refusals.get(name).unwrap_or(0)
  // Measured at this commit: 705 batches planned over 71 ordered pairs,
  // 18 of them multi-edit across multiple carriers. The EXACT per-key
  // counts above are the real pin; this is a volume total.
  assert_true(planned == 705, msg="\{planned} lexical batches planned")
  // Entity and numeric-reference boundaries plan in BOTH orders; their
  // interiors are unresolvable and refuse below.
  // EXACT identity set, both directions. Inclusion alone would let a
  // pair vanish unnoticed if another appeared, and — worse — would stay
  // green when the planner starts ACCEPTING something it should refuse,
  // since a new key is an unexpected acceptance.
  // EXACT per-key COUNTS, both directions. Presence alone cannot see a
  // single range being refused when other ranges share its key, nor a
  // single unsafe acceptance whose key is already listed — the counts
  // move in both cases.
  for entry in partial_expected_pair_counts {
    let (key, count) = entry
    assert_eq(
      pairs.get(key).unwrap_or(0),
      count,
      msg="ordered pair count changed: " + key,
    )
  }
  for key, _ in pairs {
    let mut listed = false
    for entry in partial_expected_pair_counts {
      if entry.0 == key {
        listed = true
      }
    }
    assert_true(listed, msg="unexpected ordered pair accepted: " + key)
  }
  let lexical_pairs = pairs.size()
  assert_true(
    lexical_pairs == 71,
    msg="only \{lexical_pairs} distinct ordered pairs in the lexical family",
  )
  // BOTH orders of every mixed pair: a planner refusing only the
  // unasserted order would otherwise lose a handful of plans while every
  // floor stayed green.
  assert_true(seen("replace:entity-edge>entity-edge") >= 3)
  assert_true(seen("replace:raw-edge>entity-edge") >= 1)
  assert_true(seen("replace:entity-edge>raw-edge") >= 1)
  assert_true(seen("delete:entity-edge>raw-edge") >= 1)
  assert_true(seen("insert:entity-edge>entity-edge") >= 3)
  assert_true(seen("replace:numref-edge>numref-edge") >= 2)
  assert_true(seen("replace:raw-edge>numref-edge") >= 1)
  assert_true(seen("replace:numref-edge>raw-edge") >= 1)
  assert_true(seen("delete:numref-edge>raw-edge") >= 1)
  assert_true(seen("insert:numref-edge>numref-edge") >= 2)
  assert_true(seen("replace:raw-edge>atom-start-edge") >= 1)
  assert_true(seen("replace:atom-end-edge>raw-interior") >= 1)
  assert_true(seen("replace:raw-interior>atom-start-edge") >= 1)
  // CROSS-category pairs: isolated fixtures only ever produce
  // category-vs-raw keys, so a planner could reject entity>numref or
  // numref>atom while every other floor stayed green. The
  // mixed-categories fixture puts an entity, a numeric reference and two
  // ADJACENT atoms side by side — adjacency matters, because at a
  // coincident boundary the finer text-token class masks the atom.
  assert_true(seen("replace:entity-edge>numref-edge") >= 1)
  assert_true(seen("replace:numref-edge>entity-edge") >= 1)
  assert_true(seen("replace:entity-edge>atom-start-edge") >= 1)
  assert_true(seen("replace:numref-edge>atom-start-edge") >= 1)
  assert_true(seen("replace:atom-start-edge>numref-edge") >= 1)
  assert_true(seen("replace:atom-start-edge>entity-edge") >= 1)
  // Multi-edit batches spanning MORE THAN ONE carrier must actually
  // PLAN. Without this the suite accepts a regression that refuses every
  // general composition with InternalPlanConflict: each refusal is typed,
  // so nothing else notices.
  assert_true(
    multi_carrier >= 10,
    msg="only \{multi_carrier} multi-carrier batches planned",
  )
  // The atomless-run synthesis path plans.
  assert_true(seen("insert:bare>bare") >= 1)
  // And every refusal the lexical matrix must produce.
  assert_true(
    refused("NonScalarBoundary") >= 3,
    msg="astral halves must refuse",
  )
  assert_true(refused("CDataContext") >= 5)
  assert_true(refused("VisibleBarrier") >= 1)
  assert_true(refused("SuppressedRegion") >= 1)
  assert_true(refused("AmbiguousBoundary") >= 2)
  assert_true(refused("UnsupportedTextSource") >= 1)
}

///|
test "the source allowlist rejects a plan that widens beyond the request" {
  // The oracle's own discrimination check. Editing the first unit of
  // `a&amp;b&lt;c&gt;d` must not license rewriting the untouched later
  // `&lt;`: the projection would be unchanged and the untouched-byte walk
  // exempts whatever the plan declares, so the allowlist is the only
  // witness that can catch it.
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>a&amp;b&lt;c&gt;d</w:t></w:r></w:p></w:body></w:document>"
  let projection = surgery_native_projection(source)
  let elements = projection.scan.elements()
  let paragraph = projection.paragraphs[0]
  let requested : Array[ParagraphTextEdit] = [
    { start: 0, end: 1, replacement: "A" },
  ]
  let allowed = partial_expected_licenses(
    @utf8.encode(source)[:],
    paragraph,
    elements,
    requested,
  )
  // Locate the `&lt;` entity's bytes through the host's token map.
  let mut host : ScannedElement? = None
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) {
      let SourceElementId(identity) = contribution.source
      host = Some(elements[identity])
    }
  }
  guard host is Some(element) else { fail("expected a text host") }
  guard element.text_map is Some(map) else { fail("expected a token map") }
  let mut entity_span : (Int, Int)? = None
  for token in map.tokens {
    if token.kind is EntityRef && token.projection_start == 3 {
      entity_span = Some((token.byte_start, token.byte_end))
    }
  }
  guard entity_span is Some((from, to)) else {
    fail("expected the second entity token")
  }
  let mut licensed = false
  for span in allowed {
    let (span_from, span_to, _, _) = span
    if from >= span_from && to <= span_to {
      licensed = true
    }
  }
  assert_false(
    licensed,
    msg="the allowlist must not license an untouched later entity",
  )
  // And the requested range itself IS licensed, so the check is not
  // vacuously rejecting everything.
  guard map.byte_offset_at(0) is Some(request_from) else { fail("offset 0") }
  guard map.byte_offset_at(1) is Some(request_to) else { fail("offset 1") }
  let mut request_licensed = false
  for span in allowed {
    let (span_from, span_to, _, _) = span
    if request_from >= span_from && request_to <= span_to {
      request_licensed = true
    }
  }
  assert_true(request_licensed)
}

///|
test "the allowlist pins the half-open rule and the synthesis anchors" {
  // Two discrimination checks the property suite cannot make, because
  // both defects reproject identically and pass byte accounting.
  //
  // (1) HALF-OPEN. `<w:t>ab</w:t><w:t>cd</w:t>` with [0,1) and [2,3):
  // the second edit only ABUTS the first host, so nothing inside the
  // first host beyond its own requested range may be licensed. Under a
  // closed intersection the first host's content END would be, and a
  // widened plan could insert an empty CDATA there — well-formed,
  // identical projection, and it poisons that host's token map forever.
  let abutting = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p></w:body></w:document>"
  let projection = surgery_native_projection(abutting)
  let elements = projection.scan.elements()
  let paragraph = projection.paragraphs[0]
  let allowed = partial_expected_licenses(
    @utf8.encode(abutting)[:],
    paragraph,
    elements,
    [
      ({ start: 0, end: 1, replacement: "A" } : ParagraphTextEdit),
      { start: 2, end: 3, replacement: "C" },
    ],
  )
  let mut first_host : ScannedElement? = None
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) && first_host is None {
      let SourceElementId(identity) = contribution.source
      first_host = Some(elements[identity])
    }
  }
  guard first_host is Some(host) else { fail("expected a first text host") }
  let mut licensed_tail = false
  for span in allowed {
    let (from, to, _, _) = span
    if host.content_end >= from &&
      host.content_end <= to &&
      from >= host.content_start {
      licensed_tail = true
    }
  }
  assert_false(
    licensed_tail,
    msg="an abutting edit must not license the neighbour's content end",
  )
  // (2) SYNTHESIS ANCHORS. A paragraph that projects text needs no run
  // anchor at all. The run carries an `rPr` so its post-rPr anchor sits
  // OUTSIDE every `w:t` open tag — otherwise the touched host's open-tag
  // span would already license that coordinate and the check would pass
  // whether or not the anchor rule held.
  let simple = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:rPr><w:b/></w:rPr><w:tab/><w:t>ab</w:t></w:r></w:p></w:body></w:document>"
  let simple_projection = surgery_native_projection(simple)
  let simple_elements = simple_projection.scan.elements()
  let simple_paragraph = simple_projection.paragraphs[0]
  // Edit only inside the text, leaving the tab untouched.
  let simple_allowed = partial_expected_licenses(
    @utf8.encode(simple)[:],
    simple_paragraph,
    simple_elements,
    [({ start: 1, end: 2, replacement: "A" } : ParagraphTextEdit)],
  )
  let SourceElementId(run_identity) = simple_paragraph.runs[0].source
  let run_element = simple_elements[run_identity]
  // The post-rPr anchor coordinate itself.
  let mut anchor = run_element.content_start
  let mut child = run_element.first_child_index
  while child >= 0 {
    let candidate = simple_elements[child]
    if is_wml_uri(candidate.uri) && candidate.local_name == "rPr" {
      anchor = candidate.byte_end
    }
    child = candidate.next_sibling_index
  }
  assert_true(anchor > run_element.content_start)
  let mut licensed_anchor = false
  for span in simple_allowed {
    let (from, to, _, _) = span
    if anchor >= from && anchor <= to {
      licensed_anchor = true
    }
  }
  assert_false(
    licensed_anchor,
    msg="a text-projecting paragraph must license no run synthesis anchor",
  )
  // And the run's content end is never a synthesis location either.
  let mut licensed_end = false
  for span in simple_allowed {
    let (from, to, _, _) = span
    if run_element.content_end >= from &&
      run_element.content_end <= to &&
      from > run_element.content_start {
      licensed_end = true
    }
  }
  assert_false(licensed_end, msg="run content end is never a synthesis site")
}

///|
test "partial: a multi-edit batch across two runs plans" {
  // The general composition shape the property floors now require and
  // this test pins exactly: two edits, two carriers, two runs.
  assert_partial_edits(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 2, "head"), partial_edit(2, 4, "")],
    expected="head",
  )
  // And across two hosts inside ONE run.
  assert_partial_edits(
    "<w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "A"), partial_edit(2, 3, "C")],
    expected="AbCd",
  )
}

///|
/// Every ordered (shape, start-kind, end-kind) key the lexical family
/// plans. The family enumerates EXHAUSTIVELY — every (i, j) range over
/// every fixture — so this is the permitted set over those bodies, not a
/// sample of it, and it is held as an identity set: a planner that starts
/// refusing any single pair fails with that pair's key.
let partial_expected_pair_counts : Array[(String, Int)] = [
  ("insert:bare>bare", 1),
  ("delete:raw-edge>raw-edge", 18),
  ("insert:raw-edge>raw-edge", 56),
  ("insert:seam-edge>seam-edge", 1),
  ("replace:raw-edge>raw-edge", 18),
  ("delete:raw-edge>entity-edge", 8),
  ("delete:raw-edge>numref-edge", 6),
  ("delete:entity-edge>raw-edge", 18),
  ("delete:numref-edge>raw-edge", 11),
  ("insert:empty-text>empty-text", 1),
  ("replace:raw-edge>entity-edge", 9),
  ("replace:raw-edge>numref-edge", 7),
  ("delete:atom-end-edge>raw-edge", 3),
  ("delete:raw-edge>atom-end-edge", 1),
  ("delete:raw-edge>raw-interior", 28),
  ("delete:raw-interior>raw-edge", 31),
  ("replace:entity-edge>raw-edge", 18),
  ("replace:numref-edge>raw-edge", 11),
  ("delete:numref-edge>entity-edge", 8),
  ("replace:atom-end-edge>raw-edge", 3),
  ("replace:raw-edge>atom-end-edge", 1),
  ("replace:raw-edge>raw-interior", 39),
  ("replace:raw-interior>raw-edge", 32),
  ("delete:atom-start-edge>raw-edge", 5),
  ("delete:entity-edge>entity-edge", 40),
  ("delete:entity-edge>numref-edge", 10),
  ("delete:entity-edge>raw-interior", 8),
  ("delete:numref-edge>numref-edge", 18),
  ("delete:numref-edge>raw-interior", 4),
  ("delete:raw-edge>atom-start-edge", 2),
  ("delete:raw-interior>entity-edge", 4),
  ("delete:raw-interior>numref-edge", 4),
  ("insert:entity-edge>entity-edge", 26),
  ("insert:numref-edge>numref-edge", 15),
  ("replace:numref-edge>entity-edge", 8),
  ("delete:entity-edge>atom-end-edge", 2),
  ("replace:atom-start-edge>raw-edge", 5),
  ("replace:entity-edge>entity-edge", 49),
  ("replace:entity-edge>numref-edge", 11),
  ("replace:numref-edge>numref-edge", 24),
  ("replace:numref-edge>raw-interior", 5),
  ("replace:raw-edge>atom-start-edge", 2),
  ("replace:raw-interior>entity-edge", 6),
  ("replace:raw-interior>numref-edge", 6),
  ("delete:atom-end-edge>raw-interior", 4),
  ("delete:raw-interior>atom-end-edge", 1),
  ("delete:raw-interior>raw-interior", 19),
  ("insert:raw-interior>raw-interior", 34),
  ("replace:entity-edge>atom-end-edge", 2),
  ("replace:entity-edge>raw-interior", 10),
  ("delete:atom-start-edge>entity-edge", 2),
  ("delete:atom-start-edge>numref-edge", 4),
  ("delete:entity-edge>atom-start-edge", 6),
  ("delete:numref-edge>atom-start-edge", 3),
  ("insert:atom-end-edge>atom-end-edge", 1),
  ("replace:atom-end-edge>raw-interior", 5),
  ("replace:raw-interior>atom-end-edge", 1),
  ("replace:raw-interior>raw-interior", 28),
  ("delete:atom-start-edge>raw-interior", 5),
  ("delete:raw-interior>atom-start-edge", 2),
  ("replace:atom-start-edge>entity-edge", 3),
  ("replace:atom-start-edge>numref-edge", 5),
  ("replace:entity-edge>atom-start-edge", 6),
  ("replace:numref-edge>atom-start-edge", 4),
  ("delete:atom-start-edge>atom-end-edge", 6),
  ("replace:atom-start-edge>raw-interior", 5),
  ("replace:raw-interior>atom-start-edge", 2),
  ("replace:atom-start-edge>atom-end-edge", 8),
  ("delete:atom-start-edge>atom-start-edge", 2),
  ("insert:atom-start-edge>atom-start-edge", 3),
  ("replace:atom-start-edge>atom-start-edge", 3),
]

///|
test "payload licenses are exercised by escaping and whitespace" {
  // The composition corpus replaces with alphanumerics only, so the
  // escaper's markup branches and the xml:space licenses would never be
  // exercised by it — a payload prediction nothing tests is not a proof.
  // These batches drive the SAME oracle with replacements that force
  // escaping, carriage returns, and preservation on and off, including
  // over hosts whose declaration uses each spelling the scanner must
  // tolerate.
  let bodies : Array[(String, Array[ParagraphTextEdit])] = [
    (
      "<w:p><w:r><w:t>abc</w:t></w:r></w:p>",
      [{ start: 1, end: 2, replacement: "&<>" }],
    ),
    (
      "<w:p><w:r><w:t>abc</w:t></w:r></w:p>",
      [{ start: 0, end: 3, replacement: "x\ry" }],
    ),
    (
      "<w:p><w:r><w:t>abc</w:t></w:r></w:p>",
      [{ start: 0, end: 1, replacement: " lead" }],
    ),
    (
      "<w:p><w:r><w:t>abc</w:t></w:r></w:p>",
      [{ start: 2, end: 3, replacement: "trail " }],
    ),
    (
      "<w:p><w:r><w:t xml:space='preserve'> ab </w:t></w:r></w:p>",
      [{ start: 1, end: 2, replacement: "&" }],
    ),
    (
      "<w:p><w:r><w:t xml:space = \"default\">ab</w:t></w:r></w:p>",
      [{ start: 0, end: 1, replacement: " s" }],
    ),
    (
      "<w:p><w:r><w:t notxml:space='default' xmlns:notxml='urn:decoy'>ab</w:t></w:r></w:p>",
      [{ start: 0, end: 1, replacement: " s" }],
    ),
    (
      "<w:p><w:r><w:tab/><w:t>ab</w:t></w:r></w:p>",
      [{ start: 0, end: 1, replacement: "&x" }],
    ),
    ("<w:p><w:r/></w:p>", [{ start: 0, end: 0, replacement: " &z " }]),
  ]
  for entry in bodies {
    let (body, edits) = entry
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
    let projection = surgery_native_projection(source)
    let elements = projection.scan.elements()
    let pairs : Array[String] = []
    for edit in edits {
      let start_class = partial_primary_class(
        partial_offset_classes(projection.paragraphs[0], elements, edit.start),
      )
      let end_class = partial_primary_class(
        partial_offset_classes(projection.paragraphs[0], elements, edit.end),
      )
      pairs.push("escape:\{start_class}>\{end_class}")
    }
    let batch : PartialBatchPlan = { paragraph_index: 0, edits, pairs }
    let fresh = surgery_native_projection(source)
    let (_, refusal, _) = assert_partial_batch(source, fresh, batch)
    assert_eq(refusal, "", msg="escaping batch refused for \{body}")
  }
}
