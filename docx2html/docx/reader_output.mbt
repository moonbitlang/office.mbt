// The joined production bundle (#434 PR 6a): ONE authoritative joined
// read of a story part, segmented the way production consumes it. The
// document body is one segment; a header or footer root's children are
// one segment; each accepted note or comment container is its own, so
// pending content can never leak across containers while coordinates
// stay continuous across the whole part. The same segment items feed
// both the erased AST and the mutation projection -- the reader must
// not run twice over one story.

///|
priv struct ReaderOutputSegment {
  container : ReaderNode
  items : Array[ReaderItem]
}

///|
priv struct JoinedReaderOutput {
  story : JoinedReaderStory
  segments : Array[ReaderOutputSegment]
}

///|
/// Why a joined story could not be segmented for mutation-safe
/// consumption. Production READING narrows silently -- an unexpected
/// container simply never surfaces -- but a mutation-safe view must not
/// silently lose story content, so every structural surprise refuses.
priv enum ReaderSegmentationRefusal {
  UnexpectedStoryRoot(name~ : String)
  MissingDocumentBody
  UnexpectedContainer(root~ : String, name~ : String)
}

///|
priv enum ReaderSegmentationResult {
  SegmentedStory(JoinedReaderOutput)
  SegmentationRefused(ReaderSegmentationRefusal)
}

///|
/// A bounded human-readable form for tests and diagnostics.
fn ReaderSegmentationRefusal::describe(
  self : ReaderSegmentationRefusal,
) -> String {
  match self {
    UnexpectedStoryRoot(name~) => "unexpected story root " + name
    MissingDocumentBody => "the document story has no body"
    UnexpectedContainer(root~, name~) =>
      "unexpected direct child " + name + " of " + root
  }
}

///|
/// Refusal diagnostics never carry unbounded input: an expanded XML name
/// is clipped to at most 64 UTF-16 units before it is stored in a
/// refusal, so a hostile namespace URI cannot ride a describe() into
/// logs or messages.
const READER_SEGMENTATION_NAME_LIMIT = 64

///|
fn reader_segmentation_clip_name(name : String) -> String {
  if name.length() <= READER_SEGMENTATION_NAME_LIMIT {
    return name
  }
  let output = StringBuilder()
  let mut units = 0
  for character in name {
    // the cap is UTF-16 units, the length() currency: a non-BMP
    // character spends two
    let width = if character.to_int() > 0xFFFF { 2 } else { 1 }
    if units + width > READER_SEGMENTATION_NAME_LIMIT - 1 {
      break
    }
    output.write_char(character)
    units += width
  }
  output.write_string("\u{2026}")
  output.to_string()
}

///|
/// Word's plumbing notes -- separator rules and continuation notices --
/// which production note reading skips rather than surfacing as content.
/// Comments carry no such convention: production reads every comment
/// whatever its attributes say.
fn reader_note_container_is_plumbing(container : ReaderNode) -> Bool {
  match container.attribute("w:type") {
    Some("separator")
    | Some("continuationSeparator")
    | Some("continuationNotice") => true
    _ => false
  }
}

///|
/// Segments one joined story and performs the one authoritative read of
/// each segment's children, mirroring production consumption exactly:
/// the document's body (a `w:background` sibling is presentation, not
/// story content, and is not read), a header or footer root's own
/// children, and each name-matching note or comment container. Container
/// elements themselves are never read. Where production reading would
/// silently drop content -- a foreign direct child of the document or of
/// a notes or comments root, a second body, a bodyless document, an
/// unknown root -- segmentation refuses instead: a mutation-safe view
/// must not quietly narrow the story.
fn segment_joined_reader_story(
  story : JoinedReaderStory,
  reader : BodyReader,
) -> ReaderSegmentationResult raise DocxError {
  let root = story.root
  let segments : Array[ReaderOutputSegment] = []
  fn container_segments(
    container_name : String,
  ) -> ReaderSegmentationRefusal? raise DocxError {
    let filter_plumbing = container_name != "w:comment"
    for container in root.element_children() {
      if container.name() != container_name {
        return Some(
          UnexpectedContainer(
            root=root.name(),
            name=reader_segmentation_clip_name(container.name()),
          ),
        )
      }
      if filter_plumbing && reader_note_container_is_plumbing(container) {
        continue
      }
      segments.push({
        container,
        items: reader.read_children(container.element_children()),
      })
    }
    None
  }

  match root.name() {
    "w:document" => {
      // the document child model is w:background then w:body; anything
      // else -- a foreign child, a second body -- refuses rather than
      // silently vanishing from the mutation-safe view
      let mut body : ReaderNode? = None
      let mut background_seen = false
      for child in root.element_children() {
        match child.name() {
          "w:background" =>
            // the schema sequence is AT MOST ONE background, BEFORE the
            // body; a duplicate or trailing background is invalid
            // structure that must not silently vanish
            if background_seen || body is Some(_) {
              return SegmentationRefused(
                UnexpectedContainer(root="w:document", name="w:background"),
              )
            } else {
              background_seen = true
            }
          "w:body" =>
            match body {
              None => body = Some(child)
              Some(_) =>
                return SegmentationRefused(
                  UnexpectedContainer(root="w:document", name="w:body"),
                )
            }
          name =>
            return SegmentationRefused(
              UnexpectedContainer(
                root="w:document",
                name=reader_segmentation_clip_name(name),
              ),
            )
        }
      }
      match body {
        Some(body) =>
          segments.push({
            container: body,
            items: reader.read_children(body.element_children()),
          })
        None => return SegmentationRefused(MissingDocumentBody)
      }
    }
    "w:hdr" | "w:ftr" =>
      segments.push({
        container: root,
        items: reader.read_children(root.element_children()),
      })
    "w:footnotes" =>
      match container_segments("w:footnote") {
        Some(refusal) => return SegmentationRefused(refusal)
        None => ()
      }
    "w:endnotes" =>
      match container_segments("w:endnote") {
        Some(refusal) => return SegmentationRefused(refusal)
        None => ()
      }
    "w:comments" =>
      match container_segments("w:comment") {
        Some(refusal) => return SegmentationRefused(refusal)
        None => ()
      }
    name =>
      return SegmentationRefused(
        UnexpectedStoryRoot(name=reader_segmentation_clip_name(name)),
      )
  }
  SegmentedStory({ story, segments, })
}

///|
/// Projects a joined bundle: every segment walks through ONE shared
/// builder with a segment boundary between, so paragraph coordinates and
/// carrier events stay part-wide continuous while ownership stays
/// segment-local.
fn project_joined_reader_output(
  output : JoinedReaderOutput,
  budget? : ReaderProjectionBudget,
) -> ReaderProjectionBuildResult raise DocxError {
  let segments : Array[Array[ReaderItem]] = []
  for segment in output.segments {
    segments.push(segment.items)
  }
  project_reader_item_segments(output.story.scan, segments, budget?)
}

///|
/// Which reader semantics a `DocumentParts` uses for story parts.
/// Ordinary and tolerant-annotated reading keep the tolerant unjoined
/// path; mutation-safe and joined read-only annotated reads go joined -- and
/// once joined there is no fallback: a join, segmentation or projection
/// failure refuses the whole read.
priv enum StoryReaderMode {
  TolerantReader
  JoinedMutationReader
}

///|
/// One joined story read: the bundle whose segments carry the ONE
/// authoritative read, and its classified projection.
priv struct JoinedStoryRead {
  output : JoinedReaderOutput
  projection : ReaderProjection
}

///|
/// Maps a join refusal out of the no-fallback pipeline: stage causes
/// keep their type (a resource ceiling stays a resource ceiling, bad
/// XML stays bad XML), while the join's own findings become typed
/// Unsupported with bounded diagnostics.
fn reader_join_refusal_error(
  part : String,
  refusal : ReaderInputJoinRefusal,
) -> DocxError {
  match refusal {
    StageRefused(stage=_, cause~) =>
      match cause {
        InvalidXml(message~) =>
          InvalidXml(
            message="mutation-safe story read of '\{part}': \{message}",
          )
        Unsupported(message~) =>
          Unsupported(
            message="mutation-safe story read of '\{part}': \{message}",
          )
        other => other
      }
    other =>
      Unsupported(
        message="mutation-safe reader join refused for '\{part}': \{other.describe()}",
      )
  }
}

///|
/// The one authoritative mutation-safe read of a story part from its
/// bytes: strict gate, scan, tolerant parse, join, segmentation,
/// projection, field classification. Every failure is a typed refusal.
fn read_joined_story_bytes(
  part : String,
  bytes : BytesView,
  reader : BodyReader,
  strict_budget? : @xml.XmlReadBudget,
  tolerant_budget? : @xml.XmlReadBudget,
  path_budget? : AnnotationPathBudget,
) -> JoinedStoryRead raise DocxError {
  match
    join_reader_input_story_limited(
      bytes,
      strict_budget?,
      tolerant_budget?,
      path_budget?,
    ) {
    Refused(refusal) => raise reader_join_refusal_error(part, refusal)
    Joined(story) => finish_joined_story_read(part, story, reader)
  }
}

///|
/// The main-document form: the tolerant DOM is already parsed and the
/// strict gate already ran beside it, so only the scan and the join are
/// added -- nothing parses twice and budget accounting is unchanged.
fn read_joined_story_prepared(
  part : String,
  bytes : BytesView,
  root : XmlElement,
  reader : BodyReader,
  path_budget? : AnnotationPathBudget,
) -> JoinedStoryRead raise DocxError {
  let scan = scan_projection_source_tree(bytes, path_budget?) catch {
    cause =>
      raise reader_join_refusal_error(
        part,
        StageRefused(stage=SourceScan, cause~),
      )
  }
  match join_reader_dom(root, scan) {
    Refused(refusal) => raise reader_join_refusal_error(part, refusal)
    Joined(story) => finish_joined_story_read(part, story, reader)
  }
}

///|
fn finish_joined_story_read(
  part : String,
  story : JoinedReaderStory,
  reader : BodyReader,
) -> JoinedStoryRead raise DocxError {
  match segment_joined_reader_story(story, reader) {
    SegmentationRefused(refusal) =>
      raise Unsupported(
        message="mutation-safe segmentation refused for '\{part}': \{refusal.describe()}",
      )
    SegmentedStory(output) =>
      match project_joined_reader_output(output) {
        ProjectionRefused(refusal) =>
          raise Unsupported(
            message="mutation-safe reader projection refused for '\{part}': \{refusal.describe()}",
          )
        Projected(projection) => {
          classify_reader_projection_fields(projection)
          { output, projection, }
        }
      }
  }
}
