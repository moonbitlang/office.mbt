// Logical, snapshot-relative projection paths over the parsed document —
// the addressing scheme shared by `docx text` (which emits them) and
// `docx get` (which resolves them). See docs/agent-json-schemas.md for the
// normative contract. In short:
//
// - Paths are 1-based and use OOXML-like local names for the AST's semantic
//   kinds: `/body/p[3]`, `/body/tbl[1]/tr[2]/tc[1]/p[1]`.
// - Indices count same-kind DIRECT siblings within the parent.
// - A path is valid for one document snapshot; positional paths shift after
//   any edit. They are projections over the (lossy) parsed document, not
//   literal source-XML paths.
// - `/body` is the only root implemented today. `/header[n]`, `/footer[n]`,
//   `/footnotes/note[id]`, `/endnotes/note[id]`, and `/comments/comment[id]`
//   are RESERVED for the header/footer/notes read surface; resolving them
//   fails with a clear "not yet addressable" error rather than `not found`.

///|
/// A path that cannot be parsed or resolved. Its message is agent-facing.
pub(all) suberror PathError {
  PathError(String)
} derive(Eq)

///|
pub impl Show for PathError with fn output(self, logger) {
  match self {
    PathError(message) => logger.write_string(message)
  }
}

///|
/// One parsed `kind[index]` segment.
priv struct PathStep {
  kind : String
  index : Int
}

///|
/// The path segment kind of an addressable element, or `None` for leaves
/// and structural nodes that are not directly addressable (text, tabs,
/// breaks, references…). The kind table is part of the `docx.element/1`
/// contract — extend it only additively.
fn segment_kind(element : @document.DocumentElement) -> String? {
  match element {
    Paragraph(..) => Some("p")
    Run(..) => Some("r")
    Table(..) => Some("tbl")
    TableRow(..) => Some("tr")
    TableCell(..) => Some("tc")
    Hyperlink(..) => Some("hyperlink")
    Image(_) => Some("image")
    _ => None
  }
}

///|
/// The addressable children of an element (the lists paths descend into).
fn element_children(
  element : @document.DocumentElement,
) -> Array[@document.DocumentElement] {
  match element {
    Document(children~, ..)
    | Paragraph(children~, ..)
    | Run(children~, ..)
    | Table(children~, ..)
    | TableRow(children~, ..)
    | TableCell(children~, ..)
    | Hyperlink(children~, ..) => children
    _ => []
  }
}

///|
let reserved_roots : ReadOnlyArray[String] = [
  "header", "footer", "footnotes", "endnotes", "comments",
]

///|
/// Parses a `/body/kind[i]/...` path into steps. The `/body` root is
/// required; reserved roots fail with a dedicated diagnostic.
fn parse_path(path : String) -> Array[PathStep] raise PathError {
  if !path.has_prefix("/") {
    raise PathError("invalid path '\{path}': a path starts with '/'")
  }
  let segments : Array[String] = path[1:]
    .to_owned()
    .split("/")
    .map(v => v.to_owned())
    .collect()
  if segments.length() == 0 || segments[0] == "" {
    raise PathError("invalid path '\{path}': expected '/body/...'")
  }
  let root = segments[0]
  if root != "body" {
    for reserved in reserved_roots {
      if root == reserved || root.has_prefix(reserved + "[") {
        raise PathError(
          "path root '/\{root}' is reserved but not yet addressable; only '/body' paths are supported today",
        )
      }
    }
    raise PathError("invalid path '\{path}': unknown root '/\{root}'")
  }
  let steps = []
  for i in 1..<segments.length() {
    steps.push(parse_step(segments[i], path))
  }
  steps
}

///|
fn parse_step(segment : String, path : String) -> PathStep raise PathError {
  guard segment.find("[") is Some(open) && segment.has_suffix("]") && open > 0 else {
    raise PathError(
      "invalid path segment '\{segment}' in '\{path}': expected kind[index], e.g. p[1]",
    )
  }
  let kind = segment[:open].to_owned()
  let digits = segment[open + 1:segment.length() - 1].to_owned()
  let index = parse_positive_int(digits) catch {
    _ =>
      raise PathError(
        "invalid path segment '\{segment}' in '\{path}': index must be a positive integer",
      )
  }
  if !known_kind(kind) {
    raise PathError(
      "invalid path segment '\{segment}' in '\{path}': unknown kind '\{kind}' (known: p, r, tbl, tr, tc, hyperlink, image)",
    )
  }
  { kind, index }
}

///|
fn known_kind(kind : String) -> Bool {
  kind is ("p" | "r" | "tbl" | "tr" | "tc" | "hyperlink" | "image")
}

///|
priv suberror NotAPositiveInt {
  NotAPositiveInt
}

///|
fn parse_positive_int(digits : String) -> Int raise NotAPositiveInt {
  if digits.length() == 0 || digits.length() > 9 {
    raise NotAPositiveInt
  }
  let mut value = 0
  for unit in digits {
    if unit is ('0'..='9') {
      value = value * 10 + (unit.to_int() - 0x30)
    } else {
      raise NotAPositiveInt
    }
  }
  if value < 1 {
    raise NotAPositiveInt
  }
  value
}

///|
/// Resolves a parsed path against a document, returning the element. The
/// error names the failing segment and how many same-kind siblings exist,
/// so an agent can self-correct.
fn resolve_steps(
  document : @document.DocumentElement,
  steps : Array[PathStep],
  path : String,
) -> @document.DocumentElement raise PathError {
  let mut current = match document {
    Document(..) => document
    other => @document.document([other])
  }
  let mut prefix = "/body"
  for step in steps {
    let mut seen = 0
    let mut found : @document.DocumentElement? = None
    for child in element_children(current) {
      if segment_kind(child) is Some(kind) && kind == step.kind {
        seen += 1
        if seen == step.index {
          found = Some(child)
          break
        }
      }
    }
    match found {
      Some(element) => {
        current = element
        prefix = "\{prefix}/\{step.kind}[\{step.index}]"
      }
      None =>
        raise PathError(
          "path '\{path}' not found: '\{prefix}' has \{seen} '\{step.kind}' children (wanted index \{step.index})",
        )
    }
  }
  current
}

///|
/// Parses and resolves an agent path against a document.
pub fn resolve_path(
  document : @document.DocumentElement,
  path : String,
) -> @document.DocumentElement raise PathError {
  let steps = parse_path(path)
  if steps.length() == 0 {
    // `/body` itself: return the document node (its element JSON is the
    // body summary).
    return match document {
      Document(..) => document
      other => @document.document([other])
    }
  }
  resolve_steps(document, steps, path)
}
