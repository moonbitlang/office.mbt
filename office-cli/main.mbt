///|
suberror CliError {
  CliError(String)
}

///|
impl Show for CliError with fn output(self, logger) {
  match self {
    CliError(message) => logger.write_string(message)
  }
}

///|
async fn main {
  @office_cli.run() catch {
    error if @async.is_being_cancelled() => raise error
    error => raise CliError(error.to_string())
  }
}
