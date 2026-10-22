///|
pub(all) suberror PdfCliError {
  Usage(String)
  Runtime(String)
}

///|
fn pdflite_cmd_select_pages(
  document : @pdf.PdfDocument,
  spec : String,
) -> Array[Int32] raise {
  let count = document.endpage()
  guard spec != "" else { raise Usage("page specification must not be empty") }
  let pages = @pagespec.pdf_parse_pagespec_for_count(
    count,
    spec,
    strict_bounds=true,
  ) catch {
    err =>
      raise Usage(
        "invalid page specification '\{spec}': \{@core.pdf_error_summary(err)}",
      )
  }
  guard !pages.is_empty() else {
    raise Usage("page specification selects no pages")
  }
  pages
}


///|
fn pdflite_cmd_optional_value(
  matches : @argparse.Matches,
  name : String,
) -> String? {
  matches.values.get(name).bind(values => values.get(0))
}


///|
fn pdflite_cmd_path(name : String) -> @argparse.PositionArg {
  PositionArg(name, about=name, num_args=@argparse.ValueRange::single())
}


///|
fn pdflite_cmd_action(
  options : @argparse.Matches,
) -> (String, @argparse.Matches) raise {
  guard options.subcommand is Some(action) else {
    raise Usage("a subcommand is required")
  }
  action
}


