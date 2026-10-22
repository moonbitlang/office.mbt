///|
/// A fully materialized file payload; only the Office entry point publishes it.
pub struct PdfArtifact {
  path : String
  bytes : Bytes
}

///|
/// Structured report data plus exact human/export bytes and an optional file.
pub struct PdfResult {
  data : Json
  text : Bytes
  artifact : PdfArtifact?
}

///|
fn pdf_artifact(path : String, bytes : Bytes, data : Json) -> PdfResult {
  { data, text: b"", artifact: Some({ path, bytes }), }
}

///|
fn pdf_export(bytes : Bytes, output : String?, json : Bool) -> PdfResult raise {
  let data = if json {
    @json.parse(@utf8.decode(bytes))
  } else {
    try @utf8.decode(bytes) catch {
      _ => Json::object({
        "encoding": Json::string("base64"),
        "content": Json::string(@base64.encode(bytes)),
      })
    } noraise {
      text => Json::string(text)
    }
  }
  { data, text: bytes, artifact: output.map(path => { path, bytes }), }
}

///|
fn pdf_json_export(data : Json, output : String?) -> PdfResult {
  let text = data.stringify() + "\n"
  { data, text: @utf8.encode(text), artifact: output.map(path => { path, bytes: @utf8.encode(text) }), }
}

///|
fn pdf_verify(bytes : Bytes, expected_pages : Int32) -> Unit raise {
  let verified = @pdf.pdf_read_document_from_bytes(bytes)
  guard verified.endpage() == expected_pages else {
    raise Runtime("written PDF page count does not match the candidate")
  }
}

///|
fn pdf_candidate(document : @pdf.PdfDocument, output : String) -> PdfResult raise {
  let expected = document.endpage()
  let bytes = @pdf.pdf_write_document(document)
  pdf_verify(bytes, expected)
  pdf_artifact(output, bytes, Json::object({ "pages": Json::number(expected.to_double()) }))
}

///|
async fn pdflite_cmd_load(
  input : String,
  passwords~ : PdflitePasswords = { user: None, owner: None, },
) -> @pdf.PdfDocument {
  let bytes = @fs.read_file(input).binary() catch {
    error => raise Runtime("cannot read '\{input}': \{error}")
  }
  pdflite_cmd_read_with_passwords(bytes, passwords) catch {
    error => raise Runtime("cannot parse PDF '\{input}': \{@core.pdf_error_summary(error)}")
  }
}

///|
fn pdf_info(input : String, document : @pdf.PdfDocument) -> PdfResult raise {
  let (major, minor) = document.version()
  let pages = document.endpage()
  let objects = document.object_count()
  let encrypted = document.is_encrypted()
  let version = "\{major}.\{minor}"
  {
    data: Json::object({
      "path": Json::string(input),
      "version": Json::string(version),
      "pages": Json::number(pages.to_double()),
      "objects": Json::number(objects.to_double()),
      "encrypted": Json::boolean(encrypted),
    }),
    text: @utf8.encode("path: \{input}\nversion: \{version}\npages: \{pages}\nobjects: \{objects}\nencrypted: \{encrypted}\n"),
    artifact: None,
  }
}

///|
/// Execute an existing-PDF operation without printing or publishing a file.
/// A returned artifact is fully materialized and PDF candidates are reparsed.
pub async fn execute(options : @argparse.Matches) -> PdfResult {
  let (operation, args) = pdflite_cmd_action(options)
  let supplied_passwords = pdflite_cmd_passwords(options)
  let passwords = if operation == "decrypt" && supplied_passwords.user is None && supplied_passwords.owner is None {
    { user: Some(@utf8.encode("")), owner: None, }
  } else {
    supplied_passwords
  }
  match operation {
    "merge" =>
      pdflite_cmd_merge_selected(
        pdflite_cmd_single_value(args, "output"),
        pdflite_cmd_multiple_values(args, "inputs"),
        args,
        passwords~,
      )
    "metadata" => pdflite_cmd_metadata_execute(args, passwords~)
    "bookmarks" => pdflite_cmd_bookmarks_execute(args, passwords~)
    "labels" => pdflite_cmd_labels_execute(args, passwords~)
    _ => {
      let input = pdflite_cmd_single_value(args, "input")
      let document = pdflite_cmd_load(input, passwords~)
      match operation {
        "info" =>
          if pdflite_cmd_flag_value(args, "detailed") {
            let report = pdf_export(document.info_json_blob(), None, true)
            { ..report, text: document.info_blob() }
          } else {
            pdf_info(input, document)
          }
        "pages" => {
          let pages = pdflite_cmd_select_pages(document, pdflite_cmd_single_value(args, "pages"))
          let report = pdf_export(document.page_info_json_blob(pages), pdflite_cmd_optional_value(args, "output"), true)
          // File reports use the selected presentation, while JSON stdout
          // always carries the structured result.
          if pdf_json_mode(options) {
            report
          } else {
            { ..report,
              text: document.page_info_text(pages),
              artifact: pdflite_cmd_optional_value(args, "output").map(path => {
                path, bytes: document.page_info_text(pages),
              }),
            }
          }
        }
        "fonts" => {
          let pages = pdflite_cmd_select_pages(document, pdflite_cmd_single_value(args, "pages"))
          let missing = pdflite_cmd_flag_value(args, "missing")
          let bytes = if missing {
            @utf8.encode(Json(document.missing_fonts(pages)).stringify() + "\n")
          } else {
            document.print_fonts(pages, json=true)
          }
          let report = pdf_export(bytes, pdflite_cmd_optional_value(args, "output"), true)
          if pdf_json_mode(options) {
            report
          } else {
            let text_bytes = if missing { document.missing_fonts_text(pages) } else { document.print_fonts(pages, json=false) }
            { ..report,
              text: text_bytes,
              artifact: pdflite_cmd_optional_value(args, "output").map(path => { path, bytes: text_bytes }),
            }
          }
        }
        "validate" => {
          let bytes = @pdf.pdf_write_document(document)
          pdf_verify(bytes, document.endpage())
          let report = pdf_info(input, document)
          { ..report, text: @utf8.encode("valid: \{input}\n" + @utf8.decode(report.text)) }
        }
        "extract" => {
          let pages = pdflite_cmd_select_pages(document, pdflite_cmd_single_value(args, "pages"))
          let extracted = document.pdf_of_pages(
            pages,
            retain_numbering=pdflite_cmd_flag_value(args, "retain-numbering"),
            process_struct_tree=pdflite_cmd_flag_value(args, "process-struct-tree"),
          )
          let bytes = @pdf.pdf_write_document(extracted)
          pdf_verify(bytes, pages.length())
          pdf_artifact(pdflite_cmd_single_value(args, "output"), bytes, Json::object({ "pages": Json::number(pages.length().to_double()) }))
        }
        "rewrite" => pdf_candidate(document, pdflite_cmd_single_value(args, "output"))
        "decrypt" => pdf_candidate(document, pdflite_cmd_single_value(args, "output"))
        _ => raise Usage("unknown PDF operation: \{operation}")
      }
    }
  }
}

///|
fn pdf_json_mode(matches : @argparse.Matches) -> Bool {
  if pdflite_cmd_flag_value(matches, "json") || pdflite_cmd_flag_value(matches, "jsonl") {
    return true
  }
  matches.subcommand.map_or(false, child => pdf_json_mode(child.1))
}

///|
fn pdflite_cmd_json_number(value : Int32) -> Json {
  Json::number(value.to_double())
}
