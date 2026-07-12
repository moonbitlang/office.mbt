///|
test "URI references follow RFC 3986 component grammar" {
  for
    value in [
      "https://example.com/a%20b?q=x/y&v=1#frag", "urn:isbn:9780141036144", "//example.com/path",
      "/relative/path", "../relative/path", "?query", "#fragment", "https://user:pass@[2001:db8::1]:443/path",
      "http://[::ffff:192.0.2.1]/", "http://[1:2:3:4:5:6:7:8]/", "http://[v1.fe80]/",
      "file:///C:/path",
    ] {
    if !is_valid_uri_reference(value) {
      fail("expected a valid URI reference: \{value}")
    }
  }
  for
    value in [
      "https://example.com/a[b]", "https://example.com:port/path", "https://user@@example.com/path",
      "https://[2001:db8:::1]/path", "https://[1:2:3:4:5:6:7]/path", "https://[1:2:3:4:5:6:7:8:9]/path",
      "https://[::ffff:192.168.001.1]/path", "https://[v1.]/path", "https://example.com/%ZZ",
      "https://example.com/a b", "https://example.com/{bad}", "https://example.com/#one#two",
      "https://例え.テスト/資料", "1bad:value",
    ] {
    if is_valid_uri_reference(value) {
      fail("expected an invalid URI reference: \{value}")
    }
  }
}

///|
test "IRI references follow RFC 3987 component grammar" {
  for
    value in [
      "https://例え.テスト/資料/文書.docx?名前=値#節", "../資料/文書.docx?名前=値",
      "https://利用者@example.com/文書", "file://server/共有/文書.docx",
    ] {
    if !is_valid_iri_reference(value) {
      fail("expected a valid IRI reference: \{value}")
    }
  }
  for
    value in [
      "https://example.com/a b", "https://example.com/{bad}", "https://example.com/%ZZ",
      "https://example.com/文書#one#two", "https://example.com/\u{e000}", "https://\u{e000}.example/path",
      "../資料/文書?bad=\u{7f}",
    ] {
    if is_valid_iri_reference(value) {
      fail("expected an invalid IRI reference: \{value}")
    }
  }
  if !is_valid_iri_reference("https://example.com/文書?private=\u{e000}") {
    fail("expected RFC 3987 iprivate to be accepted in a query")
  }
}

///|
test "Office file IRIs support drive and UNC paths" {
  for
    value in [
      "file:///C:\\Documents\\資料.docx", "file:///C:/Documents/資料.docx", "file:///\\\\server\\共有\\文書.docx",
      "FILE:///\\\\server/共有/文書.docx",
    ] {
    if !is_valid_office_windows_file_iri(value) {
      fail("expected a valid Office file IRI: \{value}")
    }
  }
  for
    value in [
      "file:///\\\\server", "file:///\\\\server\\", "file:///\\\\\\share\\file.docx",
      "file:///\\\\server\\bad{share}\\file.docx", "file:///\\\\server\\share\\bad%ZZ",
    ] {
    if is_valid_office_windows_file_iri(value) {
      fail("expected an invalid Office file IRI: \{value}")
    }
  }
}

///|
test "content types follow media-type grammar" {
  for
    value in [
      "application/xml", "Application/Vnd.Example+Xml", "text/plain; charset=utf-8",
      "text/plain ; charset=\"utf-8\"; note=\"a b\"", "application/x-custom!#$%&'*+-.^_`|~",
    ] {
    if !is_valid_media_type(value) {
      fail("expected a valid media type: \{value}")
    }
  }
  for
    value in [
      "", "not a media type", "application", "/xml", "application/", "application/xml ",
      "application/xml;", "application/xml; charset", "application/xml; charset=",
      "application/xml; charset=\"unterminated", "application/x[bad]",
    ] {
    if is_valid_media_type(value) {
      fail("expected an invalid media type: \{value}")
    }
  }
}
