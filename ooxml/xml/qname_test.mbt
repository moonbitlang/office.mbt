///|
test "QName equality ignores prefix" {
  // The prefix isn't part of QName at all — same uri+local always equal.
  let a1 = @xml.QName::new("http://example.org/ns", "rect")
  let a2 = @xml.QName::new("http://example.org/ns", "rect")
  debug_inspect(a1 == a2, content="true")
}

///|
test "QName distinguishes uri and local name" {
  let a = @xml.QName::new("http://x", "name")
  let b = @xml.QName::new("http://y", "name")
  let c = @xml.QName::new("http://x", "other")
  debug_inspect(a != b, content="true")
  debug_inspect(a != c, content="true")
}

///|
test "unqualified vs qualified" {
  let q = @xml.QName::new("http://x", "n")
  let u = @xml.QName::unqualified("n")
  debug_inspect(q.is_qualified(), content="true")
  debug_inspect(!u.is_qualified(), content="true")
  debug_inspect(q != u, content="true")
}
