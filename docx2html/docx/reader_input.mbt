// The reader's INPUT abstraction (#434 PR 1, provenance-bearing since PR 4).
//
// `ReaderNode` is the seam between the tolerant DOM and the body reader:
// every accessor navigates a CACHED child tree built once per root, so a
// node's physical identity -- populated when the tree comes from the
// DOM<->physical join, `None` on plain tolerant reads and on synthetic
// `first_or_empty` misses -- survives every access path. Producers pass
// their input node as `ReaderTree.source`, which is how the effect stream
// carries provenance without any producer knowing about it.
//
// Scope: the body-reading recursive component only. Part readers (styles,
// numbering, comments, relationships) parse their own parts and never flow
// through body reading; they keep reading `XmlElement` until their own
// migration step.

///|
/// One element as the body reader sees it.
priv struct ReaderNode {
  element : XmlElement
  /// The paired physical identity when this tree came through the join;
  /// `None` on unjoined reads and on synthetic `first_or_empty` nodes.
  source_element_id : SourceElementId?
  /// The element children, wrapped once. Accessors navigate this cache --
  /// reconstructing wrappers from `element` would silently drop the
  /// identity.
  children : Array[ReaderNode]
}

///|
/// Wraps an unjoined tolerant tree: no physical identities anywhere.
fn ReaderNode::of(element : XmlElement) -> ReaderNode {
  let children : Array[ReaderNode] = []
  for child in element.children {
    match child {
      XmlElement(child_element) => children.push(ReaderNode::of(child_element))
      XmlText(_) => ()
    }
  }
  { element, source_element_id: None, children, }
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
/// The first DIRECT child element named `name`, cache-navigated so its
/// identity survives.
fn ReaderNode::first(self : ReaderNode, name : String) -> ReaderNode? {
  for child in self.children {
    if child.element.name == name {
      return Some(child)
    }
  }
  None
}

///|
/// The first direct child named `name`, or a SYNTHETIC empty node carrying
/// no physical identity -- the metadata-miss convention every reader
/// lookup uses.
fn ReaderNode::first_or_empty(self : ReaderNode, name : String) -> ReaderNode {
  match self.first(name) {
    Some(child) => child
    None =>
      {
        element: self.element.first_or_empty(name),
        source_element_id: None,
        children: [],
      }
  }
}

///|
/// The element children, in order. Raw text children were dropped at wrap
/// time the way every read-path loop already dropped them; the one
/// consumer of text content goes through `text()`. Callers never mutate
/// the returned array.
fn ReaderNode::element_children(self : ReaderNode) -> Array[ReaderNode] {
  self.children
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
/// Every DIRECT child element named `name`, in document order --
/// `XmlElement::elements_by_tag_name`, cache-navigated.
fn ReaderNode::elements_by_tag_name(
  self : ReaderNode,
  name : String,
) -> Array[ReaderNode] {
  let out : Array[ReaderNode] = []
  for child in self.children {
    if child.element.name == name {
      out.push(child)
    }
  }
  out
}
