///|
/// `docx validate <file>` — portable structural validation (see
/// docx2html/opc): prints `valid` and exits 0, or prints one finding per
/// line and exits non-zero. Unlike schema validation this checks package
/// structure only (archive integrity incl. CRCs, content types,
/// relationships, main-part root).
async fn run_validate(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let data = @afs.read_file(file).binary()
  let findings = @opc.validate_docx_package(data)
  if findings.length() == 0 {
    println("valid")
  } else {
    for finding in findings {
      println(finding)
    }
    raise @cli.CliError(
      "docx: invalid package: \{findings.length()} finding(s)",
    )
  }
}

///|
fn validate_command() -> @argparse.Command {
  Command(
    "validate",
    about="Check docx package structure (prints findings; non-zero exit if invalid)",
    positionals=[
      PositionArg(
        "file",
        about="Input .docx file.",
        num_args=ValueRange(lower=1, upper=1),
      ),
    ],
  )
}
