// Style -> Json conversion for the `xlsx.cells/1` payload's dedup style map.
// Every field is emitted only when present (omit-`None` discipline): an
// absent key means the workbook does not set that property, and `null` is
// never emitted.

///|
fn set_string(out : Map[String, Json], key : String, value : String?) -> Unit {
  match value {
    Some(value) => out[key] = Json::string(value)
    None => ()
  }
}

///|
fn set_bool(out : Map[String, Json], key : String, value : Bool?) -> Unit {
  match value {
    Some(value) => out[key] = Json::boolean(value)
    None => ()
  }
}

///|
fn set_int(out : Map[String, Json], key : String, value : Int?) -> Unit {
  match value {
    Some(value) => out[key] = Json::number(value.to_double())
    None => ()
  }
}

///|
fn set_double(out : Map[String, Json], key : String, value : Double?) -> Unit {
  match value {
    Some(value) => out[key] = Json::number(value)
    None => ()
  }
}

///|
/// Converts a resolved `Style` into its `xlsx.cells/1` JSON shape. See
/// docs/agent-json-schemas.md for the normative field list.
pub fn style_to_json(style : @xlsx.Style) -> Json {
  let out : Map[String, Json] = Map([])
  match style.number_format {
    Some(Builtin(id)) => out["num_fmt_id"] = Json::number(id.to_double())
    Some(Custom(code)) => out["number_format"] = Json::string(code)
    None => ()
  }
  if !out.contains("num_fmt_id") {
    set_int(out, "num_fmt_id", style.num_fmt)
  }
  if !out.contains("number_format") {
    set_string(out, "number_format", style.custom_num_fmt)
  }
  match style.font {
    Some(font) => {
      let f : Map[String, Json] = Map([])
      set_bool(f, "bold", font.bold)
      set_bool(f, "italic", font.italic)
      set_bool(f, "strike", font.strike)
      set_string(f, "underline", font.underline)
      set_double(f, "size", font.size)
      set_string(f, "color", font.color)
      // Theme/indexed colors are how most real files color text; without
      // them a themed font would look unset.
      set_int(f, "color_theme", font.color_theme)
      set_int(f, "color_indexed", font.color_indexed)
      set_double(f, "color_tint", font.color_tint)
      set_string(f, "family", font.family)
      if f.length() > 0 {
        out["font"] = Json::object(f)
      }
    }
    None => ()
  }
  match style.fill {
    Some(fill) => {
      let f : Map[String, Json] = Map([])
      set_string(f, "type", fill.typ)
      set_int(f, "pattern", fill.pattern)
      match fill.colors {
        Some(colors) => f["colors"] = Json::array(colors.map(Json::string))
        None => ()
      }
      set_int(f, "fg_theme", fill.fg_theme)
      set_int(f, "fg_indexed", fill.fg_indexed)
      set_double(f, "fg_tint", fill.fg_tint)
      set_int(f, "bg_theme", fill.bg_theme)
      set_int(f, "bg_indexed", fill.bg_indexed)
      set_double(f, "bg_tint", fill.bg_tint)
      if f.length() > 0 {
        out["fill"] = Json::object(f)
      }
    }
    None => ()
  }
  match style.border {
    Some(borders) => {
      let sides = []
      for border in borders {
        let side : Map[String, Json] = { "side": Json::string(border.typ) }
        set_int(side, "style", border.style)
        set_string(side, "color", border.color)
        sides.push(Json::object(side))
      }
      if sides.length() > 0 {
        out["border"] = Json::array(sides)
      }
    }
    None => ()
  }
  match style.alignment {
    Some(alignment) => {
      let a : Map[String, Json] = Map([])
      set_string(a, "horizontal", alignment.horizontal)
      set_string(a, "vertical", alignment.vertical)
      set_bool(a, "wrap_text", alignment.wrap_text)
      set_int(a, "text_rotation", alignment.text_rotation)
      set_int(a, "indent", alignment.indent)
      set_bool(a, "shrink_to_fit", alignment.shrink_to_fit)
      if a.length() > 0 {
        out["alignment"] = Json::object(a)
      }
    }
    None => ()
  }
  match style.protection {
    Some(protection) => {
      let p : Map[String, Json] = Map([])
      set_bool(p, "hidden", protection.hidden)
      set_bool(p, "locked", protection.locked)
      if p.length() > 0 {
        out["protection"] = Json::object(p)
      }
    }
    None => ()
  }
  Json::object(out)
}
