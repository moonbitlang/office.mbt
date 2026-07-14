///|
fn tiny_package() -> Bytes raise {
  let archive = @mbtzip.Archive::new()
  archive.add("a.xml", @utf8.encode("<r><a/></r>"))
  archive.add("b.bin", b"\x00\x01\x02\x03binary payload", compression=Store)
  archive.add("c.xml", @utf8.encode("<c/>"))
  @mbtzip.write(archive)
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
        | MissingPart(message~) => message
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
    "could not repack the package",
  )
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
    "'l.xml' declares encoding 'ISO-8859-1'",
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
    "'d.xml' declares encoding 'ISO-8859-1'",
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
  // No whitespace after <?xml.
  reject("<?xmlversion=\"1.0\"?><r></r>", "a.xml")
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
