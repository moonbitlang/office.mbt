///|
fn emit_fonts(
  sb : StringBuilder,
  model : @pagelayout.PageModel,
  page : @pagelayout.Page,
  fonts : @fonts.FontRegistry,
) -> Unit {
  let used : Map[Int32, Unit] = Map([])
  fn record(run : @pagelayout.GlyphRun) {
    used[run.font] = ()
  }
  for item in page.items {
    match item {
      Text(run) => record(run)
      Graphic(graphic) =>
        for op in graphic.ops {
          match op {
            Text(run) | PaintedText(run, _) => record(run)
            _ => ()
          }
        }
      _ => ()
    }
  }
  let faces : Map[String, @fonts.RegisteredFace] = Map([])
  for font_id, _ in used {
    let font = model.fonts[font_id]
    guard fonts.registered_face(font.family, bold=font.bold, italic=font.italic)
      is Some(face) &&
      face.sfnt is Some(_) else {
      continue
    }
    let key = "\{face.metrics.family}|\{face.metrics.bold}|\{face.metrics.italic}"
    faces[key] = face
  }
  let keys = faces.keys().to_array()
  keys.sort()
  for key in keys {
    let face = faces[key]
    let program = face.sfnt.unwrap()
    // PDF subsets intentionally omit browser-required OS/2, name and post
    // tables. Keep the original sfnt so OpenType sanitizers accept the face.
    let data = program
    let family = face.metrics.family
      .replace(old="\\", new="\\\\")
      .replace(old="'", new="\\'")
      .replace(old="<", new="\\3c ")
      .replace(old="\n", new=" ")
      .replace(old="\r", new=" ")
    sb.write_string("<style>@font-face{font-family:'")
    sb.write_string(escape_xml(family))
    sb.write_string("';font-weight:")
    sb.write_string(if face.metrics.bold { "bold" } else { "normal" })
    sb.write_string(";font-style:")
    sb.write_string(if face.metrics.italic { "italic" } else { "normal" })
    sb.write_string(";src:url(data:font/otf;base64,")
    sb.write_string(base64_encode(data))
    sb.write_string(")}</style>\n")
  }
}
