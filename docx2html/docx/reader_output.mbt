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
  source_part : String
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
} derive(Debug, Eq)

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
/// the document's FIRST body (other direct document children, like a
/// `w:background`, are not story content and are not read), a header or
/// footer root's own children, and each name-matching note or comment
/// container. Container elements themselves are never read. Where
/// production reading would silently drop a container -- a foreign
/// direct child of a notes or comments root, a bodyless document, an
/// unknown root -- segmentation refuses instead: a mutation-safe view
/// must not quietly narrow the story.
fn segment_joined_reader_story(
  source_part : String,
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
          UnexpectedContainer(root=root.name(), name=container.name()),
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
    "w:document" =>
      match root.first("w:body") {
        Some(body) =>
          segments.push({
            container: body,
            items: reader.read_children(body.element_children()),
          })
        None => return SegmentationRefused(MissingDocumentBody)
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
    name => return SegmentationRefused(UnexpectedStoryRoot(name~))
  }
  SegmentedStory({ source_part, story, segments })
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
  project_reader_item_segments(
    output.source_part,
    output.story.scan,
    segments,
    budget?,
  )
}
