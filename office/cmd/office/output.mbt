///|
enum OutputMode {
  Human
  JsonDocument
  JsonLines
}

///|
fn output_flags_from_args(args : Array[String]) -> (Bool, Bool) {
  let mut json = false
  let mut jsonl = false
  for argument in args {
    if argument == "--" {
      break
    } else if argument == "--json" {
      json = true
    } else if argument == "--jsonl" {
      jsonl = true
    }
  }
  (json, jsonl)
}

///|
fn output_mode_from_args(args : Array[String]) -> OutputMode {
  let (json, jsonl) = output_flags_from_args(args)
  if jsonl && !json {
    JsonLines
  } else if json {
    JsonDocument
  } else {
    Human
  }
}

///|
fn bounded_text(value : String, maximum_chars : Int) -> String {
  let output = StringBuilder::new()
  let mut count = 0
  let mut truncated = false
  for char in value {
    if count < maximum_chars {
      output.write_char(char) |> ignore
    } else {
      truncated = true
    }
    count = count + 1
  }
  if truncated {
    output.write_string("…") |> ignore
  }
  output.to_string()
}

///|
fn normalize_argument_error(value : String) -> String {
  let first_line = match value.find("\n") {
    Some(index) => value[:index].to_owned()
    None => value
  }
  let bounded = bounded_text(first_line, 240)
  if bounded.has_prefix("error: ") {
    bounded["error: ".length():].to_owned()
  } else if bounded.has_prefix("office: ") {
    bounded["office: ".length():].to_owned()
  } else {
    bounded
  }
}

///|
fn render_failure(error : @lib.ProtocolError, mode : OutputMode) -> String {
  match mode {
    Human => "office: " + error.message
    JsonDocument => @lib.output_failure(error).stringify(indent=2)
    JsonLines => @lib.output_failure(error).stringify()
  }
}
