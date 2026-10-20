///|
priv struct OfficePptxLayout {
  model : @pagelayout.PageModel
  fonts : @layout_fonts.FontRegistry
  font_substitutions : Array[String]
}

///|
/// Read an optional font catalog for slide rendering. Explicit font bytes and
/// fallback chains are shared by measurement and drawing.
async fn office_pptx_layout(
  source : OfficeReadPackage,
  matches : @argparse.Matches,
) -> OfficePptxLayout {
  let fonts = @layout_fonts.FontRegistry::new()
  let fallback : Map[String, Array[String]] = Map([])
  if matches.values.get("font-manifest") is Some([path]) {
    let document = @afs.read_file(path)
    let manifest = @json.parse(document.text())
    guard manifest is Array(entries) else {
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "font manifest must be an array",
        ),
      )
    }
    for entry in entries {
      guard entry
        is {
          "family": String(family),
          "path": String(font_path),
          "bold": False
          | True as bold,
          "italic": False
          | True as italic,
          ..
        } else {
        raise CliFailure(
          @lib.protocol_error(
            "office.invalid_arguments", "font entry needs family, path, bold and italic",
          ),
        )
      }
      let input = @afs.open(font_path, mode=ReadOnly)
      defer input.close()
      guard input.size() <= office_read_max_package_bytes.to_int64() else {
        raise CliFailure(
          @lib.protocol_error(
            "office.pptx.resource_limit", "font program exceeds input byte limit",
          ),
        )
      }
      fonts.register(
        family,
        input.read_all().binary(),
        bold=bold is True,
        italic=italic is True,
      )
      |> ignore
      if entry is { "fallback_for": Array(families), .. } {
        for candidate in families {
          guard candidate is String(source) else {
            raise CliFailure(
              @lib.protocol_error(
                "office.invalid_arguments", "font fallback families must be strings",
              ),
            )
          }
          if !fallback.contains(source) {
            fallback[source] = []
          }
          fallback[source].push(family)
        }
      }
    }
  }
  let layout = @pagelayout_pptx.layout_presentation(
    source.bytes,
    fonts~,
    font_fallbacks=fallback,
    allow_bundled_fallbacks=true,
  ) catch {
    error =>
      raise CliFailure(
        @lib.protocol_error(
          "office.pptx.render_failed",
          "cannot lay out this presentation: \{error}",
        ),
      )
  }
  // Metrics-only bundled faces are sufficient for browser hosts with font
  // sidecars. The CLI must put those same outlines into its offline exports.
  let programs : Map[String, (@pagelayout.FontSpec, Bytes)] = Map([])
  let characters : Map[Int32, Map[Int32, Unit]] = Map([])
  fn record(run : @pagelayout.GlyphRun) {
    if !characters.contains(run.font) {
      characters[run.font] = Map([])
    }
    for char in run.text {
      characters[run.font][char.to_int()] = ()
    }
  }
  for page in layout.model.pages {
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
  }
  for index, font in layout.model.fonts {
    if layout.fonts.registered_face(
        font.family,
        bold=font.bold,
        italic=font.italic,
      )
      is Some(_) {
      continue
    }
    let measured = layout.fonts.face(
      font.family,
      bold=font.bold,
      italic=font.italic,
    )
    if @fontoutlines.browser_sfnt(
        measured.family,
        bold=measured.bold,
        italic=measured.italic,
        codepoints=characters
          .get(index)
          .map(chars => chars.keys().to_array())
          .unwrap_or([]),
      )
      is Some(program) {
      programs["\{measured.family}|\{measured.bold}|\{measured.italic}"] = (
        font, program,
      )
    }
  }
  let catalog = layout.fonts.clone()
  for _, (font, program) in programs {
    catalog.register(font.family, program, bold=font.bold, italic=font.italic)
    |> ignore
  }
  {
    model: layout.model,
    fonts: catalog,
    font_substitutions: layout.font_substitutions,
  }
}

///|
async fn office_preview_render_pptx(
  source : OfficeReadPackage,
  matches : @argparse.Matches,
) -> (String, OfficePreviewStats) {
  let layout = office_pptx_layout(source, matches)
  guard layout.model.pages.length() <= office_render_max_pages else {
    raise CliFailure(
      @lib.protocol_error(
        "office.pptx.resource_limit", "presentation exceeds slide limit",
      ),
    )
  }
  let html = StringBuilder()
  html.write_string(
    "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>",
  )
  html.write_string(@xlsx2html.escape_html(source.file))
  html.write_string(
    "</title><style>body{margin:0;padding:24px;background:#252525;color:#eee;font:14px system-ui}.slide{max-width:1200px;margin:0 auto 24px}.slide svg{display:block;width:100%;height:auto;background:white}.slide figcaption{padding:8px 0}</style></head><body>",
  )
  let mut images = 0
  for index, page in layout.model.pages {
    html.write_string(
      "<figure class=\"slide\" data-slide=\"\{index+1}\"><figcaption>\{index+1} / \{layout.model.pages.length()}</figcaption>",
    )
    let svg = @pagelayout_svg.render_page(
      layout.model,
      index,
      fonts=layout.fonts,
    )
    html.write_string(
      svg
      .strip_prefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
      .unwrap_or(svg)
      .to_owned(),
    )
    html.write_string("</figure>")
    for item in page.items {
      if item is Graphic(graphic) {
        for op in graphic.ops {
          if op is Image(_) {
            images += 1
          }
        }
      }
    }
    guard html.to_string().length() <= office_preview_max_output_bytes else {
      raise CliFailure(
        @lib.protocol_error(
          "office.pptx.resource_limit", "preview exceeds output byte limit",
        ),
      )
    }
  }
  html.write_string("</body></html>")
  (
    html.to_string(),
    {
      charts_rendered: 0,
      charts_placeholder: 0,
      truncated_sheets: [],
      images_embedded: images,
      images_omitted: 0,
      warnings: layout.font_substitutions.map(value => {
        "Font substitution: " + value
      }),
      slides_rendered: Some(layout.model.pages.length()),
    },
  )
}
