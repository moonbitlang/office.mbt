///|
/// #462 C1c: the adoption cutover oracles. Mutation-safe public stories no
/// longer get their own index scan — the index adopts the retained
/// reader-projection scans, making the annotation surface and the mutation
/// resolver read the SAME physical scan. These pins hold that cutover.
fn adoption_fixture() -> Bytes raise {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/footnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
  )
  builder.add_override(
    "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId2",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    "footnotes.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId3",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "comments.xml",
    source="word/document.xml",
  )
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:commentRangeStart w:id="1"/><w:r><w:t>Body</w:t></w:r><w:commentRangeEnd w:id="1"/><w:r><w:commentReference w:id="1"/></w:r></w:p><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  builder.add_part(
    "word/footnotes.xml",
    @utf8.encode(
      (
        #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:id="1"><w:p><w:r><w:t>note</w:t></w:r></w:p></w:footnote></w:footnotes>
      ),
    ),
  )
  builder.add_part(
    "word/comments.xml",
    @utf8.encode(
      (
        #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="1" w:author="A"><w:p><w:r><w:t>c</w:t></w:r></w:p></w:comment></w:comments>
      ),
    ),
  )
  builder.build()
}

///|
test "the index's mutation-safe story scans ARE the retained projections" {
  let annotated = read_docx_annotated(adoption_fixture())
  let story_keys : Array[String] = []
  for entry in annotated.index.scans {
    story_keys.push(entry.0)
  }
  assert_eq(story_keys, ["/body", "/footnotes", "/comments"])
  let parts_by_key = [
    ("/body", "word/document.xml"),
    ("/footnotes", "word/footnotes.xml"),
    ("/comments", "word/comments.xml"),
  ]
  for pair in parts_by_key {
    let (story_key, part) = pair
    guard annotated.reader_projections.get(part) is Some(projection) else {
      fail("expected a retained projection for \{part}")
    }
    for entry in annotated.index.scans {
      let (key, scan) = entry
      if key == story_key {
        assert_true(
          physical_equal(scan, projection.scan),
          msg="\{story_key} must adopt the retained scan instance",
        )
      }
    }
  }
}

///|
test "adopted story scans equal a fresh rescan of the same retained bytes" {
  let annotated = read_docx_annotated(adoption_fixture())
  let mut compared = 0
  for entry in annotated.index.scans {
    let (story_key, adopted) = entry
    for part, projection in annotated.reader_projections {
      if physical_equal(adopted, projection.scan) {
        guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
          fail("expected retained source bytes for \{part}")
        }
        assert_scans_agree("adopted \{story_key}", scan_story(bytes), adopted)
        compared += 1
      }
    }
  }
  assert_eq(compared, 3)
}

///|
test "adopted scan warnings surface through the index collector" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:ins w:id="1"><w:r><w:t>x</w:t></w:r></w:ins><w:del w:id="2"><w:r><w:delText>y</w:delText></w:r></w:del></w:p><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  let annotated = read_docx_annotated(builder.build())
  debug_inspect(
    annotated.annotations().warnings(),
    content=(
      #|[
      #|  "annotation scanner: a w:ins revision has no w:author attribute",
      #|  "annotation scanner: a w:del revision has no w:author attribute",
      #|]
    ),
  )
}

///|
test "read-time path-budget exhaustion keeps resource classification" {
  // Scan level: the C1b plumbing genuinely charges a supplied budget.
  let tiny : AnnotationPathBudget = {
    shared_xml_budget: None,
    remaining_chars: 4,
  }
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>x</w:t></w:r></w:p></w:body></w:document>
  try
    scan_projection_source_tree(@utf8.encode(source), path_budget=tiny)
    |> ignore
  catch {
    ResourceLimit(..) => ()
    _ => fail("expected a ResourceLimit refusal")
  } noraise {
    _ => fail("expected the tiny path budget to refuse")
  }
  // End to end: exhaustion inside the joined read surfaces as ResourceLimit
  // (reader_join_refusal_error passes resource causes through unwrapped),
  // exactly the classification the pre-adoption index raise produced.
  let archive = @mbtzip.read(adoption_fixture())
  let starving = @xml.xml_read_budget(
    max_source_units=1024 * 1024,
    max_tokens=1024 * 1024,
    max_materialized_chars=700,
    max_token_chars=4096,
  )
  try read_docx_annotated_archive_limited(archive, starving) |> ignore catch {
    ResourceLimit(..) => ()
    _ => fail("expected a ResourceLimit refusal")
  } noraise {
    _ => fail("expected the starving budget to refuse")
  }
}
