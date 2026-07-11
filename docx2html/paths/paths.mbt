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
// - Roots: `/body` (the main story) and, when the caller supplies the
//   package's parts, `/header[n]` / `/footer[n]` (1-based part index).
//   `/footnotes/note[id]`, `/endnotes/note[id]`, and `/comments/comment[id]`
//   remain RESERVED for the notes/comments surface; resolving them fails
//   with a clear "not yet addressable" error rather than `not found`.

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
/// How one segment selects among same-kind siblings: by 1-based ordinal
/// (snapshot-relative, the default) or by the element's document id
/// (`[@id=3]` — comments and notes carry document-lifetime ids, the
/// agent-stable handle). Ids match the LITERAL id string; the token may
/// not contain `]` or `=` (an id spelled with those is unaddressable by
/// id and is emitted as an ordinal path plus a diagnostic).
pub enum StepSelector {
  Ordinal(Int)
  ById(String)
}

///|
/// One parsed `kind[index]` / `kind[@id=...]` segment.
pub struct PathStep {
  kind : String
  selector : StepSelector
}

///|
/// The story a path addresses. Header/Footer carry the 1-based part
/// index; Footnotes/Endnotes/Comments are the annotation stories
/// (Phase-2 J2 — previously reserved).
pub enum PathRoot {
  Body
  Header(Int)
  Footer(Int)
  Footnotes
  Endnotes
  Comments
}

///|
/// A parsed path: its story root plus the `kind[index]` steps.
pub struct ParsedPath {
  root : PathRoot
  steps : Array[PathStep]
}

///|
/// The path segment kind of an addressable element, or `None` for leaves
/// and structural nodes that are not directly addressable (text, tabs,
/// breaks, references…). The kind table is part of the `docx.element/1`
/// contract — extend it only additively.
pub fn segment_kind(element : @document.DocumentElement) -> String? {
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
pub fn element_children(
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
/// Roots still reserved for later surfaces (none since J2).
let reserved_roots : ReadOnlyArray[String] = []

///|
/// Parses a `/body/kind[i]/...`, `/header[n]/...`, or `/footer[n]/...` path.
/// Reserved roots (notes/comments) fail with a dedicated diagnostic.
pub fn parse_path(path : String) -> ParsedPath raise PathError {
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
  let root_segment = segments[0]
  let root = if root_segment == "body" {
    Body
  } else if root_segment.has_prefix("header[") || root_segment == "header" {
    Header(parse_root_index(root_segment, "header", path))
  } else if root_segment.has_prefix("footer[") || root_segment == "footer" {
    Footer(parse_root_index(root_segment, "footer", path))
  } else if root_segment == "footnotes" {
    Footnotes
  } else if root_segment == "endnotes" {
    Endnotes
  } else if root_segment == "comments" {
    Comments
  } else {
    for reserved in reserved_roots {
      if root_segment == reserved || root_segment.has_prefix(reserved + "[") {
        raise PathError(
          "path root '/\{root_segment}' is reserved but not yet addressable",
        )
      }
    }
    raise PathError("invalid path '\{path}': unknown root '/\{root_segment}'")
  }
  let steps = []
  for i in 1..<segments.length() {
    steps.push(parse_step(segments[i], path))
  }
  { root, steps }
}

///|
/// Parses a `header[n]` / `footer[n]` ROOT segment. Deliberately not routed
/// through `parse_step`: header/footer are not child kinds (widening the
/// child-kind table for them would make `/body/header[1]` parse and fail
/// with a misleading not-found).
fn parse_root_index(
  segment : String,
  kind : String,
  path : String,
) -> Int raise PathError {
  guard segment.find("[") is Some(open) &&
    segment.has_suffix("]") &&
    segment[:open].to_owned() == kind else {
    raise PathError(
      "invalid path root '/\{segment}' in '\{path}': expected \{kind}[index], e.g. /\{kind}[1]",
    )
  }
  let digits = segment[open + 1:segment.length() - 1].to_owned()
  parse_positive_int(digits) catch {
    _ =>
      raise PathError(
        "invalid path root '/\{segment}' in '\{path}': expected \{kind}[index], e.g. /\{kind}[1]",
      )
  }
}

///|
fn parse_step(segment : String, path : String) -> PathStep raise PathError {
  guard segment.find("[") is Some(open) && segment.has_suffix("]") && open > 0 else {
    raise PathError(
      "invalid path segment '\{segment}' in '\{path}': expected kind[index], e.g. p[1]",
    )
  }
  let kind = segment[:open].to_owned()
  let inner = segment[open + 1:segment.length() - 1].to_owned()
  if !known_kind(kind) {
    raise PathError(
      "invalid path segment '\{segment}' in '\{path}': unknown kind '\{kind}' (known: p, r, tbl, tr, tc, hyperlink, image, note, comment)",
    )
  }
  // `[@id=TOKEN]` selects by document id (comments/notes); the token is
  // matched literally and may not contain ']' or '=' (grammar-locked).
  if inner.has_prefix("@id=") {
    let token = inner[4:].to_owned()
    if token == "" || token.find("=") is Some(_) {
      raise PathError(
        "invalid path segment '\{segment}' in '\{path}': expected [@id=<token>] with a non-empty token free of ']' and '='",
      )
    }
    if !(kind is ("note" | "comment")) {
      raise PathError(
        "invalid path segment '\{segment}' in '\{path}': [@id=...] selects notes and comments only (positional kinds use [index])",
      )
    }
    return { kind, selector: ById(token) }
  }
  let index = parse_positive_int(inner) catch {
    _ =>
      raise PathError(
        "invalid path segment '\{segment}' in '\{path}': index must be a positive integer",
      )
  }
  { kind, selector: Ordinal(index) }
}

///|
fn known_kind(kind : String) -> Bool {
  kind
  is ("p"
  | "r"
  | "tbl"
  | "tr"
  | "tc"
  | "hyperlink"
  | "image"
  | "note"
  | "comment")
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
pub fn resolve_steps(
  document : @document.DocumentElement,
  steps : Array[PathStep],
  path : String,
  root_prefix? : String = "/body",
) -> @document.DocumentElement raise PathError {
  let mut current = match document {
    Document(..) => document
    other => @document.document([other])
  }
  let mut prefix = root_prefix
  for step in steps {
    let wanted = match step.selector {
      Ordinal(index) => index
      ById(_) =>
        raise PathError(
          "path '\{path}' not resolvable: [@id=...] applies to annotation roots, not '\{prefix}'",
        )
    }
    let mut seen = 0
    let mut found : @document.DocumentElement? = None
    for child in element_children(current) {
      if segment_kind(child) is Some(kind) && kind == step.kind {
        seen += 1
        if seen == wanted {
          found = Some(child)
          break
        }
      }
    }
    match found {
      Some(element) => {
        current = element
        prefix = "\{prefix}/\{step.kind}[\{wanted}]"
      }
      None =>
        raise PathError(
          "path '\{path}' not found: '\{prefix}' has \{seen} '\{step.kind}' children (wanted index \{wanted})",
        )
    }
  }
  current
}

///|
/// Resolves a parsed root to its story container plus the path prefix its
/// steps resolve under.
pub fn root_container(
  document : @document.DocumentElement,
  parsed : ParsedPath,
  path : String,
  headers : Array[@document.HeaderFooterPart],
  footers : Array[@document.HeaderFooterPart],
) -> (@document.DocumentElement, String) raise PathError {
  match parsed.root {
    Body =>
      (
        match document {
          Document(..) => document
          other => @document.document([other])
        },
        "/body",
      )
    Header(index) =>
      (part_container(headers, index, "header", path), "/header[\{index}]")
    Footer(index) =>
      (part_container(footers, index, "footer", path), "/footer[\{index}]")
    Footnotes | Endnotes | Comments =>
      raise PathError(
        "path root of '\{path}' is an annotation story — resolve it via resolve_annotation_path with the document's notes/comments",
      )
  }
}

///|
/// Resolves a path under an annotation root against (id, body) pairs in
/// reader order. The FIRST step must be `note[...]`/`comment[...]`
/// (ordinal or `[@id=...]`); remaining steps resolve through the shared
/// grammar inside that container's body. Duplicate ids make `[@id=...]`
/// AMBIGUOUS (the error names the ordinal alternatives, per the locked
/// selector rules).
pub fn resolve_annotation_path(
  path : String,
  footnotes? : Array[(String, Array[@document.DocumentElement])] = [],
  endnotes? : Array[(String, Array[@document.DocumentElement])] = [],
  comments? : Array[(String, Array[@document.DocumentElement])] = [],
) -> @document.DocumentElement raise PathError {
  let parsed = parse_path(path)
  let (entries, container_kind, story) = match parsed.root {
    Footnotes => (footnotes, "note", "/footnotes")
    Endnotes => (endnotes, "note", "/endnotes")
    Comments => (comments, "comment", "/comments")
    _ =>
      raise PathError(
        "path '\{path}' does not address an annotation story; use resolve_path",
      )
  }
  guard parsed.steps.length() > 0 else {
    raise PathError(
      "path '\{path}' addresses the whole \{story} story; select a \{container_kind} (e.g. \{story}/\{container_kind}[1])",
    )
  }
  let head = parsed.steps[0]
  if head.kind != container_kind {
    raise PathError(
      "path '\{path}' must start with \{story}/\{container_kind}[...] (got '\{head.kind}')",
    )
  }
  let (entry_index, rendered) = match head.selector {
    Ordinal(index) => {
      if index < 1 || index > entries.length() {
        raise PathError(
          "path '\{path}' not found: \{story} has \{entries.length()} \{container_kind}(s) (wanted index \{index})",
        )
      }
      (index - 1, "\{story}/\{container_kind}[\{index}]")
    }
    ById(token) => {
      let matches : Array[Int] = []
      for at, entry in entries {
        let (id, _) = entry
        if id == token {
          matches.push(at)
        }
      }
      match matches.length() {
        0 =>
          raise PathError(
            "path '\{path}' not found: no \{container_kind} has id '\{token}'",
          )
        1 => (matches[0], "\{story}/\{container_kind}[@id=\{token}]")
        _ => {
          let ordinals : Array[String] = []
          for at in matches {
            ordinals.push("\{container_kind}[\{at + 1}]")
          }
          raise PathError(
            "path '\{path}' is ambiguous: id '\{token}' matches \{matches.length()} \{container_kind}s (use \{ordinals.join(" or ")})",
          )
        }
      }
    }
  }
  let (_, body) = entries[entry_index]
  let container = @document.document(body)
  if parsed.steps.length() == 1 {
    return container
  }
  resolve_steps(
    container,
    parsed.steps[1:].to_array(),
    path,
    root_prefix=rendered,
  )
}

///|
fn part_container(
  parts : Array[@document.HeaderFooterPart],
  index : Int,
  kind : String,
  path : String,
) -> @document.DocumentElement raise PathError {
  if index < 1 || index > parts.length() {
    raise PathError(
      "path '\{path}' not found: the document has \{parts.length()} \{kind} part(s) (wanted index \{index})",
    )
  }
  @document.document(parts[index - 1].body)
}

///|
/// Parses and resolves an agent path against a document (and, when
/// supplied, its header/footer parts).
pub fn resolve_path(
  document : @document.DocumentElement,
  path : String,
  headers? : Array[@document.HeaderFooterPart] = [],
  footers? : Array[@document.HeaderFooterPart] = [],
) -> @document.DocumentElement raise PathError {
  let parsed = parse_path(path)
  let (container, prefix) = root_container(
    document, parsed, path, headers, footers,
  )
  if parsed.steps.length() == 0 {
    return container
  }
  resolve_steps(container, parsed.steps, path, root_prefix=prefix)
}

///|
/// Resolves a RELATIVE step string ("p[2]/r[1]", "" = the container
/// itself) against a container element — the verification primitive the
/// annotation index uses to check scanner-derived positions against the
/// parsed document. `prefix~` only shapes error messages.
pub fn resolve_relative(
  container : @document.DocumentElement,
  steps_path : String,
  prefix~ : String,
) -> @document.DocumentElement raise PathError {
  if steps_path == "" {
    return container
  }
  let steps : Array[PathStep] = []
  for segment in steps_path.split("/") {
    steps.push(parse_step(segment.to_string(), "\{prefix}/\{steps_path}"))
  }
  resolve_steps(container, steps, "\{prefix}/\{steps_path}", root_prefix=prefix)
}
