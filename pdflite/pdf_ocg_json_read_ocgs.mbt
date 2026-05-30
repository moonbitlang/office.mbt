///|
fn pdf_ocg_read_json_ocg(json : Json) -> @ocg.PdfOcg raise PdfError {
  match json {
    Object(entries) if entries.length() == 3 => {
      let intent = pdf_ocg_read_json_field(
        entries, "Intent", "ocg_read_ocg: malformed",
      )
      let name = pdf_ocg_read_json_field(
        entries, "Name", "ocg_read_ocg: malformed",
      )
      let usage = pdf_ocg_read_json_field(
        entries, "Usage", "ocg_read_ocg: malformed",
      )
      {
        name: pdf_ocg_read_json_pdf_string(name, "ocg_read_ocg: malformed"),
        intent: pdf_ocg_read_json_names(
          intent, "ocg_read_ocg: malformed intent",
        ),
        usage: pdf_ocg_read_json_usage(usage),
      }
    }
    _ => raise SoftError("ocg_read_ocg: malformed")
  }
}

///|
fn pdf_ocg_read_json_ocgs(
  json : Json,
) -> Array[(Int, @ocg.PdfOcg)] raise PdfError {
  match json {
    Object(entries) => {
      let output : Array[(Int, @ocg.PdfOcg)] = []
      for entry in entries {
        let number : Int = @strconv.from_str(entry.0) catch {
          _ =>
            raise SoftError(
              "ocg_read_json: malformed JSON top-level dictionary",
            )
        }
        output.push((number, pdf_ocg_read_json_ocg(entry.1)))
      }
      output
    }
    _ => raise SoftError("ocg_read_json: malformed JSON top-level dictionary")
  }
}

///|
fn pdf_ocg_read_json_configs(
  json : Json,
) -> Array[@ocg.PdfOcgConfig] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[@ocg.PdfOcgConfig] = []
      for value in values {
        output.push(pdf_ocg_read_json_config(value))
      }
      output
    }
    _ => raise SoftError("ocg_read_json: malformed JSON top-level dictionary")
  }
}
