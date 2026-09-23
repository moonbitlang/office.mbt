// Modified for office.mbt: follow the workspace warning conventions.

///|
test "XmlElement::new wraps fields verbatim" {
  let name = @xml.QName::new("http://x", "root")
  let attrs = [(@xml.QName::unqualified("a"), "1")]
  let children = [@xml.XmlNode::Text("hello")]
  let e = @xml.XmlElement::new(name, attrs, children)
  debug_inspect(e.name == name, content="true")
  debug_inspect(e.attributes.length(), content="1")
  debug_inspect(e.children.length(), content="1")
}

///|
test "XmlElement equality is structural" {
  let q = @xml.QName::unqualified("p")
  let a = @xml.XmlElement::new(q, [], [Text("x")])
  let b = @xml.XmlElement::new(q, [], [Text("x")])
  let c = @xml.XmlElement::new(q, [], [Text("y")])
  debug_inspect(a == b, content="true")
  debug_inspect(a != c, content="true")
}

///|
test "XmlNode variants are distinguishable" {
  let t = @xml.XmlNode::Text("foo")
  let c = @xml.XmlNode::CData("foo")
  debug_inspect(t != c, content="true")
}
