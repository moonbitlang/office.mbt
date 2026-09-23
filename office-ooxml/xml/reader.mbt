///|
/// One reader event. Attributes on `StartElement` are reported in source
/// order; values are already entity-decoded.
pub(all) enum XmlEvent {
  StartElement(QName, Array[(QName, String)])
  EndElement(QName)
  Text(String)
  CData(String)
} derive(Debug)

///|
pub extend XmlEvent with @debug.Debug::{to_repr}

///|
pub extend XmlEvent with Show::{to_string, output}

///|
pub impl Show for XmlEvent with fn output(self, logger) {
  match self {
    StartElement(n, _) => {
      logger.write_string("StartElement(")
      logger.write_object(n)
      logger.write_string(")")
    }
    EndElement(n) => {
      logger.write_string("EndElement(")
      logger.write_object(n)
      logger.write_string(")")
    }
    Text(s) => {
      logger.write_string("Text(")
      logger.write_object(s)
      logger.write_string(")")
    }
    CData(s) => {
      logger.write_string("CData(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}

///|
/// Document-buffered, namespace-aware reader backed by Milky2018/xml.
pub struct XmlReader {
  priv reader : @parser.NamespaceReader
  priv mut pending : XmlEvent?
  priv mut buffered : XmlEvent?
  priv mut depth : Int
}

///|
pub fn XmlReader::new(input : String) -> XmlReader {
  {
    reader: @parser.NamespaceReader::from_string(input),
    pending: None,
    buffered: None,
    depth: 0,
  }
}

///|
fn resolved_name(name : @parser.XmlName) -> QName {
  QName::new(name.namespace_uri.unwrap_or(""), name.local_name)
}

///|
fn XmlReader::read_next(self : XmlReader) -> XmlEvent? raise XmlError {
  if self.pending is Some(event) {
    self.pending = None
    return Some(event)
  }
  while true {
    let event = self.reader.read_event() catch {
      At(error~, ..) =>
        match error {
          UnexpectedEof | InvalidSyntax([.. "unclosed element:", ..]) =>
            raise UnexpectedEof
          InvalidSyntax(message) if message.has_prefix("end tag mismatch:") =>
            raise MismatchedEndTag(message)
          UnmatchedTag(found~, ..) => raise MismatchedEndTag(found)
          InvalidSyntax([.. "undeclared namespace prefix: ", .. prefix]) =>
            raise UnboundPrefix(prefix.to_owned())
          _ => raise Malformed(error.to_string())
        }
    }
    match event.kind {
      Start(element) => {
        self.depth += 1
        return Some(
          StartElement(
            resolved_name(element.name),
            element.attributes.map(a => (resolved_name(a.name), a.value)),
          ),
        )
      }
      Empty(element) => {
        let name = resolved_name(element.name)
        self.pending = Some(EndElement(name))
        return Some(
          StartElement(
            name,
            element.attributes.map(a => (resolved_name(a.name), a.value)),
          ),
        )
      }
      End(name) => {
        self.depth -= 1
        return Some(EndElement(resolved_name(name)))
      }
      Text(text) => if self.depth > 0 { return Some(Text(text)) }
      CData(text) => return Some(CData(text))
      DocType(_) =>
        raise Malformed("DOCTYPE is not supported in Office XML parts")
      Eof => return None
      _ => ()
    }
  } nobreak {
    None
  }
}

///|
/// Read an event, coalescing entity-split text from the underlying parser.
pub fn XmlReader::next(self : XmlReader) -> XmlEvent? raise XmlError {
  let event = match self.buffered {
    Some(event) => {
      self.buffered = None
      Some(event)
    }
    None => self.read_next()
  }
  guard event is Some(Text(first)) else { return event }
  let text = StringBuilder()
  text.write_string(first)
  while true {
    match self.read_next() {
      Some(Text(chunk)) => text.write_string(chunk)
      next => {
        self.buffered = next
        break
      }
    }
  }
  Some(Text(text.to_string()))
}
