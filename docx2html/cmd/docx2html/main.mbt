///|
enum CliOutputFormat {
  Html
  Markdown
} derive(Debug, Eq)

///|
enum CliCommand {
  Run(CliOptions)
  Help
} derive(Debug, Eq)

///|
struct CliOptions {
  input_path : String
  output_path : String?
  output_dir : String?
  style_map_path : String?
  output_format : CliOutputFormat
  pretty_print : Bool
} derive(Debug, Eq)

///|
suberror CliError {
  CliError(String)
} derive(Debug, Eq)

///|
#borrow(content)
extern "C" fn write_stdout_bytes(content : Bytes) -> Int = "docx2html_write_stdout"

///|
#borrow(content)
extern "C" fn write_stderr_bytes(content : Bytes) -> Int = "docx2html_write_stderr"

///|
extern "C" fn exit_process(status : Int) -> Unit = "docx2html_exit"

///|
fn main {
  run_main() catch {
    CliError(message) => {
      write_stderr(message + "\n")
      exit_process(1)
    }
    @fs.IOError(message) => {
      write_stderr("docx2html: " + message + "\n")
      exit_process(1)
    }
    @docx.InvalidZip(message~)
    | @docx.InvalidXml(message~)
    | @docx.MissingPart(message~)
    | @docx.Unsupported(message~) => {
      write_stderr("docx2html: " + message + "\n")
      exit_process(1)
    }
    _ => {
      write_stderr("docx2html: unexpected failure\n")
      exit_process(1)
    }
  }
}

///|
fn run_main() -> Unit raise {
  match parse_cli_args(@env.args()) {
    Help => write_stdout(ensure_trailing_newline(render_cli_help()))
    Run(options) => run_conversion(options)
  }
}

///|
fn parse_cli_args(args : Array[String]) -> CliCommand raise CliError {
  let argv = cli_argv(args)
  if argv_is_help_only(argv) {
    return Help
  }
  let matches = cli_command().parse(argv~, env={}) catch {
    err => raise CliError(err.to_string())
  }
  if matches.flags.get_or_default("help", false) {
    return Help
  }
  let input_path = match first_value(matches, "input") {
    Some(value) => value
    None =>
      raise CliError(
        "error: the following required argument was not provided: 'input'\n\n" +
        render_cli_help(),
      )
  }
  let output_path = first_value(matches, "output")
  let output_dir = first_value(matches, "output-dir")
  if output_path is Some(_) && output_dir is Some(_) {
    raise CliError(
      "error: output path and --output-dir are mutually exclusive\n\n" +
      render_cli_help(),
    )
  }
  let output_format = match first_value(matches, "output-format") {
    Some(value) => parse_output_format(value)
    None => Html
  }
  Run({
    input_path,
    output_path,
    output_dir,
    style_map_path: first_value(matches, "style-map"),
    output_format,
    pretty_print: matches.flags.get_or_default("pretty-print", false),
  })
}

///|
fn cli_command() -> @argparse.Command {
  Command(
    "docx2html",
    about="Convert DOCX documents to HTML or Markdown.",
    disable_help_flag=true,
    flags=[
      FlagArg("help", short='h', long="help", about="Show help information."),
      FlagArg("pretty-print", about="Pretty-print generated HTML."),
    ],
    options=[
      OptionArg("style-map", about="Read Mammoth style-map lines from a file."),
      OptionArg("output-format", about="Output format: html or markdown.", default_values=[
        "html",
      ]),
      OptionArg(
        "output-dir",
        about="Write converted output and extracted images into a directory.",
      ),
    ],
    positionals=[
      PositionArg(
        "input",
        about="Input .docx file.",
        num_args=ValueRange(lower=1, upper=1),
      ),
      PositionArg(
        "output",
        about="Output file. Defaults to stdout unless --output-dir is set.",
        num_args=ValueRange(lower=0, upper=1),
      ),
    ],
  )
}

///|
fn cli_argv(args : Array[String]) -> Array[String] {
  let argv = []
  for index in 1..<args.length() {
    argv.push(args[index])
  }
  argv
}

///|
fn argv_is_help_only(argv : Array[String]) -> Bool {
  argv.length() == 1 && (argv[0] == "--help" || argv[0] == "-h")
}

///|
fn first_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => if values.length() > 0 { Some(values[0]) } else { None }
    None => None
  }
}

///|
fn parse_output_format(value : String) -> CliOutputFormat raise CliError {
  match value {
    "html" => Html
    "markdown" => Markdown
    _ =>
      raise CliError(
        "Unsupported output format: " +
        value +
        "\nExpected one of: html, markdown",
      )
  }
}

///|
fn run_conversion(options : CliOptions) -> Unit raise {
  let result = render_conversion(options)
  for message in result.messages {
    write_stderr(format_message(message) + "\n")
  }
  match output_path(options) {
    Some(path) => @fs.write_string_to_file(path, result.value)
    None => write_stdout(result.value)
  }
}

///|
fn render_conversion(options : CliOptions) -> @docx.ConversionResult raise {
  let style_map = match options.style_map_path {
    Some(path) => @docx.read_style_map_string(@fs.read_file_to_string(path))
    None => []
  }
  let docx = @fs.read_file_to_bytes(options.input_path)
  let convert_image = match options.output_dir {
    Some(output_dir) => output_dir_image_converter(output_dir)
    None => @docx.data_uri_image_converter
  }
  let result = match options.output_format {
    Html =>
      @docx.convert_to_html(
        docx[:],
        style_map~,
        pretty_print=options.pretty_print,
        convert_image~,
      )
    Markdown => @docx.convert_to_markdown(docx[:], style_map~, convert_image~)
  }
  result
}

///|
fn output_dir_image_converter(
  output_dir : String,
) -> (@docx.Image) -> @docx.ImageConversion {
  let mut image_index = 0
  fn(image) {
    image_index += 1
    let filename = image_index.to_string() +
      "." +
      image_extension(image.content_type)
    let path = join_path(output_dir, filename)
    try {
      @fs.write_bytes_to_file(path, image.data)
      @docx.img_element(fn(_image) { { "src": filename } })(image)
    } catch {
      IOError(message) =>
        @docx.image_conversion([], messages=[
          Error("could not write image file '" + path + "': " + message),
        ])
    }
  }
}

///|
fn output_path(options : CliOptions) -> String? {
  match options.output_path {
    Some(path) => Some(path)
    None =>
      match options.output_dir {
        Some(dir) =>
          Some(
            join_path(
              dir,
              input_basename_without_docx(options.input_path) + ".html",
            ),
          )
        None => None
      }
  }
}

///|
fn input_basename_without_docx(path : String) -> String {
  let name = basename(path)
  if name.has_suffix(".docx") {
    name[:name.length() - ".docx".length()].to_owned()
  } else {
    name
  }
}

///|
fn basename(path : String) -> String {
  match last_path_separator(path) {
    Some(index) => path[index + 1:].to_owned()
    None => path
  }
}

///|
fn last_path_separator(path : String) -> Int? {
  match (path.rev_find("/"), path.rev_find("\\")) {
    (Some(left), Some(right)) => Some(if left > right { left } else { right })
    (Some(index), None) | (None, Some(index)) => Some(index)
    (None, None) => None
  }
}

///|
fn join_path(dir : String, filename : String) -> String {
  if dir.has_suffix("/") || dir.has_suffix("\\") {
    dir + filename
  } else {
    dir + "/" + filename
  }
}

///|
fn image_extension(content_type : String) -> String {
  match content_type.find("/") {
    Some(index) => content_type[index + 1:].to_owned()
    None => "bin"
  }
}

///|
fn format_message(message : @docx.Message) -> String {
  match message {
    Warning(message) | Error(message) => message
  }
}

///|
fn write_stdout(content : String) -> Unit {
  ignore(write_stdout_bytes(@utf8.encode(content)))
}

///|
fn write_stderr(content : String) -> Unit {
  ignore(write_stderr_bytes(@utf8.encode(content)))
}

///|
fn render_cli_help() -> String {
  cli_command().render_help()
}

///|
fn ensure_trailing_newline(content : String) -> String {
  if content.has_suffix("\n") {
    content
  } else {
    content + "\n"
  }
}
