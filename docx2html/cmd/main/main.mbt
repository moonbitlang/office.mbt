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
    @docx2html.InvalidZip(message~)
    | @docx2html.InvalidXml(message~)
    | @docx2html.MissingPart(message~)
    | @docx2html.Unsupported(message~) => {
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
    Help => write_stdout(usage() + "\n")
    Run(options) => run_conversion(options)
  }
}

///|
fn parse_cli_args(args : Array[String]) -> CliCommand raise CliError {
  let mut input_path : String? = None
  let mut output_path : String? = None
  let mut output_dir : String? = None
  let mut style_map_path : String? = None
  let mut output_format = Html
  let mut pretty_print = false
  let mut index = 1
  while index < args.length() {
    let arg = args[index]
    if arg == "--help" || arg == "-h" {
      return Help
    } else if arg == "--pretty-print" {
      pretty_print = true
    } else if arg == "--style-map" {
      index += 1
      style_map_path = Some(require_arg_value(args, index, "--style-map"))
    } else if arg.has_prefix("--style-map=") {
      style_map_path = Some(arg["--style-map=".length():].to_owned())
    } else if arg == "--output-format" {
      index += 1
      output_format = parse_output_format(
        require_arg_value(args, index, "--output-format"),
      )
    } else if arg.has_prefix("--output-format=") {
      output_format = parse_output_format(
        arg["--output-format=".length():].to_owned(),
      )
    } else if arg == "--output-dir" {
      index += 1
      output_dir = Some(require_arg_value(args, index, "--output-dir"))
    } else if arg.has_prefix("--output-dir=") {
      output_dir = Some(arg["--output-dir=".length():].to_owned())
    } else if arg.has_prefix("-") {
      raise CliError("Unknown option: " + arg + "\n" + usage())
    } else {
      match input_path {
        None => input_path = Some(arg)
        Some(_) =>
          match output_path {
            None => output_path = Some(arg)
            Some(_) =>
              raise CliError("Too many positional arguments\n" + usage())
          }
      }
    }
    index += 1
  }
  match (input_path, output_path, output_dir) {
    (None, _, _) => raise CliError(usage())
    (Some(_), Some(_), Some(_)) =>
      raise CliError(
        "output path and --output-dir are mutually exclusive\n" + usage(),
      )
    (Some(input_path), output_path, output_dir) =>
      Run({
        input_path,
        output_path,
        output_dir,
        style_map_path,
        output_format,
        pretty_print,
      })
  }
}

///|
fn require_arg_value(
  args : Array[String],
  index : Int,
  option_name : String,
) -> String raise CliError {
  if index >= args.length() {
    raise CliError("Missing value for " + option_name + "\n" + usage())
  }
  args[index]
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
  let style_map = match options.style_map_path {
    Some(path) =>
      @docx2html.read_style_map_string(@fs.read_file_to_string(path))
    None => []
  }
  let docx = @fs.read_file_to_bytes(options.input_path)
  let convert_image = match options.output_dir {
    Some(output_dir) => output_dir_image_converter(output_dir)
    None => @docx2html.data_uri_image_converter
  }
  let result = match options.output_format {
    Html =>
      @docx2html.convert_to_html(
        docx[:],
        style_map~,
        pretty_print=options.pretty_print,
        convert_image~,
      )
    Markdown =>
      @docx2html.convert_to_markdown(docx[:], style_map~, convert_image~)
  }
  for message in result.messages {
    write_stderr(format_message(message) + "\n")
  }
  match output_path(options) {
    Some(path) => @fs.write_string_to_file(path, result.value)
    None => write_stdout(result.value)
  }
}

///|
fn output_dir_image_converter(
  output_dir : String,
) -> (@docx2html.Image) -> @docx2html.ImageConversion {
  let mut image_index = 0
  fn(image) {
    image_index += 1
    let filename = image_index.to_string() +
      "." +
      image_extension(image.content_type)
    let path = join_path(output_dir, filename)
    try {
      @fs.write_bytes_to_file(path, image.data)
      @docx2html.img_element(fn(_image) { { "src": filename } })(image)
    } catch {
      IOError(message) =>
        @docx2html.image_conversion([], messages=[
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
              input_basename_without_docx(options.input_path) +
              output_extension(options.output_format),
            ),
          )
        None => None
      }
  }
}

///|
fn output_extension(format : CliOutputFormat) -> String {
  match format {
    Html => ".html"
    Markdown => ".md"
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
fn format_message(message : @docx2html.Message) -> String {
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
fn usage() -> String {
  (
    #|Usage: docx2html [--style-map PATH] [--output-format html|markdown] [--pretty-print] INPUT.docx [OUTPUT]
    #|       docx2html --output-dir DIR [--style-map PATH] INPUT.docx
  )
}
