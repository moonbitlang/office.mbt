// The joined production bundle (#434 PR 6a): ONE authoritative joined
// read of a story part, segmented the way production consumes it. The
// main body is one segment; each accepted note or comment container is
// its own, so pending content can never leak across containers while
// coordinates stay continuous across the whole part. The same segment
// items feed both the erased AST and the mutation projection -- the
// reader must not run twice over one story.

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
/// Word's plumbing notes -- separator rules and continuation notices --
/// which production note reading skips rather than surfacing as content.
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
/// each segment's children. Container elements themselves are never read:
/// the body (or bare root) contributes its children as one segment, and
/// every non-plumbing direct child of a notes or comments root becomes a
/// segment of its own. Note that segmentation does NOT name-filter the
/// containers: a foreign direct child still projects, so its content
/// stays visible to ownership checks instead of silently vanishing from
/// the mutation-safe view.
fn segment_joined_reader_story(
  source_part : String,
  story : JoinedReaderStory,
  reader : BodyReader,
) -> JoinedReaderOutput raise DocxError {
  let root = story.root
  let segments : Array[ReaderOutputSegment] = []
  match root.name() {
    "w:footnotes" | "w:endnotes" | "w:comments" =>
      for container in root.element_children() {
        if reader_note_container_is_plumbing(container) {
          continue
        }
        segments.push({
          container,
          items: reader.read_children(container.element_children()),
        })
      }
    _ => {
      let container = match root.first("w:body") {
        Some(body) => body
        None => root
      }
      segments.push({
        container,
        items: reader.read_children(container.element_children()),
      })
    }
  }
  { source_part, story, segments }
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
