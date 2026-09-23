// Modified for office.mbt: follow the workspace warning conventions.
// Speaker-notes parser tests.

///|
let pml_ns : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
let dml_ns : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
/// UTF-8 encode a `String` to bytes. Mirrors the helper in `@slide` tests
/// — duplicated here because every `*_test.mbt` in a package compiles into
/// its own blackbox-test package, and `@slide`'s helper is private to that
/// test package.

///|
/// A trimmed but realistic notes slide: the two canonical placeholders
/// (slide image + body) plus a body paragraph carrying the actual notes
/// text. Trailing `<p:custDataLst>` exercises the lossless-extension path.
fn typical_notes() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:notes xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld name=\"Slide 1 Notes\">" +
    "<p:spTree>" +
    "<p:nvGrpSpPr>" +
    "<p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/>" +
    "</p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    // Slide Image placeholder
    "<p:sp>" +
    "<p:nvSpPr>" +
    "<p:cNvPr id=\"2\" name=\"Slide Image Placeholder 1\"/>" +
    "<p:cNvSpPr><a:spLocks noGrp=\"1\" noRot=\"1\" noChangeAspect=\"1\"/></p:cNvSpPr>" +
    "<p:nvPr><p:ph type=\"sldImg\"/></p:nvPr>" +
    "</p:nvSpPr>" +
    "<p:spPr/>" +
    "</p:sp>" +
    // Notes body placeholder
    "<p:sp>" +
    "<p:nvSpPr>" +
    "<p:cNvPr id=\"3\" name=\"Notes Placeholder 2\"/>" +
    "<p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>" +
    "<p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr>" +
    "</p:nvSpPr>" +
    "<p:spPr/>" +
    "<p:txBody>" +
    "<a:bodyPr/><a:lstStyle/>" +
    "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>Speaker notes here.</a:t></a:r></a:p>" +
    "</p:txBody>" +
    "</p:sp>" +
    "</p:spTree>" +
    "</p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
    "<p:custDataLst><p:tags r:id=\"rId1\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"/></p:custDataLst>" +
    "</p:notes>"
  @oxml.string_to_bytes(xml)
}

// --- happy path ---

///|
test "parse: notes name and shape count" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  debug_inspect(notes.name, content="\"Slide 1 Notes\"")
  debug_inspect(notes.shapes.length(), content="2") // sldImg + body placeholders
}

///|
test "parse: clrMapOvr defaults to MasterMapping" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  debug_inspect(notes.clr_map_override is MasterMapping, content="true")
}

///|
test "parse: slide-image placeholder metadata" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  match notes.shapes[0] {
    AutoShape(s) => {
      debug_inspect(s.id, content="2")
      debug_inspect(s.name, content="\"Slide Image Placeholder 1\"")
      let ph = s.placeholder.unwrap()
      debug_inspect(ph.ph_type, content="\"sldImg\"")
      debug_inspect(ph.idx, content="0") // missing idx defaults to 0
    }
    _ => panic()
  }
}

///|
test "parse: body placeholder carries the notes paragraph text" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  match notes.shapes[1] {
    AutoShape(s) => {
      let ph = s.placeholder.unwrap()
      debug_inspect(ph.ph_type, content="\"body\"")
      debug_inspect(ph.idx, content="1")
      let body = s.text_body.unwrap()
      debug_inspect(body.plain_text(), content="\"Speaker notes here.\"")
    }
    _ => panic()
  }
}

// --- lossless preservation ---

///|
test "parse: <p:custDataLst> rides on the slide-level extension" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  // The slide-level extension captures the root-group metadata
  // (`<p:nvGrpSpPr>` + `<p:grpSpPr>`) followed by the `<p:custDataLst>`
  // sibling of `<p:cSld>` / `<p:clrMapOvr>` — three elements in source
  // order.  Cross-section ordering inside `extension` is not part of the
  // contract; the lookup uses local-name membership instead.
  debug_inspect(notes.extension.length(), content="3")
  let names = notes.extension.map(e => e.name.local_name)
  debug_inspect(names.contains("custDataLst"), content="true")
}

///|
test "parse: <p:extLst> alongside <p:clrMapOvr> is preserved" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:notes xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:extLst><p:ext uri=\"{ABCD}\"/></p:extLst>" +
    "</p:notes>"
  let notes = @notes.NotesSlide::parse(@oxml.string_to_bytes(xml))
  debug_inspect(notes.shapes.length(), content="0")
  // 3 = nvGrpSpPr + grpSpPr (root-group metadata) + extLst sibling.
  debug_inspect(notes.extension.length(), content="3")
  let names = notes.extension.map(e => e.name.local_name)
  debug_inspect(names.contains("extLst"), content="true")
}

// --- error paths ---

///|
test "parse: wrong root element raises SlideFailure" {
  // The shared `Slide::parse_with_root` checks the root element before
  // any notes-specific logic runs, so the underlying SlideError surfaces
  // through SlideFailure rather than the local Malformed variant.
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  try @notes.NotesSlide::parse(@oxml.string_to_bytes(xml)) catch {
    SlideFailure(_) => ()
    _ => fail("expected SlideFailure")
  } noraise {
    _ => fail("expected SlideFailure")
  }
}

///|
test "parse: empty bytes raises SlideFailure" {
  try @notes.NotesSlide::parse(FixedArray::make(0, b'\x00')) catch {
    SlideFailure(_) => ()
    _ => fail("expected SlideFailure")
  } noraise {
    _ => fail("expected SlideFailure")
  }
}
