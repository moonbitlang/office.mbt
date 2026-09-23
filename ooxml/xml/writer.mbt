///|
/// QName adapter for Milky2018/xml's checked writer. A pending start tag
/// collects incremental attributes until content or an end tag is written.
pub struct XmlWriter {
  priv writer : @parser.Writer
  priv prefix_for_uri : Map[String, String]
  priv stack : Array[String]
  priv attributes : Array[(String, String)]
  priv mut pending : Bool
}

///|
pub fn XmlWriter::new() -> XmlWriter {
  {
    writer: @parser.Writer::new(),
    prefix_for_uri: Map([]),
    stack: [],
    attributes: [],
    pending: false,
  }
}

///|
/// Bind a URI to its output prefix. Emit its declaration separately with
/// `namespace_attr` or `default_namespace_attr`.
pub fn XmlWriter::bind_namespace(
  self : XmlWriter,
  prefix : String,
  uri : String,
) -> Unit {
  self.prefix_for_uri[uri] = prefix
}

///|
/// Write the Office XML declaration before any element. Repeated or misplaced
/// declarations raise `WriterMisuse`.
pub fn XmlWriter::xml_declaration(self : XmlWriter) -> Unit raise XmlError {
  if !self.stack.is_empty() {
    raise WriterMisuse("XML declaration must precede the root element")
  }
  // The backend exposes declarations through write_event; its Event type
  // is read-only, so obtain the declaration through its public reader.
  let reader = @parser.Reader::from_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
  )
  let declaration = reader.read_event() catch {
    error => raise WriterMisuse(@debug.to_string(error))
  }
  self.writer.write_event(declaration) catch {
    error => raise wrap_writer_error(error)
  }
}

///|
/// Begin an element, collecting attributes until its first child or content.
pub fn XmlWriter::start_element(
  self : XmlWriter,
  name : QName,
) -> Unit raise XmlError {
  let qualified = self.qualified_name(name)
  self.flush_start_tag(empty=false)
  self.stack.push(qualified)
  self.pending = true
}

///|
/// Add an attribute to the pending start tag, preserving insertion order.
/// The backend validates and escapes attributes when the tag is emitted.
pub fn XmlWriter::attribute(
  self : XmlWriter,
  name : QName,
  value : String,
) -> Unit raise XmlError {
  if !self.pending {
    raise WriterMisuse("attribute() called outside an open start tag")
  }
  self.attributes.push((self.qualified_name(name), value))
}

///|
pub fn XmlWriter::namespace_attr(
  self : XmlWriter,
  prefix : String,
  uri : String,
) -> Unit raise XmlError {
  self.attribute(QName::unqualified("xmlns:" + prefix), uri)
}

///|
pub fn XmlWriter::default_namespace_attr(
  self : XmlWriter,
  uri : String,
) -> Unit raise XmlError {
  self.attribute(QName::unqualified("xmlns"), uri)
}

///|
pub fn XmlWriter::text(self : XmlWriter, text : String) -> Unit raise XmlError {
  if self.stack.is_empty() {
    raise WriterMisuse("text() called with no element open")
  }
  self.flush_start_tag(empty=false)
  self.writer.text(text) catch {
    error => raise wrap_writer_error(error)
  }
}

///|
pub fn XmlWriter::cdata(self : XmlWriter, text : String) -> Unit raise XmlError {
  if self.stack.is_empty() {
    raise WriterMisuse("cdata() called with no element open")
  }
  self.flush_start_tag(empty=false)
  self.writer.cdata(text) catch {
    error => raise wrap_writer_error(error)
  }
}

///|
/// Close the current element, using an empty tag when it has no content.
pub fn XmlWriter::end_element(self : XmlWriter) -> Unit raise XmlError {
  guard self.stack.last() is Some(name) else {
    raise WriterMisuse("end_element() with no element open")
  }
  if self.pending {
    self.flush_start_tag(empty=true)
  } else {
    self.writer.end_element(name) catch {
      error => raise wrap_writer_error(error)
    }
  }
  self.stack.pop() |> ignore
}

///|
/// Return a complete document, rejecting unclosed elements or a missing root.
pub fn XmlWriter::to_string(self : XmlWriter) -> String raise XmlError {
  if !self.stack.is_empty() {
    raise WriterMisuse("to_string() called with unclosed elements")
  }
  self.writer.to_string() catch {
    error => raise wrap_writer_error(error)
  }
}

///|
fn XmlWriter::flush_start_tag(
  self : XmlWriter,
  empty~ : Bool,
) -> Unit raise XmlError {
  if self.pending {
    let name = self.stack.last().unwrap()
    try {
      if empty {
        self.writer.empty_element(name, self.attributes)
      } else {
        self.writer.start_element(name, self.attributes)
      }
    } catch {
      error => raise wrap_writer_error(error)
    }
    self.attributes.clear()
    self.pending = false
  }
}

///|
fn XmlWriter::qualified_name(
  self : XmlWriter,
  name : QName,
) -> String raise XmlError {
  if name.uri.is_empty() {
    return name.local_name
  }
  match self.prefix_for_uri.get(name.uri) {
    Some("") => name.local_name
    Some(prefix) => prefix + ":" + name.local_name
    None => raise UnboundPrefix(name.uri)
  }
}

///|
fn wrap_writer_error(error : @parser.WriterError) -> XmlError {
  WriterMisuse(@debug.to_string(error))
}
