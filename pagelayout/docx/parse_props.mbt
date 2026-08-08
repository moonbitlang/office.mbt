///|
// Readers for the OOXML property elements the layout engine needs.
// Deliberately narrow: these read `w:rPr` and `w:pPr` subtrees only, and
// keep every quantity in its authored unit (twips, half-points) so the
// unit types in the root package do the converting.

///|
fn attr(el : @xml.XmlElement, name : String) -> String? {
  el.attributes.get(name)
}

///|
/// OOXML measurement attributes are either a bare integer in the
/// attribute's own unit, or a "universal measure" — a decimal with a
/// `cm`/`mm`/`in`/`pt`/`pc`/`pi` suffix (ECMA-376 §22.9.2.15). Returns the
/// value in the attribute's native unit, given how many of that unit make
/// one inch. Overflow is rejected rather than wrapped.
fn parse_measure(text : String?, per_inch : Double) -> Int? {
  guard text is Some(s) else { return None }
  let trimmed = s.trim(chars=" \t\r\n")
  if trimmed.length() == 0 {
    return None
  }
  // split a trailing alphabetic unit off the numeric head
  let mut split = trimmed.length()
  while split > 0 {
    let c = trimmed[split - 1].to_int()
    let alpha = (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)
    if !alpha {
      break
    }
    split -= 1
  }
  let number = trimmed[0:split]
  let unit = trimmed[split:].to_lower()
  guard parse_decimal(number.to_owned()) is Some(value) else { return None }
  let inches = match unit {
    "" => return clamp_to_int(value) // already in the attribute's unit
    "in" => value
    "cm" => value / 2.54
    "mm" => value / 25.4
    "pt" => value / 72.0
    "pc" | "pi" => value / 6.0
    _ => return None
  }
  clamp_to_int(inches * per_inch)
}

///|
/// Reject values that would not survive the 32-bit `Int` the unit types
/// carry, rather than wrapping them into arbitrary (often negative) sizes.
fn clamp_to_int(value : Double) -> Int? {
  if value.is_nan() || value > 2147483000.0 || value < -2147483000.0 {
    None
  } else {
    Some(value.to_int())
  }
}

///|
fn parse_decimal(s : String) -> Double? {
  if s.length() == 0 {
    return None
  }
  let negative = s[0] == '-'
  let start = if negative || s[0] == '+' { 1 } else { 0 }
  let mut whole = 0.0
  let mut frac = 0.0
  let mut scale = 1.0
  let mut seen_dot = false
  let mut digits = 0
  for i in start..<s.length() {
    let c = s[i].to_int()
    if c == '.'.to_int() {
      if seen_dot {
        return None
      }
      seen_dot = true
      continue
    }
    if c < 0x30 || c > 0x39 {
      return None
    }
    digits += 1
    if seen_dot {
      scale /= 10.0
      frac += (c - 0x30).to_double() * scale
    } else {
      whole = whole * 10.0 + (c - 0x30).to_double()
    }
  }
  if digits == 0 {
    return None
  }
  let value = whole + frac
  Some(if negative { -value } else { value })
}

///|
/// Twips-valued attributes (indents, spacing, page size and margins).
fn parse_twips(text : String?) -> Int? {
  parse_measure(text, 1440.0)
}

///|
/// Half-point-valued attributes (`w:sz`).
fn parse_half_points(text : String?) -> Int? {
  parse_measure(text, 144.0)
}

///|
/// Unitless integer attributes (`w:line`, toggles' numeric forms).
fn parse_int(text : String?) -> Int? {
  parse_measure(text, 1.0)
}

///|
/// OOXML on/off toggles: absent `w:val` means on; "0"/"false"/"off" mean
/// off; anything else means on.
fn parse_toggle(el : @xml.XmlElement) -> Bool {
  match attr(el, "w:val") {
    None => true
    Some(v) =>
      match v {
        "0" | "false" | "off" => false
        _ => true
      }
  }
}

///|
/// `w:color` values are `RRGGBB` hex, or "auto" (which means "let the
/// consumer decide" — we take Word's black).
fn parse_hex_color(value : String) -> @pagelayout.Color? {
  if value == "auto" {
    return Some(@pagelayout.black)
  }
  if value.length() != 6 {
    return None
  }
  let channels : Array[Int] = []
  for pair in 0..<3 {
    let mut byte = 0
    for offset in 0..<2 {
      let c = value[pair * 2 + offset].to_int()
      let digit = if c >= 0x30 && c <= 0x39 {
        c - 0x30
      } else if c >= 0x61 && c <= 0x66 {
        c - 0x61 + 10
      } else if c >= 0x41 && c <= 0x46 {
        c - 0x41 + 10
      } else {
        return None
      }
      byte = byte * 16 + digit
    }
    channels.push(byte)
  }
  Some(@pagelayout.Color::rgb(channels[0], channels[1], channels[2]))
}

///|
/// Read a `w:rPr` element into partial character formatting.
pub fn read_run_props(
  rpr : @xml.XmlElement,
  theme? : ThemeFonts = ThemeFonts::empty(),
) -> RunProps {
  let mut props = RunProps::empty()
  for child in rpr.children {
    guard child is XmlElement(el) else { continue }
    match el.name {
      "w:rFonts" => {
        // ascii covers Latin; eastAsia is the CJK family. The engine's
        // per-character fallback handles the CJK side, so the ascii
        // family (falling back to eastAsia) is what we carry. A direct
        // family wins over a theme reference, per ECMA-376.
        let direct = match attr(el, "w:ascii") {
          Some(f) => Some(f)
          None => attr(el, "w:eastAsia")
        }
        let family = match direct {
          Some(f) => Some(f)
          None => {
            let reference = match attr(el, "w:asciiTheme") {
              Some(r) => Some(r)
              None =>
                match attr(el, "w:hAnsiTheme") {
                  Some(r) => Some(r)
                  None => attr(el, "w:eastAsiaTheme")
                }
            }
            match reference {
              Some(r) => theme.resolve(r)
              None => None
            }
          }
        }
        match family {
          Some(f) => props = { ..props, family: Some(f) }
          None => ()
        }
      }
      "w:sz" =>
        match parse_half_points(attr(el, "w:val")) {
          Some(hp) => props = { ..props, size: Some(HalfPoints(hp)) }
          None => ()
        }
      "w:b" => props = { ..props, bold: Some(parse_toggle(el)) }
      "w:i" => props = { ..props, italic: Some(parse_toggle(el)) }
      "w:color" =>
        match attr(el, "w:val") {
          Some(v) =>
            match parse_hex_color(v) {
              Some(c) => props = { ..props, color: Some(c) }
              None => ()
            }
          None => ()
        }
      _ => ()
    }
  }
  props
}

///|
fn read_indent(el : @xml.XmlElement, props : ParaProps) -> ParaProps {
  let mut out = props
  // strict OOXML uses start/end; transitional uses left/right
  let left = match attr(el, "w:left") {
    Some(v) => Some(v)
    None => attr(el, "w:start")
  }
  let right = match attr(el, "w:right") {
    Some(v) => Some(v)
    None => attr(el, "w:end")
  }
  match parse_twips(left) {
    Some(v) => out = { ..out, indent_left: Some(Twips(v)) }
    None => ()
  }
  match parse_twips(right) {
    Some(v) => out = { ..out, indent_right: Some(Twips(v)) }
    None => ()
  }
  // hanging is a negative first-line indent; firstLine is positive
  match parse_twips(attr(el, "w:hanging")) {
    Some(v) => out = { ..out, indent_first: Some(Twips(-v)) }
    None =>
      match parse_twips(attr(el, "w:firstLine")) {
        Some(v) => out = { ..out, indent_first: Some(Twips(v)) }
        None => ()
      }
  }
  out
}

///|
fn read_spacing(el : @xml.XmlElement, props : ParaProps) -> ParaProps {
  let mut out = props
  match parse_twips(attr(el, "w:before")) {
    Some(v) => out = { ..out, space_before: Some(Twips(v)) }
    None => ()
  }
  match parse_twips(attr(el, "w:after")) {
    Some(v) => out = { ..out, space_after: Some(Twips(v)) }
    None => ()
  }
  match parse_int(attr(el, "w:line")) {
    Some(line) => {
      // w:lineRule: "auto" means line/240 of a single line; "exact" and
      // "atLeast" give the height directly in twips
      let rule = attr(el, "w:lineRule").unwrap_or("auto")
      let spacing : @paragraph.LineSpacing = match rule {
        "exact" => Exact(@pagelayout.Twips(line).to_pt())
        "atLeast" => AtLeast(@pagelayout.Twips(line).to_pt())
        _ => Multiple(line.to_double() / 240.0)
      }
      out = { ..out, line_spacing: Some(spacing) }
    }
    None => ()
  }
  out
}

///|
/// Read a `w:pPr` element into partial paragraph formatting. Returns the
/// properties and the referenced style id (`w:pStyle`), if any.
pub fn read_para_props(ppr : @xml.XmlElement) -> (ParaProps, String?) {
  let mut props = ParaProps::empty()
  let mut style_id : String? = None
  for child in ppr.children {
    guard child is XmlElement(el) else { continue }
    match el.name {
      "w:pStyle" => style_id = attr(el, "w:val")
      "w:jc" =>
        match attr(el, "w:val") {
          Some(v) => {
            let align : @paragraph.Alignment? = match v {
              "center" => Some(AlignCenter)
              "right" | "end" => Some(AlignRight)
              "both" | "distribute" => Some(AlignJustify)
              "left" | "start" => Some(AlignLeft)
              _ => None
            }
            match align {
              Some(a) => props = { ..props, align: Some(a) }
              None => ()
            }
          }
          None => ()
        }
      "w:ind" => props = read_indent(el, props)
      "w:spacing" => props = read_spacing(el, props)
      "w:keepLines" => props = { ..props, keep_lines: Some(parse_toggle(el)) }
      "w:keepNext" => props = { ..props, keep_next: Some(parse_toggle(el)) }
      "w:widowControl" =>
        props = { ..props, widow_control: Some(parse_toggle(el)) }
      "w:pageBreakBefore" =>
        props = { ..props, page_break_before: Some(parse_toggle(el)) }
      _ => ()
    }
  }
  (props, style_id)
}

///|
/// Read `w:sectPr` page geometry. Missing values keep Word's defaults
/// (US Letter, 1in margins).
pub fn read_section_props(sectpr : @xml.XmlElement) -> @paginate.SectionProps {
  let mut section = @paginate.SectionProps::default()
  for child in sectpr.children {
    guard child is XmlElement(el) else { continue }
    match el.name {
      "w:pgSz" => {
        match parse_twips(attr(el, "w:w")) {
          Some(w) =>
            section = { ..section, page_width_pt: @pagelayout.Twips(w).to_pt() }
          None => ()
        }
        match parse_twips(attr(el, "w:h")) {
          Some(h) =>
            section = {
              ..section,
              page_height_pt: @pagelayout.Twips(h).to_pt(),
            }
          None => ()
        }
      }
      "w:pgMar" => {
        match parse_twips(attr(el, "w:top")) {
          Some(v) =>
            section = { ..section, margin_top_pt: @pagelayout.Twips(v).to_pt() }
          None => ()
        }
        match parse_twips(attr(el, "w:bottom")) {
          Some(v) =>
            section = {
              ..section,
              margin_bottom_pt: @pagelayout.Twips(v).to_pt(),
            }
          None => ()
        }
        match parse_twips(attr(el, "w:left")) {
          Some(v) =>
            section = {
              ..section,
              margin_left_pt: @pagelayout.Twips(v).to_pt(),
            }
          None => ()
        }
        match parse_twips(attr(el, "w:right")) {
          Some(v) =>
            section = {
              ..section,
              margin_right_pt: @pagelayout.Twips(v).to_pt(),
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  section
}
