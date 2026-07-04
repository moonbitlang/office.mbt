///|
fn syntax_depth_nested_bytes(open : Byte, close : Byte, count : Int) -> Bytes {
  let out : Array[Byte] = []
  for _ in 0..<count {
    out.push(open)
  }
  for _ in 0..<count {
    out.push(close)
  }
  Bytes::from_array(out)
}

///|
test "object parser rejects arrays nested deeper than 512" {
  let deep = syntax_depth_nested_bytes(b'[', b']', 600)
  let parsed : Result[@syntax.PdfObject, Error] = try
    @syntax.pdf_parse_object_from_view(deep)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard parsed is Err(@core.PdfError::ParseObjectExpected) else {
    fail("expected @core.PdfError::ParseObjectExpected")
  }
}

///|
test "object parser rejects dictionaries nested deeper than 512" {
  let out : Array[Byte] = []
  for _ in 0..<600 {
    out.push(b'<')
    out.push(b'<')
    out.push(b'/')
    out.push(b'A')
    out.push(b' ')
  }
  for _ in 0..<600 {
    out.push(b'>')
    out.push(b'>')
  }
  let parsed : Result[@syntax.PdfObject, Error] = try
    @syntax.pdf_parse_object_from_view(Bytes::from_array(out))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard parsed is Err(@core.PdfError::ParseObjectExpected) else {
    fail("expected @core.PdfError::ParseObjectExpected")
  }
}

///|
test "object parser accepts moderately nested arrays" {
  let shallow = syntax_depth_nested_bytes(b'[', b']', 100)
  let parsed = @syntax.pdf_parse_object_from_view(shallow)
  guard parsed is PdfArray(_) else { fail("expected array") }
}
