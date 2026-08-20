///|
/// #462 phase C1b: the adoption prerequisites for making the annotation
/// index consume retained reader-projection scans (C1c). Two oracles:
///
/// 1. A saturation witness for the warning-replay argument: replaying an
///    adopted scan's warnings through the index's shared collector is
///    lossless only if the per-scan collector (64 messages) can never
///    saturate. Source mode hard-refuses every malformed-balance condition,
///    leaving exactly SEVEN nonfatal warning shapes — five marker kinds
///    missing `w:id` and two revision kinds missing `w:author`. (The
///    scanner's eighth warning, `a vMerge outside any table cell`, is
///    structurally unreachable: emitting it requires a first `w:tcPr`
///    whose direct parent is a `w:tc`, and `nearest_frame_by_kind` matches
///    that very structural `tc` frame even when suppression cleared its
///    projection kind.) Widening the scanner's warning vocabulary must
///    re-establish this argument.
///
/// 2. A mode-parity oracle: after C1a's precedence unification, an
///    annotation-mode scan and a source-retaining scan of the same bytes
///    must agree on every public-relevant output — nodes, markers,
///    revisions, revision sites, root namespace, and warnings — so scan
///    adoption can never change what the index reports.
const SEVEN_WARNING_SOURCE : String =
  #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:commentRangeStart/><w:r><w:commentReference/></w:r><w:r><w:footnoteReference/></w:r><w:r><w:endnoteReference/></w:r><w:commentRangeEnd/><w:ins><w:r><w:t>x</w:t></w:r></w:ins><w:del><w:r><w:delText>y</w:delText></w:r></w:del></w:p></w:body></w:document>

///|
test "source-mode nonfatal warning vocabulary never saturates its collector" {
  let scan = scan_projection_source_tree(@utf8.encode(SEVEN_WARNING_SOURCE))
  debug_inspect(
    scan.warnings(),
    content=(
      #|[
      #|  "annotation scanner: a commentRangeStart marker has no w:id attribute",
      #|  "annotation scanner: a commentReference marker has no w:id attribute",
      #|  "annotation scanner: a footnoteReference marker has no w:id attribute",
      #|  "annotation scanner: a endnoteReference marker has no w:id attribute",
      #|  "annotation scanner: a commentRangeEnd marker has no w:id attribute",
      #|  "annotation scanner: a w:ins revision has no w:author attribute",
      #|  "annotation scanner: a w:del revision has no w:author attribute",
      #|]
    ),
  )
}

///|
test "replaying adopted scan warnings preserves collector semantics" {
  let scan = scan_projection_source_tree(@utf8.encode(SEVEN_WARNING_SOURCE))
  let collector = AnnotationWarningCollector::new(16, 512)
  collector.add(
    "annotation scanner: a w:ins revision has no w:author attribute",
  )
  collector.replay_scan_warnings(scan)
  collector.replay_scan_warnings(scan)
  // Dedupe holds across a pre-existing message and a double replay.
  assert_eq(collector.finish().length(), 7)
}

///|
fn assert_scan_modes_agree(label : String, source : String) -> Unit raise {
  assert_scans_agree(
    label,
    scan_story(@utf8.encode(source)),
    scan_projection_source_tree(@utf8.encode(source)),
  )
}

///|
fn assert_scans_agree(
  label : String,
  annotation : StoryScan,
  retained : StoryScan,
) -> Unit raise {
  assert_eq(annotation.root_namespace_uri(), retained.root_namespace_uri())
  assert_eq(annotation.warnings(), retained.warnings())
  let annotation_nodes = annotation.nodes()
  let retained_nodes = retained.nodes()
  assert_eq(annotation_nodes.length(), retained_nodes.length())
  for index in 0..<annotation_nodes.length() {
    let a = annotation_nodes[index]
    let r = retained_nodes[index]
    assert_eq(
      (
        a.path,
        a.kind,
        a.byte_start,
        a.byte_end,
        a.content_start,
        a.close_tag_start,
      ),
      (
        r.path,
        r.kind,
        r.byte_start,
        r.byte_end,
        r.content_start,
        r.close_tag_start,
      ),
      msg="\{label}: node \{index}",
    )
    assert_eq(
      (a.open_order, a.open_seq, a.close_seq),
      (r.open_order, r.open_seq, r.close_seq),
      msg="\{label}: node sequence \{index}",
    )
  }
  let annotation_markers = annotation.markers()
  let retained_markers = retained.markers()
  assert_eq(annotation_markers.length(), retained_markers.length())
  for index in 0..<annotation_markers.length() {
    let a = annotation_markers[index]
    let r = retained_markers[index]
    assert_eq(
      (
        "\{a.kind}",
        a.id,
        a.id_was_present,
        a.seq,
        a.container_path,
        a.after_child,
      ),
      (
        "\{r.kind}",
        r.id,
        r.id_was_present,
        r.seq,
        r.container_path,
        r.after_child,
      ),
      msg="\{label}: marker \{index}",
    )
  }
  let annotation_revisions = annotation.revisions()
  let retained_revisions = retained.revisions()
  assert_eq(annotation_revisions.length(), retained_revisions.length())
  for index in 0..<annotation_revisions.length() {
    let a = annotation_revisions[index]
    let r = retained_revisions[index]
    assert_eq(
      ("\{a.kind}", a.id, a.author, a.date, a.container_path),
      ("\{r.kind}", r.id, r.author, r.date, r.container_path),
      msg="\{label}: revision \{index}",
    )
  }
  let annotation_sites = annotation.revision_sites()
  let retained_sites = retained.revision_sites()
  assert_eq(annotation_sites.length(), retained_sites.length())
  for index in 0..<annotation_sites.length() {
    let a = annotation_sites[index]
    let r = retained_sites[index]
    assert_eq(
      (a.local_name, a.supported, a.id, a.author, a.date, a.container_path),
      (r.local_name, r.supported, r.id, r.author, r.date, r.container_path),
      msg="\{label}: revision site \{index}",
    )
    assert_eq(
      (a.byte_start, a.content_start, a.close_tag_start, a.byte_end),
      (r.byte_start, r.content_start, r.close_tag_start, r.byte_end),
      msg="\{label}: revision site span \{index}",
    )
    assert_eq(
      a.declares_namespaces,
      r.declares_namespaces,
      msg="\{label}: revision site namespace flag \{index}",
    )
    assert_eq(
      a.name_edits.length(),
      r.name_edits.length(),
      msg="\{label}: revision site name edits \{index}",
    )
    for edit_index in 0..<a.name_edits.length() {
      let ae = a.name_edits[edit_index]
      let re = r.name_edits[edit_index]
      assert_eq(
        (
          ae.open_start,
          ae.open_end,
          ae.close_start,
          ae.close_end,
          ae.replacement,
        ),
        (
          re.open_start,
          re.open_end,
          re.close_start,
          re.close_end,
          re.replacement,
        ),
        msg="\{label}: revision site \{index} name edit \{edit_index}",
      )
    }
  }
  match (annotation.root(), retained.root()) {
    (Some(a), Some(r)) =>
      assert_eq(
        (
          a.path,
          a.kind,
          a.byte_start,
          a.byte_end,
          a.content_start,
          a.close_tag_start,
        ),
        (
          r.path,
          r.kind,
          r.byte_start,
          r.byte_end,
          r.content_start,
          r.close_tag_start,
        ),
        msg="\{label}: root",
      )
    (None, None) => ()
    _ => fail("\{label}: root presence differs between scan modes")
  }
  let annotation_positions = annotation.story_level_positions
  let retained_positions = retained.story_level_positions
  assert_eq(
    annotation_positions.length(),
    retained_positions.length(),
    msg="\{label}: story-level position count",
  )
  for seq, position in annotation_positions {
    match retained_positions.get(seq) {
      Some(other) =>
        assert_eq(
          (position.path, position.node_is_after),
          (other.path, other.node_is_after),
          msg="\{label}: story-level position \{seq}",
        )
      None =>
        fail("\{label}: story-level position \{seq} missing in source mode")
    }
  }
}

///|
test "annotation and source scans agree on every public projection" {
  assert_scan_modes_agree("warnings", SEVEN_WARNING_SOURCE)
  assert_scan_modes_agree(
    "table",
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/><w:gridSpan w:val="2"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge w:val="continue"/></w:tcPr><w:p/></w:tc><w:tc><w:p><w:commentRangeStart w:id="7"/><w:r><w:t>B</w:t></w:r><w:commentRangeEnd w:id="7"/></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
    ),
  )
  assert_scan_modes_agree(
    "containers",
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><w:body><w:sdt><w:sdtContent><w:p><w:hyperlink><w:r><w:t>link</w:t></w:r></w:hyperlink><w:ins w:id="1" w:author="Ada" w:date="2001-01-01T00:00:00Z"><w:r><w:t>new</w:t></w:r></w:ins></w:p></w:sdtContent></w:sdt><mc:AlternateContent><mc:Choice><w:p><w:r><w:t>hidden</w:t></w:r></w:p></mc:Choice><mc:Fallback><w:p><w:r><w:t>shown</w:t></w:r></w:p></mc:Fallback></mc:AlternateContent><w:p><w:del w:id="2" w:author="Bob"><w:r><w:delText>old</w:delText></w:r></w:del></w:p></w:body></w:document>
    ),
  )
  assert_scan_modes_agree(
    "story-level markers",
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:commentRangeStart w:id="3"/><w:p><w:r><w:t>a</w:t></w:r></w:p><w:commentRangeEnd w:id="3"/><w:p><w:r><w:commentReference w:id="3"/></w:r></w:p></w:body></w:document>
    ),
  )
  assert_scan_modes_agree(
    "namespace-declaring revision with name edits",
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:del w:id="9" w:author="Eve" xmlns:x="urn:extra"><w:r><w:delText>gone</w:delText><w:delInstrText>PAGE</w:delInstrText></w:r></w:del></w:p></w:body></w:document>
    ),
  )
  assert_scan_modes_agree(
    "mixed-prefix duplicate",
    (
      #|<root xmlns:t="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:s="http://purl.oclc.org/ooxml/wordprocessingml/main"><t:commentRangeStart t:id="first" s:id="last"/></root>
    ),
  )
}
