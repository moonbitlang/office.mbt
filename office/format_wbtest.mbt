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
      "1bad:value",
    ] {
    if is_valid_uri_reference(value) {
      fail("expected an invalid URI reference: \{value}")
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
