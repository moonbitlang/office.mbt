///|
// SVG backend: transcribe one page-model page into deterministic,
// self-contained SVG. The output stays inside svgdiff's supported subset
// (positioned text, solid fills, data-URL raster images; no CSS classes,
// filters, masks, gradients, or animation) so golden comparisons report
// complete coverage. Text is positioned per code unit via an explicit
// `x` list built from the run's own advances — a viewer with different
// fonts cannot shift our layout.

///|
/// Format a coordinate with at most three decimals (trailing zeros and
/// dot trimmed), rounding half away from zero. Three decimals of a point
/// is ~0.35µm — far below visibility — and keeps goldens byte-stable.
fn fmt_num(v : Double) -> String {
  let scaled = v * 1000.0
  let rounded = if scaled >= 0 {
    (scaled + 0.5).to_int64()
  } else {
    (scaled - 0.5).to_int64()
  }
  let whole = rounded / 1000
  let frac = (if rounded < 0 { -rounded } else { rounded }) % 1000
  if frac == 0 {
    whole.to_string()
  } else {
    let sign = if rounded < 0 && whole == 0 { "-" } else { "" }
    let mut digits = frac.to_string()
    while digits.length() < 3 {
      digits = "0" + digits
    }
    while digits.length() > 0 && digits[digits.length() - 1] == '0' {
      digits = digits[0:digits.length() - 1].to_owned()
    }
    "\{sign}\{whole}.\{digits}"
  }
}

///|
fn escape_xml(text : String) -> String {
  let sb = StringBuilder()
  for c in text {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&apos;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
let base64_alphabet : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
fn base64_encode(data : Bytes) -> String {
  let sb = StringBuilder()
  let n = data.length()
  let mut i = 0
  while i + 2 < n {
    let chunk = (data[i].to_int() << 16) |
      (data[i + 1].to_int() << 8) |
      data[i + 2].to_int()
    sb.write_char(base64_alphabet.get_char((chunk >> 18) & 63).unwrap())
    sb.write_char(base64_alphabet.get_char((chunk >> 12) & 63).unwrap())
    sb.write_char(base64_alphabet.get_char((chunk >> 6) & 63).unwrap())
    sb.write_char(base64_alphabet.get_char(chunk & 63).unwrap())
    i += 3
  }
  if i + 1 == n {
    let chunk = data[i].to_int() << 16
    sb.write_char(base64_alphabet.get_char((chunk >> 18) & 63).unwrap())
    sb.write_char(base64_alphabet.get_char((chunk >> 12) & 63).unwrap())
    sb.write_string("==")
  } else if i + 2 == n {
    let chunk = (data[i].to_int() << 16) | (data[i + 1].to_int() << 8)
    sb.write_char(base64_alphabet.get_char((chunk >> 18) & 63).unwrap())
    sb.write_char(base64_alphabet.get_char((chunk >> 12) & 63).unwrap())
    sb.write_char(base64_alphabet.get_char((chunk >> 6) & 63).unwrap())
    sb.write_string("=")
  }
  sb.to_string()
}

///|
fn emit_text(
  sb : StringBuilder,
  model : @pagelayout.PageModel,
  run : @pagelayout.GlyphRun,
) -> Unit {
  if run.text.length() == 0 {
    return
  }
  let font = model.fonts[run.font]
  // one x per code unit, from the run's own advances (trail surrogates
  // carry advance 0 and are covered by their lead's position)
  let xs = StringBuilder()
  let mut x = run.x_pt
  let mut first = true
  let mut i = 0
  while i < run.text.length() {
    let unit = run.text[i].to_int()
    if !(unit >= 0xDC00 && unit <= 0xDFFF) {
      if !first {
        xs.write_string(" ")
      }
      xs.write_string(fmt_num(x))
      first = false
    }
    x += run.advances_pt[i]
    i += 1
  }
  sb.write_string("  <text x=\"")
  sb.write_string(xs.to_string())
  sb.write_string("\" y=\"")
  sb.write_string(fmt_num(run.baseline_pt))
  sb.write_string("\" font-family=\"")
  sb.write_string(escape_xml(font.family))
  sb.write_string("\" font-size=\"")
  sb.write_string(fmt_num(run.size_pt))
  sb.write_string("\"")
  if font.bold {
    sb.write_string(" font-weight=\"bold\"")
  }
  if font.italic {
    sb.write_string(" font-style=\"italic\"")
  }
  sb.write_string(" fill=\"")
  sb.write_string(run.color.to_hex())
  sb.write_string("\">")
  sb.write_string(escape_xml(run.text))
  sb.write_string("</text>\n")
}

///|
fn emit_rect(sb : StringBuilder, rect : @pagelayout.RectItem) -> Unit {
  sb.write_string("  <rect x=\"")
  sb.write_string(fmt_num(rect.x_pt))
  sb.write_string("\" y=\"")
  sb.write_string(fmt_num(rect.y_pt))
  sb.write_string("\" width=\"")
  sb.write_string(fmt_num(rect.w_pt))
  sb.write_string("\" height=\"")
  sb.write_string(fmt_num(rect.h_pt))
  sb.write_string("\" fill=\"")
  match rect.fill {
    Some(color) => sb.write_string(color.to_hex())
    None => sb.write_string("none")
  }
  sb.write_string("\"")
  match rect.stroke {
    Some(color) => {
      sb.write_string(" stroke=\"")
      sb.write_string(color.to_hex())
      sb.write_string("\" stroke-width=\"")
      sb.write_string(fmt_num(rect.stroke_w_pt))
      sb.write_string("\"")
    }
    None => ()
  }
  sb.write_string("/>\n")
}

///|
fn emit_image(sb : StringBuilder, image : @pagelayout.ImageItem) -> Unit {
  sb.write_string("  <image x=\"")
  sb.write_string(fmt_num(image.x_pt))
  sb.write_string("\" y=\"")
  sb.write_string(fmt_num(image.y_pt))
  sb.write_string("\" width=\"")
  sb.write_string(fmt_num(image.w_pt))
  sb.write_string("\" height=\"")
  sb.write_string(fmt_num(image.h_pt))
  sb.write_string("\" href=\"data:")
  sb.write_string(image.mime)
  sb.write_string(";base64,")
  sb.write_string(base64_encode(image.data))
  sb.write_string("\"/>\n")
}

///|
/// Render one page as a standalone SVG document. Link regions are
/// non-visual and are emitted as inert metadata-free anchors only when
/// they enclose no visible artwork — v1 skips them entirely.
pub fn render_page(model : @pagelayout.PageModel, page_index : Int) -> String {
  let page = model.pages[page_index]
  let sb = StringBuilder()
  sb.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" +
    fmt_num(page.width_pt) +
    "pt\" height=\"" +
    fmt_num(page.height_pt) +
    "pt\" viewBox=\"0 0 " +
    fmt_num(page.width_pt) +
    " " +
    fmt_num(page.height_pt) +
    "\">\n",
  )
  // explicit page background keeps the golden self-describing
  sb.write_string(
    "  <rect x=\"0\" y=\"0\" width=\"" +
    fmt_num(page.width_pt) +
    "\" height=\"" +
    fmt_num(page.height_pt) +
    "\" fill=\"#ffffff\"/>\n",
  )
  for item in page.items {
    match item {
      Text(run) => emit_text(sb, model, run)
      Rect(rect) => emit_rect(sb, rect)
      Image(image) => emit_image(sb, image)
      Link(_) => () // non-visual; hyperlink regions belong to the PDF backend
    }
  }
  sb.write_string("</svg>\n")
  sb.to_string()
}

///|
/// Render every page, in order.
pub fn render_pages(model : @pagelayout.PageModel) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<model.pages.length() {
    out.push(render_page(model, i))
  }
  out
}
