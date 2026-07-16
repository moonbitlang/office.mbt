///|
fn tiny_package() -> Bytes raise {
  let archive = @mbtzip.Archive::new()
  archive.add("a.xml", @utf8.encode("<r><a/></r>"))
  archive.add("b.bin", b"\x00\x01\x02\x03binary payload", compression=Store)
  archive.add("c.xml", @utf8.encode("<c/>"))
  @mbtzip.write(archive)
}

///|
fn splice_hash_clustered_names(count : Int, bucket_mask : Int) -> Array[String] {
  let names : Array[String] = []
  let mut candidate = 0
  while names.length() < count {
    let name = "n\{candidate}.xml"
    if (name.hash() & bucket_mask) == 0 {
      names.push(name)
    }
    candidate += 1
  }
  names
}

///|
fn reused_namespace_splice_source(uri_chars : Int, child_count : Int) -> String {
  let source = StringBuilder()
  source.write_string("<root xmlns:n=\"")
  source.write_string("u".repeat(uri_chars))
  source.write_string("\">")
  for _ in 0..<child_count {
    source.write_string("<n:x/>")
  }
  source.write_string("</root>")
  source.to_string()
}

///|
fn[T] expect_splice_failure(
  action : () -> T raise @core.DocxError,
  expected_prefix : String,
) -> Unit raise {
  try {
    let _ = action()
  } catch {
    err => {
      let message = match err {
        Unsupported(message~)
        | InvalidZip(message~)
        | InvalidXml(message~)
        | MissingPart(message~)
        | ResourceLimit(message~, ..) => message
      }
      if !message.has_prefix(expected_prefix) {
        fail("unexpected message: \{message}")
      }
    }
  } noraise {
    _ => fail("expected the splice to fail closed")
  }
}

///|
test "L0: splicing edits exactly the spans and preserves everything else" {
  let original = tiny_package()
  let plan = @splice.SplicePlan::new()
  // Insert <x/> before </r> in a.xml (offset computed, not guessed).
  let a_text = "<r><a/></r>"
  guard a_text.find("</r>") is Some(insert_at)
  plan.edit_part(
    "a.xml",
    @splice.span_edit(start=insert_at, end=insert_at, @utf8.encode("<x/>")),
  )
  plan.add_part("d.xml", @utf8.encode("<d/>"))
  let spliced = @splice.splice_docx(original, plan)
  let output = @mbtzip.read(spliced)
  // The edited part is the manual splice of the original bytes.
  guard output.get("a.xml") is Some(a_bytes)
  inspect(@utf8.decode(a_bytes, ignore_bom=true), content="<r><a/><x/></r>")
  // Untouched entries: payload equality AND kept compression method.
  guard output.get("b.bin") is Some(b_bytes)
  inspect(b_bytes == b"\x00\x01\x02\x03binary payload", content="true")
  let mut b_compression = ""
  for entry in output.entries() {
    if entry.name() == "b.bin" {
      b_compression = "\{to_repr(entry.compression())}"
    }
  }
  inspect(b_compression, content="Store")
  // Entry ORDER: originals in place, new parts appended.
  let names : Array[String] = []
  for entry in output.entries() {
    names.push(entry.name())
  }
  debug_inspect(
    names,
    content=(
      #|["a.xml", "b.bin", "c.xml", "d.xml"]
    ),
  )
  // The byte API returns the exact original serialization for a true no-op.
  let unchanged = @splice.splice_docx(original, @splice.SplicePlan::new())
  assert_eq(unchanged, original)
  let repacked = @mbtzip.read(unchanged)
  guard repacked.get("c.xml") is Some(c_bytes)
  inspect(c_bytes == @utf8.encode("<c/>"), content="true")
}

///|
test "L0: archive validation ignores deterministic hash clustering" {
  let archive = @mbtzip.Archive::new()
  for name in splice_hash_clustered_names(256, 0x3FF) {
    assert_eq(name.hash() & 0x3FF, 0)
    archive.add(name, b"<r/>")
  }
  let original = @mbtzip.write(archive)
  assert_eq(@splice.splice_docx(original, @splice.SplicePlan::new()), original)
}

///|
test "D1: source-pinned plans compose and serialize through a hard ceiling" {
  let original = tiny_package()
  let archive = @mbtzip.read(original)
  guard archive.get("a.xml") is Some(a_bytes)
  guard archive.get("c.xml") is Some(c_bytes)
  let first = @splice.SplicePlan::new()
  first.pin_part("a.xml", a_bytes)
  let a_text = "<r><a/></r>"
  guard a_text.find("</r>") is Some(a_insert)
  first.edit_part(
    "a.xml",
    @splice.span_edit(start=a_insert, end=a_insert, @utf8.encode("<x/>")),
  )
  first.add_part("d.xml", @utf8.encode("<d/>"))
  let second = @splice.SplicePlan::new()
  second.pin_part("c.xml", c_bytes)
  second.edit_part(
    "c.xml",
    @splice.span_edit(start=2, end=2, @utf8.encode(" marked=\"yes\"")),
  )
  first.merge(second)
  assert_eq(first.is_empty(), false)
  debug_inspect(
    first.declared_parts(),
    content=(
      #|["a.xml", "c.xml", "d.xml"]
    ),
  )
  debug_inspect(first.unpinned_edited_parts(), content="[]")
  let independent = first.copy()
  independent.add_part("copy-only.xml", @utf8.encode("<copy/>"))
  debug_inspect(
    first.declared_parts(),
    content=(
      #|["a.xml", "c.xml", "d.xml"]
    ),
  )
  first.check_against(archive, require_pins=true)
  let candidate = @splice.splice_docx_archive(
    archive,
    first,
    max_output_bytes=1_000_000,
    require_pins=true,
  )
  assert_eq(
    @splice.splice_docx_archive(
      archive,
      first,
      max_output_bytes=candidate.length(),
      require_pins=true,
    ),
    candidate,
  )
  expect_splice_failure(
    () => {
      @splice.splice_docx_archive(
        archive,
        first,
        max_output_bytes=candidate.length() - 1,
        require_pins=true,
      )
    },
    "the spliced package exceeds the output limit",
  )
}

///|
test "D1: bounded preflight rejects compressible payloads and oversized manifests" {
  let archive = @mbtzip.read(tiny_package())
  let materialization_limits = @splice.splice_limits(
    max_archive_entries=512,
    max_changed_parts=256,
    max_part_name_chars=256,
    max_entry_uncompressed_bytes=16_384,
    max_total_uncompressed_bytes=32_768,
    max_materialized_bytes=128,
    max_xml_tokens=4_096,
  )
  let compressible = @splice.SplicePlan::new()
  compressible.edit_part(
    "a.xml",
    @splice.span_edit(start=3, end=3, @utf8.encode("<x/>".repeat(512))),
  )
  expect_splice_failure(
    () => compressible.check_against(archive, limits=materialization_limits),
    "the splice materialization limit is 128 bytes",
  )
  let manifest_limits = @splice.splice_limits(
    max_archive_entries=512,
    max_changed_parts=256,
    max_part_name_chars=256,
    max_entry_uncompressed_bytes=16_384,
    max_total_uncompressed_bytes=32_768,
    max_materialized_bytes=16_384,
    max_xml_tokens=4_096,
  )
  let too_many_parts = @splice.SplicePlan::new()
  for index in 0..<257 {
    too_many_parts.add_part("added/part-\{index}.xml", @utf8.encode("<x/>"))
  }
  expect_splice_failure(
    () => too_many_parts.check_against(archive, limits=manifest_limits),
    "the splice preservation manifest limit is 256 parts",
  )
}

///|
test "D1: splice XML validation charges reused namespace-derived names" {
  let source = reused_namespace_splice_source(4_096, 32)
  let archive = @mbtzip.Archive::new()
  archive.add("dense.xml", @utf8.encode(source))
  let plan = @splice.SplicePlan::new()
  plan.edit_part("dense.xml", @splice.span_edit(start=0, end=0, b""))
  let limits = @splice.splice_limits(
    max_archive_entries=16,
    max_changed_parts=4,
    max_part_name_chars=64,
    max_entry_uncompressed_bytes=16_384,
    max_total_uncompressed_bytes=32_768,
    max_materialized_bytes=16_384,
    max_xml_tokens=10_000,
  )
  expect_splice_failure(
    () => plan.check_against(archive, limits~),
    "splicing 'dense.xml' exceeded XML resource limits: XML materialized character budget exceeded",
  )
}

///|
test "D1: splice XML nesting exhaustion is a resource failure" {
  let source = "<n>".repeat(300) + "</n>".repeat(300)
  let archive = @mbtzip.Archive::new()
  archive.add("deep.xml", @utf8.encode(source))
  let plan = @splice.SplicePlan::new()
  plan.edit_part("deep.xml", @splice.span_edit(start=0, end=0, b""))
  expect_splice_failure(
    () => plan.check_against(archive),
    "splicing 'deep.xml' exceeded XML resource limits: XML nesting too deep",
  )
}

///|
test "D1: splice XML parser budget is shared across edited parts" {
  let archive = @mbtzip.Archive::new()
  archive.add("a.xml", b"<a/>")
  archive.add("b.xml", b"<b/>")
  let limits = @splice.splice_limits(
    max_archive_entries=16,
    max_changed_parts=4,
    max_part_name_chars=64,
    max_entry_uncompressed_bytes=1_024,
    max_total_uncompressed_bytes=4_096,
    max_materialized_bytes=1_024,
    max_xml_tokens=3,
  )
  let one = @splice.SplicePlan::new()
  one.edit_part("a.xml", @splice.span_edit(start=0, end=0, b""))
  one.check_against(archive, limits~)
  let two = @splice.SplicePlan::new()
  two.edit_part("a.xml", @splice.span_edit(start=0, end=0, b""))
  two.edit_part("b.xml", @splice.span_edit(start=0, end=0, b""))
  try two.check_against(archive, limits~) catch {
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlTokens")
      assert_true(message.has_prefix("splicing '"))
      assert_true(
        message.contains(
          "exceeded XML resource limits: XML token budget exceeded",
        ),
      )
    }
    _ => fail("expected aggregate splice XML resource failure")
  } noraise {
    _ => fail("expected the second edited part to exhaust the shared budget")
  }
}

///|
test "D1: stale, unpinned, conflicting, and noncanonical plans fail closed" {
  let archive = @mbtzip.read(tiny_package())
  guard archive.get("a.xml") is Some(a_bytes)
  let pinned = @splice.SplicePlan::new()
  pinned.pin_part("a.xml", a_bytes)
  pinned.edit_part(
    "a.xml",
    @splice.span_edit(start=3, end=3, @utf8.encode("<x/>")),
  )
  let changed = archive.fork()
  assert_true(changed.replace("a.xml", @utf8.encode("<r><changed/></r>")))
  expect_splice_failure(
    () => pinned.check_against(changed, require_pins=true),
    "the splice plan is stale: source part 'a.xml' changed",
  )
  let unpinned = @splice.SplicePlan::new()
  unpinned.edit_part(
    "a.xml",
    @splice.span_edit(start=3, end=3, @utf8.encode("<x/>")),
  )
  debug_inspect(
    unpinned.unpinned_edited_parts(),
    content=(
      #|["a.xml"]
    ),
  )
  expect_splice_failure(
    () => unpinned.check_against(archive, require_pins=true),
    "the splice plan edits 'a.xml' without pinned source bytes",
  )
  let conflicting = @splice.SplicePlan::new()
  conflicting.pin_part("a.xml", @utf8.encode("<different/>"))
  expect_splice_failure(
    () => pinned.merge(conflicting),
    "cannot merge splice plans with different source bytes for 'a.xml'",
  )
  let malformed_name = @splice.SplicePlan::new()
  malformed_name.edit_part(
    "word/../document.xml",
    @splice.span_edit(start=0, end=0, b""),
  )
  expect_splice_failure(
    () => malformed_name.check_against(archive),
    "splice plan part names must not contain empty, '.', or '..' components",
  )
}

///|
test "D1: merge rejects cross-plan case aliases atomically" {
  let additions = @splice.SplicePlan::new()
  additions.add_part("new.xml", @utf8.encode("<first/>"))
  let aliased_addition = @splice.SplicePlan::new()
  aliased_addition.add_part("NEW.XML", @utf8.encode("<second/>"))
  expect_splice_failure(
    () => additions.merge(aliased_addition),
    "cannot merge splice plans with case-equivalent part names 'new.xml' and 'NEW.XML'",
  )
  debug_inspect(
    additions.declared_parts(),
    content=(
      #|["new.xml"]
    ),
  )
  let pins = @splice.SplicePlan::new()
  pins.pin_part("word/document.xml", @utf8.encode("<first/>"))
  let aliased_pin = @splice.SplicePlan::new()
  aliased_pin.pin_part("WORD/DOCUMENT.XML", @utf8.encode("<second/>"))
  expect_splice_failure(
    () => pins.merge(aliased_pin),
    "cannot merge splice plans with case-equivalent part names 'word/document.xml' and 'WORD/DOCUMENT.XML'",
  )
}

///|
test "L0: the splice fail-closed matrix" {
  let original = tiny_package()
  // Overlapping edits.
  let overlapping = @splice.SplicePlan::new()
  overlapping.edit_part("a.xml", @splice.span_edit(start=0, end=5, b""))
  overlapping.edit_part(
    "a.xml",
    @splice.span_edit(start=3, end=7, @utf8.encode("<z/>")),
  )
  expect_splice_failure(
    () => @splice.splice_docx(original, overlapping),
    "the splice plan's edits on 'a.xml' overlap",
  )
  // Out-of-range edit.
  let ranged = @splice.SplicePlan::new()
  ranged.edit_part("a.xml", @splice.span_edit(start=0, end=9999, b""))
  expect_splice_failure(
    () => @splice.splice_docx(original, ranged),
    "a splice edit on 'a.xml' ends at 9999",
  )
  // Editing a part the package does not contain.
  let missing = @splice.SplicePlan::new()
  missing.edit_part("nope.xml", @splice.span_edit(start=0, end=0, b"x"))
  expect_splice_failure(
    () => @splice.splice_docx(original, missing),
    "the splice plan edits 'nope.xml', which the package does not contain",
  )
  // Adding a part that already exists (and double-adding in the plan).
  let clobbering = @splice.SplicePlan::new()
  clobbering.add_part("a.xml", b"<boom/>")
  expect_splice_failure(
    () => @splice.splice_docx(original, clobbering),
    "the splice plan adds 'a.xml', which already exists",
  )
  let doubled = @splice.SplicePlan::new()
  doubled.add_part("d.xml", b"<d/>")
  expect_splice_failure(
    () => doubled.add_part("d.xml", b"<d2/>"),
    "the splice plan already adds a part named 'd.xml'",
  )
  // An edit that breaks well-formedness never leaves the function.
  let breaking = @splice.SplicePlan::new()
  breaking.edit_part(
    "a.xml",
    @splice.span_edit(start=3, end=3, @utf8.encode("<unclosed")),
  )
  expect_splice_failure(
    () => @splice.splice_docx(original, breaking),
    "splicing 'a.xml' produced malformed XML",
  )
  // Lexically malformed XML must fail too; a map-backed tolerant parse would
  // otherwise overwrite the first attribute and let this escape.
  let duplicate_attribute = @splice.SplicePlan::new()
  duplicate_attribute.edit_part(
    "a.xml",
    @splice.span_edit(
      start=2,
      end=2,
      @utf8.encode(" id=\"first\" id=\"second\""),
    ),
  )
  expect_splice_failure(
    () => @splice.splice_docx(original, duplicate_attribute),
    "splicing 'a.xml' produced malformed XML",
  )
  // Negative spans are rejected at construction.
  expect_splice_failure(
    () => @splice.span_edit(start=-1, end=0, b""),
    "a span edit cannot start at -1",
  )
  expect_splice_failure(
    () => @splice.span_edit(start=5, end=2, b""),
    "a span edit cannot end at 2, before its start at 5",
  )
}

///|
test "L0: duplicate zip entries and foreign encodings fail closed" {
  // Duplicate entry names in the ORIGINAL package.
  let doubled = @mbtzip.Archive::new()
  doubled.add("a.xml", @utf8.encode("<r/>"))
  doubled.add("a.xml", @utf8.encode("<r2/>"))
  let dup_bytes = @mbtzip.write(doubled)
  expect_splice_failure(
    () => @splice.splice_docx(dup_bytes, @splice.SplicePlan::new()),
    "the package holds duplicate zip entries named 'a.xml'",
  )
  // OPC identity is case-insensitive, including for a true no-op.
  let aliased = @mbtzip.Archive::new()
  aliased.add("a.xml", @utf8.encode("<r/>"))
  aliased.add("A.XML", @utf8.encode("<r2/>"))
  let aliased_bytes = @mbtzip.write(aliased)
  expect_splice_failure(
    () => @splice.splice_docx(aliased_bytes, @splice.SplicePlan::new()),
    "the package holds case-equivalent zip entries 'a.xml' and 'A.XML'",
  )
  let case_source = @mbtzip.Archive::new()
  case_source.add("word/document.xml", @utf8.encode("<r/>"))
  let case_source_bytes = @mbtzip.write(case_source)
  let wrong_case_edit = @splice.SplicePlan::new()
  wrong_case_edit.edit_part(
    "WORD/DOCUMENT.XML",
    @splice.span_edit(start=0, end=0, b""),
  )
  expect_splice_failure(
    () => @splice.splice_docx(case_source_bytes, wrong_case_edit),
    "the splice plan must use exact source spelling 'word/document.xml'",
  )
  let existing_alias = @splice.SplicePlan::new()
  existing_alias.add_part("WORD/DOCUMENT.XML", @utf8.encode("<x/>"))
  expect_splice_failure(
    () => @splice.splice_docx(case_source_bytes, existing_alias),
    "the splice plan adds 'WORD/DOCUMENT.XML', case-equivalent to existing part 'word/document.xml'",
  )
  let planned_aliases = @splice.SplicePlan::new()
  planned_aliases.add_part("new.xml", @utf8.encode("<n/>"))
  expect_splice_failure(
    () => planned_aliases.add_part("NEW.XML", @utf8.encode("<n2/>")),
    "the splice plan already adds case-equivalent part 'new.xml'",
  )
  // Directory records have physical ZIP identity, not case-insensitive OPC
  // Part identity. Distinct spellings must survive edits exactly.
  let directories = @mbtzip.Archive::new()
  directories.add("word/", b"", compression=Store, data_descriptor=false)
  directories.add("WORD/", b"", compression=Store, data_descriptor=false)
  directories.add(
    "a.xml",
    @utf8.encode("<r/>"),
    compression=Store,
    data_descriptor=false,
  )
  let directory_bytes = @mbtzip.write(directories)
  let directory_plan = @splice.SplicePlan::new()
  directory_plan.edit_part(
    "a.xml",
    @splice.span_edit(start=1, end=2, @utf8.encode("s")),
  )
  let directory_output = @splice.splice_docx(directory_bytes, directory_plan)
  let directory_result = @mbtzip.read(directory_output)
  assert_eq(directory_result.get("word/"), Some(b""))
  assert_eq(directory_result.get("WORD/"), Some(b""))
  assert_eq(directory_result.get("a.xml"), Some(@utf8.encode("<s/>")))
  // In this controlled Store fixture, the two empty five-byte directory
  // names occupy 35-byte local records and 51-byte central records.
  assert_eq(directory_bytes[0:70], directory_output[0:70])
  let directory_central = @zip_fixture.classic_central_directory_offset(
    directory_bytes,
  )
  let output_central = @zip_fixture.classic_central_directory_offset(
    directory_output,
  )
  assert_eq(
    directory_bytes[directory_central:directory_central + 102],
    directory_output[output_central:output_central + 102],
  )

  let duplicate_directories = @mbtzip.Archive::new()
  duplicate_directories.add("word/", b"")
  duplicate_directories.add("word/", b"")
  duplicate_directories.add("a.xml", @utf8.encode("<r/>"))
  let duplicate_directory_bytes = @mbtzip.write(duplicate_directories)
  expect_splice_failure(
    () => {
      @splice.splice_docx(duplicate_directory_bytes, @splice.SplicePlan::new())
    },
    "the package holds duplicate zip entries named 'word/'",
  )
  // A UTF-16 part (BOM) cannot be spliced.
  let utf16 = @mbtzip.Archive::new()
  utf16.add("w.xml", b"\xFF\xFE<\x00r\x00/\x00>\x00")
  let utf16_bytes = @mbtzip.write(utf16)
  let plan16 = @splice.SplicePlan::new()
  plan16.edit_part("w.xml", @splice.span_edit(start=0, end=0, b""))
  expect_splice_failure(
    () => @splice.splice_docx(utf16_bytes, plan16),
    "'w.xml' is UTF-16 encoded",
  )
  // A declared non-UTF-8 encoding fails closed even in ASCII bytes.
  let latin = @mbtzip.Archive::new()
  latin.add(
    "l.xml",
    @utf8.encode("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><r/>"),
  )
  let latin_bytes = @mbtzip.write(latin)
  let plan_latin = @splice.SplicePlan::new()
  plan_latin.edit_part("l.xml", @splice.span_edit(start=0, end=0, b""))
  expect_splice_failure(
    () => @splice.splice_docx(latin_bytes, plan_latin),
    "'l.xml' declares a non-UTF-8 encoding",
  )
  // Declared UTF-8 (any case) is accepted.
  let utf8_decl = @mbtzip.Archive::new()
  utf8_decl.add(
    "u.xml",
    @utf8.encode("<?xml version=\"1.0\" encoding=\"UTF-8\"?><r></r>"),
  )
  let utf8_bytes = @mbtzip.write(utf8_decl)
  let plan_utf8 = @splice.SplicePlan::new()
  let source = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><r></r>"
  guard source.find("</r>") is Some(at)
  plan_utf8.edit_part(
    "u.xml",
    @splice.span_edit(start=at, end=at, @utf8.encode("<ok/>")),
  )
  let out = @mbtzip.read(@splice.splice_docx(utf8_bytes, plan_utf8))
  guard out.get("u.xml") is Some(u_bytes)
  inspect(
    @utf8.decode(u_bytes, ignore_bom=true).find("<ok/>") is Some(_),
    content="true",
  )
  // The declaration is part of the edited result's semantics, so changing a
  // valid UTF-8 source to a foreign declaration must be rejected as well.
  guard source.find("UTF-8") is Some(encoding_at)
  let rewritten_declaration = @splice.SplicePlan::new()
  rewritten_declaration.edit_part(
    "u.xml",
    @splice.span_edit(
      start=encoding_at,
      end=encoding_at + "UTF-8".length(),
      @utf8.encode("ISO-8859-1"),
    ),
  )
  expect_splice_failure(
    () => @splice.splice_docx(utf8_bytes, rewritten_declaration),
    "'u.xml' declares a non-UTF-8 encoding",
  )
}

///|
test "L0 review round 1: malformed XML declarations fail closed" {
  // An UNQUOTED encoding value: the old gate returned None (fail-open)
  // and the XML belt skips declarations entirely — the tri-state parse
  // must reject it before any splice.
  let malformed = @mbtzip.Archive::new()
  malformed.add(
    "m.xml",
    @utf8.encode("<?xml version=\"1.0\" encoding=ISO-8859-1?><r></r>"),
  )
  let malformed_bytes = @mbtzip.write(malformed)
  let plan = @splice.SplicePlan::new()
  plan.edit_part("m.xml", @splice.span_edit(start=0, end=0, b""))
  expect_splice_failure(
    () => @splice.splice_docx(malformed_bytes, plan),
    "'m.xml' has a malformed XML declaration",
  )
  // An unterminated encoding value is equally malformed.
  let unterminated = @mbtzip.Archive::new()
  unterminated.add(
    "u.xml",
    @utf8.encode("<?xml version=\"1.0\" encoding=\"UTF-8?><r></r>"),
  )
  let unterminated_bytes = @mbtzip.write(unterminated)
  let plan2 = @splice.SplicePlan::new()
  plan2.edit_part("u.xml", @splice.span_edit(start=0, end=0, b""))
  expect_splice_failure(
    () => @splice.splice_docx(unterminated_bytes, plan2),
    "'u.xml' has a malformed XML declaration",
  )
}

///|
test "L0 review round 2: 'encoding' inside a quoted value cannot fool the gate" {
  // The declaration's VERSION value contains encoding='UTF-8'; the real
  // encoding is ISO-8859-1 and must still be rejected (the sniffer
  // walks pseudo-attributes, never the inside of values).
  let devious = @mbtzip.Archive::new()
  devious.add(
    "d.xml",
    @utf8.encode(
      "<?xml version=\"encoding='UTF-8'\" encoding=\"ISO-8859-1\"?><r></r>",
    ),
  )
  let devious_bytes = @mbtzip.write(devious)
  let plan = @splice.SplicePlan::new()
  plan.edit_part("d.xml", @splice.span_edit(start=0, end=0, b""))
  expect_splice_failure(
    () => @splice.splice_docx(devious_bytes, plan),
    "'d.xml' declares a non-UTF-8 encoding",
  )
  // The canonical declaration (with standalone) still passes untouched.
  let canonical = @mbtzip.Archive::new()
  let canonical_source = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><r></r>"
  canonical.add("c.xml", @utf8.encode(canonical_source))
  let canonical_bytes = @mbtzip.write(canonical)
  let plan_ok = @splice.SplicePlan::new()
  guard canonical_source.find("</r>") is Some(at)
  plan_ok.edit_part(
    "c.xml",
    @splice.span_edit(start=at, end=at, @utf8.encode("<fine/>")),
  )
  let out = @mbtzip.read(@splice.splice_docx(canonical_bytes, plan_ok))
  guard out.get("c.xml") is Some(c_bytes)
  inspect(
    @utf8.decode(c_bytes, ignore_bom=true).find("<fine/>") is Some(_),
    content="true",
  )
  // A declaration with no encoding at all also passes.
  let plain = @mbtzip.Archive::new()
  plain.add("p.xml", @utf8.encode("<?xml version=\"1.0\"?><r></r>"))
  let plain_bytes = @mbtzip.write(plain)
  let plan_plain = @splice.SplicePlan::new()
  guard "<?xml version=\"1.0\"?><r></r>".find("</r>") is Some(plain_at)
  plan_plain.edit_part(
    "p.xml",
    @splice.span_edit(start=plain_at, end=plain_at, @utf8.encode("<ok/>")),
  )
  let plain_out = @mbtzip.read(@splice.splice_docx(plain_bytes, plan_plain))
  inspect(plain_out.get("p.xml") is Some(_), content="true")
}

///|
test "L0 review round 3: the declaration walker enforces the XML grammar" {
  fn reject(source : String, name : String) -> Unit raise {
    let archive = @mbtzip.Archive::new()
    archive.add(name, @utf8.encode(source))
    let bytes = @mbtzip.write(archive)
    let plan = @splice.SplicePlan::new()
    plan.edit_part(name, @splice.span_edit(start=0, end=0, b""))
    expect_splice_failure(
      () => @splice.splice_docx(bytes, plan),
      "'\{name}' has a malformed XML declaration",
    )
  }
  // No whitespace BETWEEN pseudo-attributes (would hide a devious
  // first-encoding under last-wins).
  reject("<?xml version=\"1.0\"encoding=\"UTF-8\"?><r></r>", "b.xml")
  // An empty declaration has no VersionInfo.
  reject("<?xml?>", "c.xml")
  reject("<?xml ?>", "d.xml")
  // Duplicate encoding pseudo-attributes are malformed, not last-wins.
  reject(
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" encoding=\"UTF-8\"?><r></r>",
    "e.xml",
  )
  // Prefix-sharing processing-instruction targets are not declarations.
  let pi = @mbtzip.Archive::new()
  let pi_source = "<?xml-stylesheet type=\"text/xsl\" href=\"style.xsl\"?><?xmlversion version=\"1.0\"?><r></r>"
  pi.add("pi.xml", @utf8.encode(pi_source))
  let pi_bytes = @mbtzip.write(pi)
  let pi_plan = @splice.SplicePlan::new()
  guard pi_source.find("</r>") is Some(pi_at)
  pi_plan.edit_part(
    "pi.xml",
    @splice.span_edit(start=pi_at, end=pi_at, @utf8.encode("<ok/>")),
  )
  guard @mbtzip.read(@splice.splice_docx(pi_bytes, pi_plan)).get("pi.xml")
    is Some(pi_result)
  inspect(
    @utf8.decode(pi_result, ignore_bom=true),
    content="<?xml-stylesheet type=\"text/xsl\" href=\"style.xsl\"?><?xmlversion version=\"1.0\"?><r><ok/></r>",
  )
}

///|
test "L0 review round 4: the declaration grammar is positional" {
  fn reject(source : String, name : String) -> Unit raise {
    let archive = @mbtzip.Archive::new()
    archive.add(name, @utf8.encode(source))
    let bytes = @mbtzip.write(archive)
    let plan = @splice.SplicePlan::new()
    plan.edit_part(name, @splice.span_edit(start=0, end=0, b""))
    expect_splice_failure(
      () => @splice.splice_docx(bytes, plan),
      "'\{name}' has a malformed XML declaration",
    )
  }
  // VersionInfo is required and FIRST.
  reject("<?xml encoding=\"UTF-8\"?><r></r>", "a.xml")
  reject("<?xml bogus=\"x\"?><r></r>", "b.xml")
  reject("<?xml encoding=\"UTF-8\" version=\"1.0\"?><r></r>", "c.xml")
  // Nothing follows standalone; nothing unknown anywhere.
  reject(
    "<?xml version=\"1.0\" standalone=\"yes\" encoding=\"UTF-8\"?><r></r>", "d.xml",
  )
  reject("<?xml version=\"1.0\" version=\"1.1\"?><r></r>", "e.xml")
  // version + standalone WITHOUT encoding is legal and passes.
  let fine = @mbtzip.Archive::new()
  let fine_source = "<?xml version=\"1.0\" standalone=\"yes\"?><r></r>"
  fine.add("f.xml", @utf8.encode(fine_source))
  let fine_bytes = @mbtzip.write(fine)
  let plan_fine = @splice.SplicePlan::new()
  guard fine_source.find("</r>") is Some(at)
  plan_fine.edit_part(
    "f.xml",
    @splice.span_edit(start=at, end=at, @utf8.encode("<ok/>")),
  )
  inspect(
    @mbtzip.read(@splice.splice_docx(fine_bytes, plan_fine)).get("f.xml")
    is Some(_),
    content="true",
  )
}

///|
test "L0 review round 5: giant encoding labels stay bounded" {
  // The declaration gate must scan this once without copying the
  // attacker-controlled value or constructing it again for diagnostics.
  let source = "<?xml version=\"1.0\" encoding=\"" +
    "A".repeat(1_000_000) +
    "\"?><r></r>"
  let archive = @mbtzip.Archive::new()
  archive.add("bounded.xml", @utf8.encode(source))
  let archive_bytes = @mbtzip.write(archive)
  let plan = @splice.SplicePlan::new()
  plan.edit_part("bounded.xml", @splice.span_edit(start=0, end=0, b""))
  expect_splice_failure(
    () => @splice.splice_docx(archive_bytes, plan),
    "'bounded.xml' declares a non-UTF-8 encoding",
  )
}

///|
test "default splice budget accepts ordinary namespace-dense OOXML" {
  let wml = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  let source = StringBuilder()
  source.write_string("<w:document xmlns:w=\"\{wml}\"><w:body>")
  for _ in 0..<50 {
    source.write_string("<w:p/>")
  }
  source.write_string("</w:body></w:document>")
  let source_text = source.to_string()
  let archive = @mbtzip.Archive::new()
  archive.add("word/document.xml", @utf8.encode(source_text))
  let plan = @splice.SplicePlan::new()
  guard source_text.find("</w:body>") is Some(insert_at)
  plan.edit_part(
    "word/document.xml",
    @splice.span_edit(start=insert_at, end=insert_at, b""),
  )
  let result = @mbtzip.read(@splice.splice_docx(@mbtzip.write(archive), plan))
  guard result.get("word/document.xml") is Some(actual)
  assert_eq(@utf8.decode(actual, ignore_bom=true), source_text)
}
