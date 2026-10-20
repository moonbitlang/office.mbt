///|
/// Render an external PPTX against a caller-owned font manifest. No private
/// fixtures or font programs are copied into the source tree.
async fn run() -> Unit {
  let args = @env.args()
  guard args.length() == 4 else {
    fail("usage: render_fixture INPUT.pptx OUTPUT_PREFIX FONTS.json")
  }
  let registry = @fonts.FontRegistry::new()
  let font_fallbacks : Map[String, Array[String]] = Map([])
  let manifest = @json.parse(@fs.read_file(args[3]).text())
  guard manifest is Array(entries) else {
    fail("font manifest must be an array")
  }
  for entry in entries {
    guard entry
      is {
        "family": String(family),
        "path": String(path),
        "bold": False
        | True as bold,
        "italic": False
        | True as italic,
        ..
      } else {
      fail("font entry needs family, path, bold and italic")
    }
    registry.register(
      family,
      @fs.read_file(path).binary(),
      bold=bold is True,
      italic=italic is True,
    )
    |> ignore
    if entry is { "fallback_for": Array(families), .. } {
      for value in families {
        guard value is String(source) else {
          fail("fallback_for entries must be strings")
        }
        if !font_fallbacks.contains(source) {
          font_fallbacks[source] = []
        }
        font_fallbacks[source].push(family)
      }
    }
  }
  let layout = @pptx.layout_presentation(
    @fs.read_file(args[1]).binary(),
    fonts=registry,
    font_fallbacks~,
  )
  let violations = layout.model.validate()
  guard violations.is_empty() else { fail(violations.join("\n")) }
  let pages = @svg.render_pages(layout.model, fonts=layout.fonts)
  for index, page in pages {
    @fs.write_file(
      "\{args[2]}-\{index + 1}.svg",
      @utf8.encode(page),
      create_mode=CreateOrTruncate,
    )
  }
  @fs.write_file(
    "\{args[2]}-model.json",
    @utf8.encode(ToJson::to_json(layout.model).stringify()),
    create_mode=CreateOrTruncate,
  )
  println("rendered \{pages.length()} slides")
}

///|
async fn main {
  run() catch {
    error => {
      println("\{error}")
      @sys.exit(1)
    }
  }
}
