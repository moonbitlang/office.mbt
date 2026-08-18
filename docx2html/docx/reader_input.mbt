// PR 1 of the reader unification (#434): the reader's INPUT abstraction.
//
// BodyReader's semantic half currently reads `XmlElement` directly, which is
// why it cannot carry provenance: the tolerant tree has no byte offsets, and
// nothing in the read path could hold them if it did. `ReaderNode` is the
// seam. Today it wraps `XmlElement` and nothing else -- every accessor is a
// mechanical forward, and behaviour is identical by construction. PR 3 joins
// this tree with the physical scan and PR 4 threads `SourceElementId`
// through the field below; the read path itself will not change shape again.
//
// Scope: the body-reading recursive component only. Part readers (styles,
// numbering, comments, relationships) parse their own parts and never flow
// through body reading; they keep reading `XmlElement` until their own
// migration step.

///|
/// One element as the body reader sees it.
priv struct ReaderNode {
  element : XmlElement
}

///|
fn ReaderNode::of(element : XmlElement) -> ReaderNode {
  { element, }
}

///|
fn ReaderNode::name(self : ReaderNode) -> String {
  self.element.name
}

///|
fn ReaderNode::attribute(self : ReaderNode, name : String) -> String? {
  self.element.attributes.get(name)
}

///|
/// The element's flattened text, exactly as `XmlElement::text` reads it.
fn ReaderNode::text(self : ReaderNode) -> String raise DocxError {
  self.element.text()
}

///|
fn ReaderNode::first(self : ReaderNode, name : String) -> ReaderNode? {
  match self.element.first(name) {
    Some(found) => Some(ReaderNode::of(found))
    None => None
  }
}

///|
fn ReaderNode::first_or_empty(self : ReaderNode, name : String) -> ReaderNode {
  ReaderNode::of(self.element.first_or_empty(name))
}

///|
/// The element children, in order. Raw text children are dropped here the
/// way every read-path loop already dropped them; the one consumer of text
/// content goes through `text()`.
fn ReaderNode::element_children(self : ReaderNode) -> Array[ReaderNode] {
  let out : Array[ReaderNode] = []
  for child in self.element.children {
    match child {
      XmlElement(element) => out.push(ReaderNode::of(element))
      XmlText(_) => ()
    }
  }
  out
}

///|
fn ReaderNode::attribute_or(
  self : ReaderNode,
  name : String,
  default : String,
) -> String {
  self.element.attributes.get_or_default(name, default)
}

///|
/// Every descendant-or-self element named `name`, in document order --
/// `XmlElement::elements_by_tag_name`, wrapped.
fn ReaderNode::elements_by_tag_name(
  self : ReaderNode,
  name : String,
) -> Array[ReaderNode] {
  self.element.elements_by_tag_name(name).map(ReaderNode::of)
}
