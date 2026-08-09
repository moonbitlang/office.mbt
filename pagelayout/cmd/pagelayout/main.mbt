///|
// The pagelayout CLI: render a .docx to paginated SVG, or report what
// pagination produced. This is the seam where the engine meets real
// files — every other package is pure.

///|
let cmd_version = "0.1.0"

///|
let exit_ok = 0

///|
let exit_runtime_error = 1

///|
let exit_usage_error = 2

///|
priv enum Cmd {
  RenderSvg(String, String)
  RenderPdf(String, String)
  Info(String, Bool)
}

///|
fn command() -> @argparse.Command {
  Command(
    "pagelayout",
    about="Lay out and render DOCX documents to paginated SVG or PDF.",
    version="pagelayout " + cmd_version,
    subcommand_required=true,
    disable_help_subcommand=true,
    subcommands=[
      Command("render", about="Render a DOCX to one SVG file per page.", positionals=[
        PositionArg(
          "input",
          about="Input DOCX path.",
          num_args=@argparse.ValueRange::single(),
        ),
        PositionArg(
          "output",
          about="Output path; one page writes here, more pages write <output>-1.svg, -2.svg, ...",
          num_args=@argparse.ValueRange::single(),
        ),
      ]),
      Command("pdf", about="Render a DOCX to a single PDF file.", positionals=[
        PositionArg(
          "input",
          about="Input DOCX path.",
          num_args=@argparse.ValueRange::single(),
        ),
        PositionArg(
          "output",
          about="Output PDF path.",
          num_args=@argparse.ValueRange::single(),
        ),
      ]),
      Command(
        "info",
        about="Report the page geometry and content a DOCX lays out to.",
        positionals=[
          PositionArg(
            "input",
            about="Input DOCX path.",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
        flags=[FlagArg("json", about="Print the report as JSON.")],
      ),
    ],
  )
}

///|
fn single_value(matches : @argparse.Matches, name : String) -> String raise {
  match matches.values.get(name) {
    Some(values) if values.length() == 1 => values[0]
    _ => fail("argparse did not return one value for " + name)
  }
}

///|
fn parse_args(args : ArrayView[String]) -> Cmd raise {
  let matches = command().parse(argv=args, env=Map([]))
  match matches.subcommand {
    Some(("render", sub)) =>
      RenderSvg(single_value(sub, "input"), single_value(sub, "output"))
    Some(("pdf", sub)) =>
      RenderPdf(single_value(sub, "input"), single_value(sub, "output"))
    Some(("info", sub)) =>
      Info(single_value(sub, "input"), sub.flags.get("json").unwrap_or(false))
    Some((name, _)) => fail("unexpected subcommand: " + name)
    None => fail("argparse did not return a subcommand")
  }
}

///|
async fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  let code = run(args)
  if code != 0 {
    @sys.exit(code)
  }
}

///|
async fn run(args : ArrayView[String]) -> Int {
  let cmd = parse_args(args) catch {
    err => {
      @stdio.stderr.write(err.to_string() + "\n")
      return exit_usage_error
    }
  }
  let result = match cmd {
    RenderSvg(input, output) => render_svg(input, output)
    RenderPdf(input, output) => render_pdf_file(input, output)
    Info(input, json) => info(input, json)
  }
  match result {
    Ok(_) => exit_ok
    Err(message) => {
      @stdio.stderr.write("pagelayout: " + message + "\n")
      exit_runtime_error
    }
  }
}

///|
async fn read_model(input : String) -> Result[@pagelayout_ir.PageModel, String] {
  let bytes = @fs.read_file(input).binary() catch {
    err => return Err("cannot read '" + input + "': " + err.to_string())
  }
  let model = @docx.render_docx(bytes) catch {
    err => return Err("cannot lay out '" + input + "': " + err.to_string())
  }
  Ok(model)
}

///|
/// Page N of a multi-page render goes to `<stem>-<n>.svg`; a single page
/// goes to `output` verbatim.
fn page_path(output : String, index : Int, total : Int) -> String {
  if total <= 1 {
    return output
  }
  let suffix = ".svg"
  let stem = if output.has_suffix(suffix) {
    output[0:output.length() - suffix.length()].to_owned()
  } else {
    output
  }
  "\{stem}-\{index + 1}\{suffix}"
}

///|
async fn render_svg(input : String, output : String) -> Result[Unit, String] {
  let model = read_model(input) catch { err => return Err(err.to_string()) }
  match model {
    Err(message) => Err(message)
    Ok(model) => {
      let pages = @svg.render_pages(model)
      for index, page in pages {
        let path = page_path(output, index, pages.length())
        @fs.write_file(path, @utf8.encode(page), create_mode=CreateOrTruncate) catch {
          err => return Err("cannot write '" + path + "': " + err.to_string())
        }
      }
      @stdio.stdout.write("wrote \{pages.length()} page(s)\n")
      Ok(())
    }
  }
}

///|
async fn render_pdf_file(
  input : String,
  output : String,
) -> Result[Unit, String] {
  let model = read_model(input) catch { err => return Err(err.to_string()) }
  match model {
    Err(message) => Err(message)
    Ok(model) => {
      let bytes = @pdf.render_pdf(model) catch {
        err => return Err("cannot build PDF: " + err.to_string())
      }
      @fs.write_file(output, bytes, create_mode=CreateOrTruncate) catch {
        err => return Err("cannot write '" + output + "': " + err.to_string())
      }
      @stdio.stdout.write("wrote \{model.pages.length()} page(s)\n")
      Ok(())
    }
  }
}

///|
async fn info(input : String, json : Bool) -> Result[Unit, String] {
  let model = read_model(input) catch { err => return Err(err.to_string()) }
  match model {
    Err(message) => Err(message)
    Ok(model) => {
      let mut runs = 0
      let mut characters = 0
      for page in model.pages {
        for item in page.items {
          if item is Text(run) {
            runs += 1
            characters += run.text.length()
          }
        }
      }
      // characters no bundled face can draw are dropped by the backends,
      // so a document can render, validate, and still be missing content
      let text = StringBuilder()
      for page in model.pages {
        for item in page.items {
          if item is Text(run) {
            text.write_string(run.text)
          }
        }
      }
      let uncovered = @fonts.uncovered(text.to_string())
      // images the PDF backend cannot embed leave the reserved space
      // blank, so they are lost the same silent way glyphs are
      let unembeddable = @pdf.unembeddable_images(model)
      let mut dropped = 0
      for entry in uncovered {
        dropped += entry.1
      }
      let width = model.pages.get(0).map(p => p.width_pt).unwrap_or(0.0)
      let height = model.pages.get(0).map(p => p.height_pt).unwrap_or(0.0)
      let violations = model.validate()
      if json {
        let report : Json = {
          "pages": model.pages.length().to_json(),
          "page_width_pt": width.to_json(),
          "page_height_pt": height.to_json(),
          "fonts": model.fonts.length().to_json(),
          "runs": runs.to_json(),
          "characters": characters.to_json(),
          "valid": (violations.length() == 0).to_json(),
          "dropped_characters": dropped.to_json(),
          "uncovered_codepoints": uncovered.length().to_json(),
          "unembeddable_images": unembeddable.length().to_json(),
        }
        @stdio.stdout.write(report.stringify() + "\n")
      } else {
        @stdio.stdout.write("pages: \{model.pages.length()}\n")
        @stdio.stdout.write("page size: \{width} x \{height} pt\n")
        @stdio.stdout.write("fonts: \{model.fonts.length()}\n")
        @stdio.stdout.write("runs: \{runs}\n")
        @stdio.stdout.write("characters: \{characters}\n")
        for entry in uncovered {
          let (codepoint, count) = entry
          @stdio.stdout.write(
            "dropped: U+\{codepoint.to_string(radix=16).to_upper()} x\{count} (no bundled face has this glyph)\n",
          )
        }
        for reason in unembeddable {
          @stdio.stdout.write("dropped image: \{reason}\n")
        }
        for violation in violations {
          @stdio.stdout.write("violation: \{violation}\n")
        }
      }
      Ok(())
    }
  }
}
