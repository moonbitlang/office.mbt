// The path grammar moved to `bobzhang/docx2html/paths` (Phase-2 J1: the
// annotation index in `docx` needs it and importing `inspect` from `docx`
// would cycle). These delegations keep this package's public surface —
// `PathError` and `resolve_path` — exactly where agents' tooling found it.

///|
pub using @paths {type PathError}

///|
/// Parses and resolves an agent path against a document (and, when
/// supplied, its header/footer parts). Delegates to `@paths.resolve_path`.
pub fn resolve_path(
  document : @document.DocumentElement,
  path : String,
  headers? : Array[@document.HeaderFooterPart] = [],
  footers? : Array[@document.HeaderFooterPart] = [],
) -> @document.DocumentElement raise PathError {
  @paths.resolve_path(document, path, headers~, footers~)
}
