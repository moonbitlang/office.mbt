///|
/// The document formats supported by the `office` facade.
pub(all) enum DocumentFormat {
  Xlsx
  Docx
} derive(Debug, Eq)

///|
/// A deterministic, lowercase name suitable for CLI and JSON output.
pub fn DocumentFormat::name(self : DocumentFormat) -> String {
  match self {
    Xlsx => "xlsx"
    Docx => "docx"
  }
}

///|
pub impl Show for DocumentFormat with fn output(self, logger) {
  logger.write_string(self.name())
}

///|
/// Errors produced while identifying a supported Office package.
pub(all) suberror OfficeError {
  UnsupportedFileExtension(String)
  InvalidPackage(String)
  FormatMismatch(expected~ : DocumentFormat, actual~ : DocumentFormat)
} derive(Debug, Eq)

///|
pub impl Show for OfficeError with fn output(self, logger) {
  match self {
    UnsupportedFileExtension(path) =>
      logger.write_string(
        "unsupported file extension for '\{path}' (expected .xlsx or .docx)",
      )
    InvalidPackage(message) =>
      logger.write_string("invalid Office package: " + message)
    FormatMismatch(expected~, actual~) =>
      logger.write_string(
        "file extension says \{expected.name()}, but package content is \{actual.name()}",
      )
  }
}

///|
const XLSX_MAIN_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"

///|
const DOCX_MAIN_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"

///|
fn format_from_extension(path : StringView) -> DocumentFormat raise OfficeError {
  let lower = path.to_owned().to_lower()
  if lower.has_suffix(".xlsx") {
    Xlsx
  } else if lower.has_suffix(".docx") {
    Docx
  } else {
    raise UnsupportedFileExtension(path.to_owned())
  }
}

///|
fn format_from_package(data : BytesView) -> DocumentFormat raise OfficeError {
  let archive = @zip.read(data) catch {
    _ => raise InvalidPackage("archive is not a readable ZIP")
  }
  let content_types_text = match archive.get("[Content_Types].xml") {
    Some(bytes) =>
      @utf8.decode(bytes) catch {
        _ => raise InvalidPackage("[Content_Types].xml is not valid UTF-8")
      }
    None => raise InvalidPackage("missing required part: [Content_Types].xml")
  }
  let content_types = @xml.read_xml_string(content_types_text) catch {
    _ => raise InvalidPackage("[Content_Types].xml is not well-formed XML")
  }
  if local_name(content_types.name) != "Types" {
    raise InvalidPackage("[Content_Types].xml root element is not Types")
  }
  let mut is_xlsx = false
  let mut is_docx = false
  for child in content_types.children {
    guard child is XmlElement(element) && local_name(element.name) == "Override" else {
      continue
    }
    match element.attributes.get("ContentType") {
      Some(XLSX_MAIN_CONTENT_TYPE) => is_xlsx = true
      Some(DOCX_MAIN_CONTENT_TYPE) => is_docx = true
      _ => ()
    }
  }
  match (is_xlsx, is_docx) {
    (true, false) => Xlsx
    (false, true) => Docx
    (false, false) =>
      raise InvalidPackage(
        "content types do not declare an XLSX or DOCX main part",
      )
    (true, true) =>
      raise InvalidPackage(
        "content types declare both XLSX and DOCX main parts",
      )
  }
}

///|
fn local_name(name : StringView) -> StringView {
  match name.rev_find("}") {
    Some(index) if index + 1 < name.length() => name[index + 1:]
    _ => name
  }
}

///|
fn structural_findings(
  format : DocumentFormat,
  data : BytesView,
) -> Array[String] {
  match format {
    Xlsx => @xlsx.validate_ooxml_package(data)
    Docx => @opc.validate_docx_package(data)
  }
}

///|
/// Identifies a structurally valid XLSX or DOCX package.
///
/// The file extension and the OOXML main-part content type must agree. The
/// corresponding portable package validator then checks the package before the
/// format is returned.
pub fn detect_format(
  path : StringView,
  data : BytesView,
) -> DocumentFormat raise OfficeError {
  let expected = format_from_extension(path)
  let actual = format_from_package(data)
  if expected != actual {
    raise FormatMismatch(expected~, actual~)
  }
  let findings = structural_findings(actual, data)
  if findings.length() > 0 {
    let first = findings[0]
    let suffix = if findings.length() == 1 {
      ""
    } else {
      " (and \{findings.length() - 1} more finding(s))"
    }
    raise InvalidPackage(first + suffix)
  }
  actual
}
