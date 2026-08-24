// Blackbox witnesses for the read-only match surface (N2a), exercised
// through the public API only.

///|
fn find_fixture(body : String) -> @docx.DocxAnnotatedResult raise {
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><w:body>\{body}<w:sectPr/></w:body></w:document>"
  @docx.read_docx_annotated(fixture_docx(document))
}

///|
fn find_all(
  annotated : @docx.DocxAnnotatedResult,
  needle : String,
  within? : String,
) -> Array[@docx.DocxMatch] raise {
  @docx.find_docx_matches(
    annotated,
    annotated.main_story_source(),
    needle~,
    within?,
  ).matches()
}

///|
/// The coordinates are paragraph-relative UTF-16 over the PROJECTION,
/// and a match that spans run boundaries names every run it draws from.
test "find reports projection coordinates across run boundaries" {
  let annotated = find_fixture(
    "<w:p><w:r><w:t>Hello </w:t></w:r><w:r><w:t>world</w:t></w:r></w:p>",
  )
  let hits = find_all(annotated, "lo wo")
  assert_eq(hits.length(), 1)
  let hit = hits[0]
  // The literal never appears in the XML -- it spans two `w:t` elements.
  // That is the whole reason a projection-coordinate matcher exists.
  inspect(
    (hit.ordinal(), hit.path(), hit.start(), hit.end(), hit.text()),
    content=(
      #|(1, p[1], 3, 8, lo wo)
    ),
  )
  assert_eq(hit.runs().length(), 2)
  assert_true(hit.actionable())
  assert_eq(hit.reason(), "")
}

///|
/// A read returns nothing rather than refusing. Only a mutation fails
/// closed on finding no match.
test "find returns an empty list rather than refusing" {
  let annotated = find_fixture("<w:p><w:r><w:t>alpha</w:t></w:r></w:p>")
  assert_eq(find_all(annotated, "absent").length(), 0)
  // The REQUEST can still be refused: an empty needle names every
  // position, which is a caller error rather than a document fact.
  let mut refused = false
  try ignore(find_all(annotated, "")) catch {
    _ => refused = true
  } noraise {
    _ => ()
  }
  assert_true(refused, msg="an empty needle should refuse rather than match")
}

///|
/// Candidates are non-overlapping and numbered in document order, so an
/// agent can act on them independently.
test "find numbers non-overlapping candidates in document order" {
  let annotated = find_fixture(
    "<w:p><w:r><w:t>aaaa</w:t></w:r></w:p><w:p><w:r><w:t>aa</w:t></w:r></w:p>",
  )
  let hits = find_all(annotated, "aa")
  let seen : Array[String] = []
  for hit in hits {
    seen.push(
      hit.ordinal().to_string() +
      ":" +
      hit.path() +
      "[" +
      hit.start().to_string() +
      "," +
      hit.end().to_string() +
      ")",
    )
  }
  // Three, not five: `aaaa` yields two non-overlapping hits.
  inspect(
    seen,
    content=(
      #|[1:p[1][0,2), 2:p[1][2,4), 3:p[2][0,2)]
    ),
  )
}

///|
/// `within` restricts to a subtree by path prefix.
test "find restricts to a subtree" {
  let annotated = find_fixture(
    "<w:p><w:r><w:t>needle</w:t></w:r></w:p><w:p><w:r><w:t>needle</w:t></w:r></w:p>",
  )
  assert_eq(find_all(annotated, "needle").length(), 2)
  let scoped = find_all(annotated, "needle", within="p[2]")
  assert_eq(scoped.length(), 1)
  assert_eq(scoped[0].path(), "p[2]")
}

///|
/// A match can read as ordinary prose and be carried by an atom. An
/// agent that assumes every character lives in a `w:t` will address the
/// wrong thing, so the source kinds are reported.
test "find names the source kinds a match draws from" {
  let annotated = find_fixture(
    "<w:p><w:r><w:t>a</w:t><w:tab/><w:t>b</w:t></w:r></w:p>",
  )
  let hits = find_all(annotated, "a\tb")
  assert_eq(hits.length(), 1)
  inspect(
    hits[0].run_kinds(),
    content=(
      #|[text, tab]
    ),
  )
}

///|
/// Non-actionable candidates are LISTED, with the construct named.
///
/// Hiding them would be worse than useless: the agent would conclude the
/// text is not there, when the truth is that it is there and must not be
/// rewritten. The remedy differs per construct, which is why the reason
/// names the construct rather than the mechanism.
test "find lists uneditable candidates and names the construct" {
  let field =
    #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>seven</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
  let hits = find_all(find_fixture(field), "seven")
  assert_eq(hits.length(), 1)
  assert_false(hits[0].actionable())
  assert_eq(hits[0].reason(), "field-region")
  let tracked =
    #|<w:p><w:ins w:id="9" w:author="Ada" w:date="2001-01-01T00:00:00Z"><w:r><w:t>seven</w:t></w:r></w:ins></w:p>
  let tracked_hits = find_all(find_fixture(tracked), "seven")
  assert_eq(tracked_hits.length(), 1)
  assert_false(tracked_hits[0].actionable())
  assert_eq(tracked_hits[0].reason(), "tracked-region")
  let control =
    #|<w:p><w:sdt><w:sdtPr><w:alias w:val="Client"/></w:sdtPr><w:sdtContent><w:r><w:t>seven</w:t></w:r></w:sdtContent></w:sdt></w:p>
  let control_hits = find_all(find_fixture(control), "seven")
  assert_eq(control_hits.length(), 1)
  assert_false(control_hits[0].actionable())
  assert_eq(control_hits[0].reason(), "sdt-content")
}

///|
/// The reason vocabulary stays worth reading: a corpus that drifted to
/// all-actionable, or all-refused, would make the other tests agree
/// trivially. This pins the MIX.
///
/// The deeper property — that `actionable` agrees with what the mutation
/// surface actually does — is proved at the planner level in
/// `find_api_wbtest.mbt`, because the public partial-replace surface
/// does not exist yet (that is N2b).
test "find keeps a mix of actionable and refused verdicts" {
  let bodies = [
    "<w:p><w:r><w:t>Hello world</w:t></w:r></w:p>",
    "<w:p><w:r><w:t>Hel</w:t></w:r><w:r><w:t>lo world</w:t></w:r></w:p>",
    (
      #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Hello world</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
    ),
    (
      #|<w:p><w:ins w:id="4" w:author="Ada" w:date="2001-01-01T00:00:00Z"><w:r><w:t>Hello world</w:t></w:r></w:ins></w:p>
    ),
    (
      #|<w:p><w:r><w:t>Hello </w:t></w:r><w:hyperlink r:id="rId9" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:r><w:t>world</w:t></w:r></w:hyperlink></w:p>
    ),
  ]
  let verdicts : Array[String] = []
  for body in bodies {
    for hit in find_all(find_fixture(body), "lo wo") {
      verdicts.push(if hit.actionable() { "ok" } else { hit.reason() })
    }
  }
  inspect(
    verdicts,
    content=(
      #|[ok, ok, field-region, tracked-region, hyperlink-boundary]
    ),
  )
}

///|
/// `within` must not widen by ordinal digits. This passes only because
/// scanner paths bracket their ordinals; a change to the path grammar
/// would break it, which is the point of pinning it.
test "find's subtree filter does not confuse p[1] with p[10]" {
  let body = StringBuilder()
  for index in 1..<=11 {
    body.write_string("<w:p><w:r><w:t>needle\{index}</w:t></w:r></w:p>")
  }
  let annotated = find_fixture(body.to_string())
  // Unrestricted: every paragraph contributes one candidate.
  assert_eq(find_all(annotated, "needle").length(), 11)
  // Restricted to p[1]: exactly one, and NOT p[10] or p[11].
  let scoped = find_all(annotated, "needle", within="p[1]")
  assert_eq(scoped.length(), 1)
  assert_eq(scoped[0].path(), "p[1]")
  assert_eq(scoped[0].context_after(), "1")
}

///|
/// Context windows must not split a surrogate pair.
///
/// Offsets are code-unit arithmetic, so an astral character near the
/// window edge lands the boundary between a pair's two halves.
/// `substring` returns that ill-formed string rather than trapping, so
/// nothing fails here — it fails much later, when the value is encoded.
/// The window is snapped outward instead, costing at most one character.
///
/// The fixture is codex's counterexample: one astral character, then
/// enough ASCII that the default window starts inside the pair.
test "find never returns a context window split across a surrogate pair" {
  let filler = StringBuilder()
  for _ in 0..<23 {
    filler.write_string("a")
  }
  let annotated = find_fixture(
    "<w:p><w:r><w:t>😀\{filler.to_string()}X</w:t></w:r></w:p>",
  )
  let hits = find_all(annotated, "X")
  assert_eq(hits.length(), 1)
  let before = hits[0].context_before()
  // Well-formed means every code unit re-encodes. A lone half would
  // survive in memory and only fail at the boundary, so the check is
  // that the value round-trips as bytes.
  let encoded = @utf8.encode(before)
  assert_eq(@utf8.decode(encoded), before)
  // And the window really did reach back to the astral character's
  // neighbourhood, so the test is not passing by having no context.
  assert_true(
    before.length() >= 20,
    msg="context window collapsed to " + before.length().to_string(),
  )
}

///|
/// Totals must describe the DOCUMENT, not the page that was returned.
///
/// The first version of the limit computed `matches_total` from the
/// retained array, so `truncated` could never be true and a bounded read
/// silently claimed the document held exactly what it had shown. That is
/// worse than a slow read: an agent would conclude it had seen
/// everything.
test "find's totals describe the document, not the returned page" {
  let annotated = find_fixture(
    "<w:p><w:r><w:t>iiii</w:t></w:r></w:p><w:p><w:r><w:t>ii</w:t></w:r></w:p>",
  )
  let all = @docx.find_docx_matches(
    annotated,
    annotated.main_story_source(),
    needle="i",
  )
  assert_eq(all.total(), 6)
  assert_eq(all.matches().length(), 6)
  assert_false(all.truncated())
  let capped = @docx.find_docx_matches(
    annotated,
    annotated.main_story_source(),
    needle="i",
    limit=2,
  )
  // Two examined, but the document's true count is still reported.
  assert_eq(capped.matches().length(), 2)
  assert_eq(capped.total(), 6)
  assert_true(capped.truncated())
  // Ordinals stay GLOBAL, so the second entry is candidate 2 of 6
  // rather than 2 of 2.
  assert_eq(capped.matches()[1].ordinal(), 2)
}

///|
/// A context window larger than the text must clamp rather than overflow
/// into a negative slice bound.
test "find clamps an oversized context window" {
  let annotated = find_fixture("<w:p><w:r><w:t>abc</w:t></w:r></w:p>")
  let hits = @docx.find_docx_matches(
    annotated,
    annotated.main_story_source(),
    needle="b",
    context=2147483647,
  ).matches()
  assert_eq(hits.length(), 1)
  assert_eq(hits[0].context_before(), "a")
  assert_eq(hits[0].context_after(), "c")
}
