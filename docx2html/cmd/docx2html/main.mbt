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
} derive(Eq)

///|
/// Its `Show` writes exactly the message, so the runtime's uncaught-error
/// print (when the error escapes `main`) produces one clean line and a
/// non-zero exit — the wasm backend exposes no public `exit()`.
impl Show for CliError with fn output(self, logger) {
  match self {
    CliError(message) => logger.write_string(message)
  }
}

///|
async fn main {
  // Any failure is turned into a `CliError` that escapes `main`: this prints
  // the message once and exits non-zero on both native and wasm (which has no
  // `exit()` and no stderr). `CliError` messages already carry their own
  // prefix; everything else is labelled `docx2html:`.
  run_main() catch {
    CliError(_) as err => raise err
    @docx.InvalidZip(message~)
    | @docx.InvalidXml(message~)
    | @docx.MissingPart(message~)
    | @docx.Unsupported(message~) => raise CliError("docx2html: " + message)
    err => raise CliError("docx2html: " + err.to_string())
  }
}

///|
async fn run_main() -> Unit {
  match parse_cli_args(@env.args()) {
    Help => println(render_cli_help())
    Run(options) => run_conversion(options)
  }
}

///|
fn parse_cli_args(args : Array[String]) -> CliCommand raise CliError {
  let argv = cli_argv(args)
  if argv_is_help_only(argv) {
    return Help
  }
  let matches = cli_command().parse(argv~, env=Map([])) catch {
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
async fn run_conversion(options : CliOptions) -> Unit {
  // Images destined for an --output-dir are collected during conversion (the
  // convert_image callback is synchronous) and written afterwards, so the
  // writes can use async fs and run on the wasm backend.
  let pending_images : Array[(String, Bytes)] = []
  let result = render_conversion(options, pending=pending_images)
  // Create the --output-dir if it doesn't exist, so callers can name a fresh
  // directory directly (write_file creates files, not their parent dirs).
  match options.output_dir {
    Some(dir) => @afs.mkdir(dir, recursive=true) catch { _ => () }
    None => ()
  }
  // Write the collected --output-dir images before the document. If an image
  // cannot be written the whole conversion fails, rather than emitting a
  // document that references an image file that isn't there: the synchronous
  // convert_image callback has already embedded the `1.png`-style reference,
  // and wasm's async fs means we can't learn the write outcome in time to drop
  // it. Failing loudly beats a document with a dangling image link.
  for entry in pending_images {
    let (path, data) = entry
    @afs.write_file(path, data, create_mode=CreateOrTruncate) catch {
      err =>
        raise CliError(
          "docx2html: could not write image file '\{path}': \{err}",
        )
    }
  }
  match output_path(options) {
    Some(path) => {
      @afs.write_file(path, result.value, create_mode=CreateOrTruncate)
      // Warnings go to stdout only when the document output went to a file, so
      // they never corrupt output piped to stdout. (Wasm has no stderr.)
      for message in result.messages {
        println(format_message(message))
      }
    }
    // stdout: the wasm backend has no exact (no-newline) stdout primitive, so
    // `println` appends a trailing newline here; file output above is the
    // exact document bytes.
    None => println(result.value)
  }
}

///|
/// Read the input document and convert it, recording any `--output-dir` images
/// into `pending` for the caller to write. Performs no output writes itself,
/// which keeps it easy to test.
async fn render_conversion(
  options : CliOptions,
  pending? : Array[(String, Bytes)] = [],
) -> @docx.ConversionResult {
  let style_map = match options.style_map_path {
    Some(path) => @docx.read_style_map_string(@afs.read_file(path).text())
    None => []
  }
  let docx = @afs.read_file(options.input_path).binary()
  let convert_image = match options.output_dir {
    Some(output_dir) => collect_output_dir_images(output_dir, pending)
    None => @docx.data_uri_image_converter
  }
  match options.output_format {
    Html =>
      @docx.convert_to_html(
        docx,
        style_map~,
        pretty_print=options.pretty_print,
        convert_image~,
      )
    Markdown => @docx.convert_to_markdown(docx, style_map~, convert_image~)
  }
}

///|
/// A synchronous image converter for `--output-dir`: it records each image's
/// bytes and target path into `pending` (written asynchronously after the
/// conversion) and returns an `<img>` element referencing the file by name.
fn collect_output_dir_images(
  output_dir : String,
  pending : Array[(String, Bytes)],
) -> (@docx.Image) -> @docx.ImageConversion {
  let mut image_index = 0
  fn(image) {
    image_index += 1
    let filename = image_index.to_string() +
      "." +
      image_extension(image.content_type)
    pending.push((join_path(output_dir, filename), image.data))
    @docx.img_element(fn(_image) { { "src": filename } })(image)
  }
}

///|
fn output_path(options : CliOptions) -> String? {
  match options.output_path {
    Some(path) => Some(path)
    None =>
      match options.output_dir {
        Some(dir) => {
          // Name the file after the input, with an extension matching the
          // chosen output format (so Markdown lands in a `.md` file, not
          // Markdown-inside-`.html`).
          let extension = match options.output_format {
            Html => ".html"
            Markdown => ".md"
          }
          Some(
            join_path(
              dir,
              input_basename_without_docx(options.input_path) + extension,
            ),
          )
        }
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
fn render_cli_help() -> String {
  cli_command().render_help()
}
