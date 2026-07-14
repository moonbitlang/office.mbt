///|
test "XLSX relationship IDs use one bounded lookup index" {
  let relationships : Array[RawRelationship] = []
  let prefix = "relationship-id-with-a-long-common-prefix-"
  for ordinal in 0..<512 {
    relationships.push({
      id: prefix + ordinal.to_string(),
      kind: transitional_office_relationship_prefix + "worksheet",
      target: "xl/worksheets/sheet\{ordinal}.xml",
      external: false,
    })
  }
  let index = relationship_index_by_id(relationships)
  assert_eq(index.length(), relationships.length())
  for ordinal in [0, 255, 511] {
    let id = prefix + ordinal.to_string()
    guard index.get(id) is Some(relationship) else {
      fail("relationship index lost ID '\{id}'")
    }
    assert_eq(relationship.target, "xl/worksheets/sheet\{ordinal}.xml")
  }
}

///|
test "raw relationship targets use the shared fallible OPC resolver" {
  assert_eq(
    normalize_relationship_target("word/", "/word/./document.xml"),
    Some("word/document.xml"),
  )
  assert_eq(
    normalize_relationship_target("word/", "../custom/main.xml"),
    Some("custom/main.xml"),
  )
  assert_eq(normalize_relationship_target("word/", "../../escape.xml"), None)
  assert_eq(normalize_relationship_target("", "/../escape.xml"), None)
}

///|
fn wb_raw_archive_limit_kind(run : () -> Unit raise RawError) -> String raise {
  try run() catch {
    RawError(code~, details~, ..) => {
      assert_eq(code, "office.raw.resource_limit")
      guard details is Some(Object(fields)) &&
        fields.get("kind") is Some(String(kind)) else {
        fail("expected structured raw archive limit details")
      }
      kind
    }
  } noraise {
    _ => fail("expected raw archive resource limit")
  }
}

///|
test "archive boundary checks serialized, entry, and aggregate limits" {
  let count = @zip.Archive::new()
  count.add("a", b"")
  count.add("b", b"")
  count.add("c", b"")
  assert_eq(
    wb_raw_archive_limit_kind(() => {
      check_raw_archive_materialization_limits(count, 2, 4, 8)
    }),
    "entry_count",
  )

  let entry = @zip.Archive::new()
  entry.add("large", b"12345")
  assert_eq(
    wb_raw_archive_limit_kind(() => {
      check_raw_archive_materialization_limits(entry, 2, 4, 8)
    }),
    "entry_uncompressed_bytes",
  )

  let aggregate = @zip.Archive::new()
  aggregate.add("left", b"123")
  aggregate.add("right", b"456")
  assert_eq(
    wb_raw_archive_limit_kind(() => {
      check_raw_archive_materialization_limits(aggregate, 2, 4, 5)
    }),
    "total_uncompressed_bytes",
  )

  let source_archive = @zip.Archive::new()
  source_archive.add("bounded", b"x")
  let source = @zip.write(source_archive)
  let bounded = @zip.read_limited(
    source,
    max_entries=1,
    max_entry_uncompressed_bytes=1,
    max_total_uncompressed_bytes=1,
  )
  assert_eq(
    wb_raw_archive_limit_kind(() => {
      check_bounded_raw_archive_limits(bounded, source.length() - 1, 1, 1, 1)
    }),
    "package_bytes",
  )
  let changed = bounded.fork()
  assert_true(changed.replace("bounded", b"y"))
  assert_eq(
    wb_raw_archive_limit_kind(() => {
      check_bounded_raw_archive_limits(changed, source.length(), 1, 1, 1)
    }),
    "bounded_archive_source",
  )
  let unbounded = @zip.read(source)
  assert_eq(
    wb_raw_archive_limit_kind(() => {
      check_bounded_raw_archive_limits(unbounded, source.length(), 1, 1, 1)
    }),
    "bounded_archive_source",
  )

  let output = @zip.Archive::new()
  output.add("payload", b"candidate")
  assert_eq(
    wb_raw_archive_limit_kind(() => {
      ignore(write_raw_candidate_archive(output, 8))
    }),
    "package_bytes",
  )
}
