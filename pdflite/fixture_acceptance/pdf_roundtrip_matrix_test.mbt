///|
priv enum FixtureAcceptanceRoundTripMode {
  RoundTripClassic
  RoundTripXrefStream
  RoundTripCompressedXrefStream
}

///|
fn FixtureAcceptanceRoundTripMode::name(
  self : FixtureAcceptanceRoundTripMode,
) -> String {
  match self {
    RoundTripClassic => "classic"
    RoundTripXrefStream => "xref-stream"
    RoundTripCompressedXrefStream => "compressed-xref-stream"
  }
}

///|
fn FixtureAcceptanceRoundTripMode::write(
  self : FixtureAcceptanceRoundTripMode,
  document : @pdflite.PdfDocument,
) -> Bytes raise @core.PdfError {
  match self {
    RoundTripClassic => @pdflite.pdf_write_document(document)
    RoundTripXrefStream =>
      @pdflite.pdf_write_document_with_xref_stream(document)
    RoundTripCompressedXrefStream =>
      @pdflite.pdf_write_document_with_compressed_xref_stream(document)
  }
}

///|
let fixture_acceptance_roundtrip_modes_for_test : Array[
  FixtureAcceptanceRoundTripMode,
] = [RoundTripClassic, RoundTripXrefStream, RoundTripCompressedXrefStream]

///|
let fixture_acceptance_checked_in_roundtrip_fixtures_for_test : Array[
  (String, Int),
] = [
  ("fixtures/camlpdf/logo.pdf", 1),
  ("fixtures/camlpdf/introduction_to_camlpdf.pdf", 10),
  ("markdown/fixtures/pandoc_latin.pdf", 2),
  ("markdown/fixtures/pandoc_cjk.pdf", 1),
]

///|
fn fixture_acceptance_assert_roundtrip_shape_for_test(
  path : String,
  mode : FixtureAcceptanceRoundTripMode,
  reparsed : @pdflite.PdfDocument,
  expected_pages : Int,
) -> Unit raise {
  let context = path + " via " + mode.name()
  let actual_pages = reparsed.endpage()
  if actual_pages != expected_pages {
    fail(
      context +
      " produced " +
      actual_pages.to_string() +
      " pages, expected " +
      expected_pages.to_string(),
    )
  }
}

///|
async test "checked-in PDF fixture matrix roundtrips through writer modes" {
  for fixture in fixture_acceptance_checked_in_roundtrip_fixtures_for_test {
    let (path, expected_pages) = fixture
    let bytes = fixture_acceptance_bytes_for_test(path)
    let original = try! @pdflite.pdf_read_document_from_bytes(bytes)
    let original_pages = try! original.endpage()
    if original_pages != expected_pages {
      fail(
        path +
        " has " +
        original_pages.to_string() +
        " pages, expected " +
        expected_pages.to_string(),
      )
    }
    for mode in fixture_acceptance_roundtrip_modes_for_test {
      let rewritten = try! mode.write(original)
      if rewritten.length() == 0 {
        fail(path + " via " + mode.name() + " produced empty output")
      }
      let reparsed = try! @pdflite.pdf_read_document_from_bytes(rewritten)
      try! fixture_acceptance_assert_roundtrip_shape_for_test(
        path, mode, reparsed, expected_pages,
      )
    }
  }
}
