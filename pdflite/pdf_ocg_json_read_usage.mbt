///|
fn pdf_ocg_read_json_usage(json : Json) -> PdfOcgUsage? raise PdfError {
  match json {
    Null => None
    Object(entries) if entries.length() == 13 => {
      let cc = pdf_ocg_read_json_field(
        entries, "CreatorInfo-Creator", "ocg_read_usage: malformed",
      )
      let cs = pdf_ocg_read_json_field(
        entries, "CreatorInfo-Subtype", "ocg_read_usage: malformed",
      )
      let ll = pdf_ocg_read_json_field(
        entries, "Language-Language", "ocg_read_usage: malformed",
      )
      let lp = pdf_ocg_read_json_field(
        entries, "Language-Preferred", "ocg_read_usage: malformed",
      )
      let e = pdf_ocg_read_json_field(
        entries, "Export", "ocg_read_usage: malformed",
      )
      let zmin = pdf_ocg_read_json_field(
        entries, "Zoom-Min", "ocg_read_usage: malformed",
      )
      let zmax = pdf_ocg_read_json_field(
        entries, "Zoom-Max", "ocg_read_usage: malformed",
      )
      let ps = pdf_ocg_read_json_field(
        entries, "Print-Subtype", "ocg_read_usage: malformed",
      )
      let pp = pdf_ocg_read_json_field(
        entries, "Print-PrintState", "ocg_read_usage: malformed",
      )
      let vs = pdf_ocg_read_json_field(
        entries, "ViewState", "ocg_read_usage: malformed",
      )
      let ut = pdf_ocg_read_json_field(
        entries, "User-Type", "ocg_read_usage: malformed",
      )
      let un = pdf_ocg_read_json_field(
        entries, "User-Name", "ocg_read_usage: malformed",
      )
      let pes = pdf_ocg_read_json_field(
        entries, "PageElement-Subtype", "ocg_read_usage: malformed",
      )
      let creator_info = match (cc, cs) {
        (Null, Null) => None
        (String(creator), String(subtype)) =>
          Some(
            (
              pdf_pdfdocstring_of_utf8(@utf8.encode(creator)),
              pdf_ocg_read_json_name_text(subtype),
            ),
          )
        _ => raise SoftError("ocg_read_usage: malformed creator info")
      }
      let language = match (ll, lp) {
        (Null, Null) => None
        (String(language), String(preferred)) =>
          Some(
            (
              pdf_pdfdocstring_of_utf8(@utf8.encode(language)),
              Some(pdf_ocg_read_json_name_text(preferred)),
            ),
          )
        (String(language), Null) =>
          Some((pdf_pdfdocstring_of_utf8(@utf8.encode(language)), None))
        _ => raise SoftError("ocg_read_usage: malformed language")
      }
      let user = match (ut, un) {
        (Null, Null) => None
        (String(user_type), Array(_)) =>
          Some(
            (
              pdf_ocg_read_json_name_text(user_type),
              pdf_ocg_read_json_pdf_strings(
                un, "ocg_read_usage: malformed user",
              ),
            ),
          )
        _ => raise SoftError("ocg_read_usage: malformed user")
      }
      Some({
        creator_info,
        language,
        export_state: pdf_ocg_read_json_optional_name(
          e, "ocg_read_usage: malformed export",
        ),
        zoom_min: pdf_ocg_read_json_optional_number(
          zmin, "ocg_read_usage: malformed zoom min",
        ),
        zoom_max: pdf_ocg_read_json_optional_number(
          zmax, "ocg_read_usage: malformed zoom max",
        ),
        print_subtype: pdf_ocg_read_json_optional_name(
          ps, "ocg_read_usage: malformed print subtype",
        ),
        print_state: pdf_ocg_read_json_optional_name(
          pp, "ocg_read_usage: malformed print printstate",
        ),
        view_state: pdf_ocg_read_json_optional_name(
          vs, "ocg_read_usage: malformed print viewstate",
        ),
        user,
        page_element_subtype: pdf_ocg_read_json_optional_name(
          pes, "ocg_read_usage: malformed subtype",
        ),
      })
    }
    _ => raise SoftError("ocg_read_usage: malformed")
  }
}
