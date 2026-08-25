// The assumption `find` is built on, tested directly.

///|
/// `actionable` is computed by offering the planner an IDENTITY
/// replacement — the matched text replacing itself. That is only a valid
/// proxy for "a real edit here would be permitted" if the planner's
/// STRUCTURAL verdict does not depend on the replacement text.
///
/// If it did, find would overpromise: it would report a candidate
/// actionable that the mutation surface then refuses, which is the one
/// failure mode a read-before-write surface must not have.
///
/// This drives both edits over the same ranges and requires the verdicts
/// to match. It is the reason find does not carry its own classifier.
test "an identity edit is a valid proxy for a real edit" {
  let bodies = [
    // ordinary, one run
    "<w:p><w:r><w:t>Hello world</w:t></w:r></w:p>",
    // split across runs
    "<w:p><w:r><w:t>Hel</w:t></w:r><w:r><w:t>lo world</w:t></w:r></w:p>",
    // an atom inside the range. No range can SPLIT it (a tab projects
    // one unit), so every range here plans -- the atom is consumed
    // whole or not at all.
    "<w:p><w:r><w:t>Hello</w:t><w:tab/><w:t>world</w:t></w:r></w:p>",
    // a field's cached result
    (
      #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Hello world</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
    ),
    // a tracked insertion
    (
      #|<w:p><w:ins w:id="4" w:author="Ada" w:date="2001-01-01T00:00:00Z"><w:r><w:t>Hello world</w:t></w:r></w:ins></w:p>
    ),
    // a content control
    (
      #|<w:p><w:sdt><w:sdtPr><w:alias w:val="C"/></w:sdtPr><w:sdtContent><w:r><w:t>Hello world</w:t></w:r></w:sdtContent></w:sdt></w:p>
    ),
    // crossing a hyperlink edge
    (
      #|<w:p><w:r><w:t>Hello </w:t></w:r><w:hyperlink r:id="rId9" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:r><w:t>world</w:t></w:r></w:hyperlink></w:p>
    ),
    // Suppressed content the run owns, sitting BEFORE the text. Every
    // range plans, and the asymmetry with whole-run surgery is
    // deliberate rather than an oversight: N0c1 replaces the whole run,
    // so suppressed content would be stranded beside text the caller
    // never saw; N0c2 replaces a text RANGE and leaves those bytes
    // alone, so it refuses only when a range CROSSES the suppressed
    // site. Nothing crosses a site at position 0.
    "<w:p><w:r><w:footnoteRef/><w:t>Hello world</w:t></w:r></w:p>",
  ]
  let verdicts : Array[String] = []
  for body in bodies {
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
    let bytes = @utf8.encode(source)
    let projection = surgery_native_projection(source)
    // Every range in the paragraph, so the comparison is not carried by
    // one lucky geometry.
    let paragraph = projection.paragraphs[projection.paragraphs.length() - 1]
    let index = projection.paragraphs.length() - 1
    let width = paragraph.projection_end - paragraph.projection_start
    let mut agreed = 0
    let mut refused_any = 0
    for start in 0..<width {
      let first_end = start + 1
      for end in first_end..<=width {
        let slice = StringBuilder()
        let mut at = 0
        for contribution in paragraph.contributions {
          for character in contribution.value {
            if at >= start && at < end {
              slice.write_char(character)
            }
            at = at + 1
          }
        }
        let identity_ok = find_wbtest_plans(
          projection,
          bytes,
          index,
          start,
          end,
          slice.to_string(),
        )
        let real_ok = find_wbtest_plans(
          projection, bytes, index, start, end, "XX",
        )
        assert_eq(
          identity_ok,
          real_ok,
          msg="identity and real edits disagree over [" +
            start.to_string() +
            "," +
            end.to_string() +
            ") in " +
            body,
        )
        agreed = agreed + 1
        if !identity_ok {
          refused_any = refused_any + 1
        }
      }
    }
    verdicts.push(
      agreed.to_string() + "/" + refused_any.to_string() + " refused",
    )
  }
  // Pinned so the agreement is not vacuous: if every range in every
  // fixture were accepted, the two edits would agree trivially and this
  // test would prove nothing.
  debug_inspect(
    verdicts,
    content=(
      #|[
      #|  "66/0 refused",
      #|  "66/0 refused",
      #|  "66/0 refused",
      #|  "66/66 refused",
      #|  "66/66 refused",
      #|  "66/66 refused",
      #|  "66/30 refused",
      #|  "66/0 refused",
      #|]
    ),
  )
}

///|
/// Whether the planner accepts one range with one replacement.
fn find_wbtest_plans(
  projection : ReaderProjection,
  bytes : Bytes,
  paragraph_index : Int,
  start : Int,
  end : Int,
  replacement : String,
) -> Bool {
  try {
    ignore(
      plan_paragraph_text_edits(projection, bytes, paragraph_index, [
        { start, end, replacement },
      ]),
    )
    true
  } catch {
    _ => false
  } noraise {
    _ => true
  }
}
