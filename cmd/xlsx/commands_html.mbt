// The `html` subcommand: render a workbook (or one sheet) to a
// self-contained HTML document — the "eyes" half of the agent loop. The
// document goes to stdout by default (wasm-safe) or to `--out`.

///|
async fn run_html(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let workbook = @lib.open_file(file)
  let max_rows = parse_positive_int(m, "max-rows", 1000)
  let max_cols = parse_positive_int(m, "max-cols", 256)
  let document = @xlsx2html.render_workbook(
    workbook,
    title=file,
    sheet=arg(m, "sheet"),
    max_rows~,
    max_cols~,
    include_images=!flag(m, "no-images"),
    calc=flag(m, "calc"),
  )
  let out = arg(m, "out")
  if out == "" {
    println(document)
  } else {
    // `html` is a read-only command: writing the document over the input
    // workbook — directly, via `./` spellings, or via a symlink — would
    // destroy it. The write itself goes through the rename-based saver,
    // so even an alias the checks cannot see (a hard link) replaces only
    // the directory entry named by --out; the input's own entry keeps
    // the original bytes.
    if lexical_normalize(out) == lexical_normalize(file) ||
      resolve_existing(out) == resolve_existing(file) {
      raise CliError("error: --out must not be the input workbook")
    }
    // Write through the exclusive-temp + rename saver with the RAW --out
    // path — never a re-resolved one. `rename` replaces the directory
    // entry named by --out itself (it does not follow a symlink at that
    // entry), and CreateNew never truncates, so whatever --out points to
    // after the guard, the input's own entry always keeps its bytes.
    // Re-resolving here would reintroduce a TOCTOU: a symlink appearing
    // between the guard and the write could retarget the rename.
    write_file_replacing(out, @encoding/utf8.encode(document[:]))
    println("wrote \{out}")
  }
}

///|
/// A path's resolved identity when it exists (native realpath); a path
/// that does not exist (or a wasm path) is its own lexically-normalized
/// identity.
async fn resolve_existing(path : String) -> String noraise {
  resolve_save_target(path) catch {
    _ => lexical_normalize(path)
  }
}

///|
/// Collapses `.` segments and resolves `..` against preceding segments
/// (purely textual — no filesystem access), so `./book.xlsx` and
/// `book.xlsx` compare equal even where realpath is unavailable.
fn lexical_normalize(path : String) -> String {
  let absolute = path.has_prefix("/")
  let out : Array[String] = []
  for segment in path.split("/") {
    let segment = segment.to_string()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if out.length() > 0 && out[out.length() - 1] != ".." {
        ignore(out.pop())
        continue
      }
      if absolute {
        continue
      }
    }
    out.push(segment)
  }
  let joined = out.join("/")
  if absolute {
    "/" + joined
  } else {
    joined
  }
}

///|
fn parse_positive_int(
  m : @argparse.Matches,
  name : String,
  default : Int,
) -> Int raise CliError {
  let text = arg(m, name)
  if text == "" {
    return default
  }
  let value = @string.parse_int(text) catch {
    _ =>
      raise CliError("error: invalid --\{name} '\{text}' (expected a number)")
  }
  if value < 1 {
    raise CliError("error: --\{name} must be at least 1")
  }
  value
}
