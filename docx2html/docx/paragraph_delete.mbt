// `office delete-paragraph` — the N3b planner, insertion's structural
// inverse. Exactly one DIRECT body paragraph leaves the story as a
// byte-exact splice; everything the deletion could dangle — notes,
// comments, bookmarks, split fields, revisions, media, a section
// break, the document-final paragraph — refuses instead. Nothing else
// in the package changes by a byte.

///|
/// What one planned deletion will do: the path that stops resolving,
/// the identity that leaves with it, the text it carried (the reader
/// projection, for the caller's own guard), and the successor's
/// identity — the paragraph that will answer at the deleted path after
/// publication, when one exists.
pub struct DocxDeleteReceipt {
  priv path : String
  priv para_id : String?
  priv anchor_status : String
  priv text : String
  priv successor_para_id : String?
}

///|
pub fn DocxDeleteReceipt::path(self : DocxDeleteReceipt) -> String {
  self.path
}

///|
/// The deleted paragraph's canonical w14:paraId, when it uniquely
/// carried one.
pub fn DocxDeleteReceipt::para_id(self : DocxDeleteReceipt) -> String? {
  self.para_id
}

///|
pub fn DocxDeleteReceipt::anchor_status(self : DocxDeleteReceipt) -> String {
  self.anchor_status
}

///|
/// The deleted paragraph's reader projection — what an agent verifies
/// against before trusting an ordinal address.
pub fn DocxDeleteReceipt::text(self : DocxDeleteReceipt) -> String {
  self.text
}

///|
/// The unique identity of the paragraph that will answer at the
/// deleted path after publication, when the successor carries one.
pub fn DocxDeleteReceipt::successor_para_id(
  self : DocxDeleteReceipt,
) -> String? {
  self.successor_para_id
}

///|
/// The subtree constructs a v1 deletion refuses, each because the
/// delete would dangle or destroy document state OUTSIDE the paragraph:
/// note references orphan definitions; comment machinery orphans
/// definitions or unbalances ranges; bookmark markers unbalance ranges
/// or dangle REF fields (the wholly-internal `_GoBack` cursor artifact
/// alone is exempt — Word plants it everywhere and deletes it freely,
/// and nothing targets it); `fldChar` pairs are document-order-global
/// (`fldSimple` is self-contained and permitted); revision content is
/// history this verb must not silently discard; drawings and objects
/// need relationship and media surgery. `sectPr` is section layout for
/// the whole preceding range.
fn delete_blocked_construct(local_name : String) -> String? {
  match local_name {
    "sectPr" => Some("a section break (w:sectPr)")
    "footnoteReference" => Some("a footnote reference")
    "endnoteReference" => Some("an endnote reference")
    "commentReference" | "commentRangeStart" | "commentRangeEnd" =>
      Some("comment machinery")
    "fldChar" => Some("a split field boundary (w:fldChar)")
    "ins"
    | "del"
    | "moveFrom"
    | "moveTo"
    | "moveFromRangeStart"
    | "moveFromRangeEnd"
    | "moveToRangeStart"
    | "moveToRangeEnd"
    | "rPrChange"
    | "pPrChange"
    | "sectPrChange"
    | "tblPrChange"
    | "trPrChange"
    | "tcPrChange"
    | "numberingChange"
    | "cellIns"
    | "cellDel" => Some("tracked-revision content")
    "drawing" | "object" | "pict" => Some("a drawing or embedded object")
    _ => None
  }
}

///|
/// Plan one paragraph deletion at a DIRECT body paragraph.
///
/// `at` is the direct body ordinal path ("p[3]") — the same anchor
/// grammar insertion uses, proven a physical child of w:body on the
/// element tree (the path grammar flattens wrappers, so the path alone
/// proves nothing). The returned plan splices ONLY the deletion; the
/// receipt names what leaves and who answers at the path afterwards.
pub fn plan_docx_paragraph_deletion(
  annotated : DocxAnnotatedResult,
  at~ : String,
) -> (@splice.SplicePlan, DocxDeleteReceipt) raise DocxError {
  guard insert_anchor_ordinal(at) is Some(_) else {
    raise Unsupported(
      message="delete-paragraph targets a direct body paragraph (p[N]); '\{at}' is not one",
    )
  }
  guard annotated.body_paragraph_span(at) is Some(span) else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' does not resolve in this document",
    )
  }
  let part = annotated.main_story_part()
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    raise Unsupported(
      message="delete-paragraph requires a mutation-safe read with retained source bytes",
    )
  }
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="delete-paragraph requires a mutation-safe read with a retained projection",
    )
  }
  let elements = projection.scan.elements()
  // The target must be a PHYSICAL direct child of w:body, and the
  // element index is the key to its subtree.
  let mut target_index = -1
  for index, element in elements {
    if element.byte_start == span.byte_start() &&
      element.local_name == "p" &&
      is_wml_uri(element.uri) {
      let parent = element.parent_index
      if parent >= 0 && parent < elements.length() {
        let holder = elements[parent]
        if holder.local_name == "body" && is_wml_uri(holder.uri) {
          target_index = index
        }
      }
      break
    }
  }
  guard target_index >= 0 else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' is not a DIRECT child of the body — paragraphs inside content controls, revisions, or compatibility wrappers are not deletion targets",
    )
  }
  // Subtree hazards: every element inside the paragraph's byte span is
  // part of what the deletion removes. WML constructs answer by name;
  // anything the blocklist misses dies with the paragraph and dangles
  // nothing this verb owes — relationships a deleted hyperlink leaves
  // behind are OPC-legal orphans.
  let mut successor_exists = false
  // Bookmark markers judge as PAIRS: every start inside must be the
  // `_GoBack` cursor artifact with its end inside, and no end inside
  // may belong to a start outside — anything else unbalances a range
  // or dangles a reference target.
  let bookmark_starts : Map[String, String] = Map([])
  let bookmark_ends : Array[String] = []
  for index, element in elements {
    if index == target_index {
      continue
    }
    if element.byte_start >= span.byte_start() &&
      element.byte_end <= span.byte_end() {
      if is_wml_uri(element.uri) {
        match delete_blocked_construct(element.local_name) {
          Some(reason) =>
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries \{reason}; deleting it would dangle or destroy document state outside the paragraph, so this deletion refuses",
            )
          None => ()
        }
        if element.local_name == "bookmarkStart" {
          let name = element.bookmark_name_raw.or("")
          let id = element.bookmark_id_raw.or("")
          guard name == "_GoBack" else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries the bookmark '\{name}'; deleting it would dangle or destroy document state outside the paragraph, so this deletion refuses",
            )
          }
          bookmark_starts[id] = name
        }
        if element.local_name == "bookmarkEnd" {
          bookmark_ends.push(element.bookmark_id_raw.or(""))
        }
      }
    } else if element.local_name == "p" &&
      is_wml_uri(element.uri) &&
      element.byte_start >= span.byte_end() {
      let parent = element.parent_index
      if parent >= 0 && parent < elements.length() {
        let holder = elements[parent]
        if holder.local_name == "body" && is_wml_uri(holder.uri) {
          successor_exists = true
        }
      }
    }
  }
  for id in bookmark_ends {
    guard bookmark_starts.get(id) is Some(_) else {
      raise Unsupported(
        message="delete-paragraph target '\{at}' carries a bookmark range boundary whose start lies outside it; deleting it would unbalance the range, so this deletion refuses",
      )
    }
  }
  for id, _name in bookmark_starts {
    guard bookmark_ends.contains(id) else {
      raise Unsupported(
        message="delete-paragraph target '\{at}' carries a bookmark range boundary whose end lies outside it; deleting it would unbalance the range, so this deletion refuses",
      )
    }
  }
  // The document-final direct body paragraph is structural: Word keeps
  // one, and a body whose last flow child is a table still needs its
  // trailing paragraph. No successor -> refuse.
  guard successor_exists else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' is the final direct body paragraph; the document keeps it",
    )
  }
  let story = annotated.main_story_source()
  let anchors = docx_paragraph_anchor_index(annotated, story)
  let (para_id, anchor_status) = match anchors.anchor_at(at) {
    Some(anchor) => {
      let id = if anchor.status() == "unique" { anchor.para_id() } else { None }
      (id, anchor.status())
    }
    None => (None, "unanchored")
  }
  guard insert_anchor_ordinal(at) is Some(ordinal)
  let successor_para_id = match anchors.anchor_at("p[\{ordinal + 1}]") {
    Some(anchor) =>
      if anchor.status() == "unique" {
        anchor.para_id()
      } else {
        None
      }
    None => None
  }
  let text = match docx_paragraph_projection(annotated, story, path=at) {
    Some(projection_text) => projection_text
    None => ""
  }
  let plan = @splice.SplicePlan::new()
  plan.pin_part(part, bytes)
  plan.edit_part(
    part,
    @splice.span_edit(start=span.byte_start(), end=span.byte_end(), b""),
  )
  (plan, { path: at, para_id, anchor_status, text, successor_para_id, })
}
