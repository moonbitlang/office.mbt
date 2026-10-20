///|
priv struct TextStyle {
  font : @pagelayout.FontSpec
  face : @fonts.FaceMetrics
  size : Double
  spacing : Double
  color : @pagelayout.Color
  alpha : Double
  underline : Bool
  language : String
  source : @slide.RunProperties
}

///|
priv struct TextSpan {
  start : Int32
  end : Int32
  style : TextStyle
}

///|
priv struct TextLine {
  baseline : Double
  x : Double
  text : String
  range : @linebreak.LineRange
  advances : Array[Double]
  spans : Array[TextSpan]
  end_adjustments : Array[Double]
  visible_end : Int32
  bullet : (String, TextStyle, Double)?
}

///|
priv struct KerningState {
  mut previous : (Int32, TextStyle, Int32)?
}

///|
fn text_style(
  context : SlideContext,
  properties : @slide.RunProperties,
  cjk : Bool,
  codepoint~ : Int32 = 32,
) -> TextStyle raise {
  if properties.underline is Some(kind) && kind != UlNone && kind != UlSingle {
    raise Unsupported("underline style in \{context.part}")
  }
  if properties.strikethrough is Some(kind) && kind != StNoStrike {
    raise Unsupported("strikethrough in \{context.part}")
  }
  if properties.caps is Some(kind) && kind != CapsNone {
    raise Unsupported("capitalisation transform in \{context.part}")
  }
  if properties.baseline is Some(value) && value.value() != 0 {
    raise Unsupported("superscript or subscript in \{context.part}")
  }
  if properties.text_effects is Some(effects) &&
    effects != @oxml.EffectList::empty() {
    raise Unsupported("text effects in \{context.part}")
  }
  if properties.highlight is Some(_) || properties.outline is Some(_) {
    raise Unsupported("text highlight or outline in \{context.part}")
  }
  let family = if cjk {
    properties.east_asian.unwrap_or(properties.latin.unwrap_or("Arial"))
  } else {
    properties.latin.unwrap_or(properties.east_asian.unwrap_or("Arial"))
  }
  let family = if family.has_prefix("+") {
    context.theme
    .map(theme => {
      let resolved = theme.font_scheme.resolve_typeface(family)
      if resolved != "" || !cjk {
        return resolved
      }
      let collection = if family.has_prefix("+mj") {
        theme.font_scheme.major_font
      } else {
        theme.font_scheme.minor_font
      }
      let script = if (codepoint >= 0x3040 && codepoint <= 0x30ff) ||
        (codepoint >= 0x31f0 && codepoint <= 0x31ff) {
        "Jpan"
      } else if (codepoint >= 0xac00 && codepoint <= 0xd7af) ||
        (codepoint >= 0x1100 && codepoint <= 0x11ff) {
        "Hang"
      } else if properties.lang.has_prefix("zh-TW") ||
        properties.lang.has_prefix("zh-HK") ||
        properties.lang.has_prefix("zh-MO") {
        "Hant"
      } else {
        "Hans"
      }
      collection.typeface_for_script(script)
    })
    .unwrap_or(family)
  } else {
    family
  }
  let mut primary_family = family
  if !context.fonts.is_registered(primary_family) &&
    !@fonts.bundled_families().contains(primary_family) {
    let fallback = context.font_fallbacks
      .get(family)
      .unwrap_or([])
      .iter()
      .find_first(candidate => {
        context.fonts.is_registered(candidate) ||
        @fonts.bundled_families().contains(candidate)
      })
    primary_family = match fallback {
      Some(family) => family
      None if context.allow_bundled_fallbacks => @fonts.resolve_family(family)
      None => raise MissingFont(family)
    }
  }

  let bold = properties.bold.unwrap_or(false)
  let italic = properties.italic.unwrap_or(false)
  let primary = context.fonts.face(primary_family, bold~, italic~)
  let mut face = primary
  if !face.has_char(codepoint) {
    for candidate in context.font_fallbacks.get(family).unwrap_or([]) {
      if !context.fonts.is_registered(candidate) &&
        !@fonts.bundled_families().contains(candidate) {
        continue
      }
      let fallback = context.fonts.face(candidate, bold~, italic~)
      if fallback.has_char(codepoint) {
        face = fallback
        break
      }
    }
    if !face.has_char(codepoint) && cjk {
      face = context.fonts.cjk_fallback(bold~, italic~)
    }
  }
  if face.family != family {
    context.font_substitutions[family + " → " + face.family] = ()
  }
  let (color, alpha) = match properties.fill {
    Some(fill) => fill_color(context, fill).unwrap_or((@pagelayout.black, 0.0))
    None => (@pagelayout.black, 1.0)
  }
  {
    font: { family: face.family, bold, italic, },
    face,
    size: properties.font_size.map(size => size.value()).unwrap_or(18.0),
    spacing: properties.character_spacing
    .map(spacing => spacing.value())
    .unwrap_or(0.0),
    color,
    alpha,
    underline: properties.underline is Some(kind) && kind != UlNone,
    language: properties.lang,
    source: properties,
  }
}

///|
fn append_text(
  context : SlideContext,
  builder : StringBuilder,
  spans : Array[TextSpan],
  advances : Array[Double],
  end_adjustments : Array[Double],
  text : String,
  properties : @slide.RunProperties,
  kerning : KerningState,
) -> Unit raise {
  let mut start = 0
  while start < text.length() {
    let first = text.get_char(start).unwrap()
    let is_cjk = @linebreak.is_cjk(first.to_int())
    let style = text_style(
      context,
      properties,
      is_cjk,
      codepoint=first.to_int(),
    )
    let mut end = start
    let offset = advances.length()
    while end < text.length() {
      let ch = text.get_char(end).unwrap()
      if @linebreak.is_cjk(ch.to_int()) != is_cjk {
        break
      }
      let code = ch.to_int()
      if code == 9 {
        raise Unsupported("text tab stops in \{context.part}")
      }
      let resolved = text_style(context, properties, is_cjk, codepoint=code)
      if resolved.font != style.font {
        break
      }
      if code != 10 && code != 9 && !style.face.has_char(code) {
        raise MissingFont(
          "\{style.font.family} lacks U+\{code.to_string(radix=16)}",
        )
      }
      let glyph_index = advances.length()
      if code == 10 || code == 9 {
        kerning.previous = None
      } else {
        if kerning.previous is Some((previous, previous_style, previous_index)) &&
          previous_style.font == style.font &&
          previous_style.size == style.size &&
          kerning_enabled(properties, style.size) &&
          kerning_enabled(previous_style.source, previous_style.size) {
          let adjustment = (style.face.kerning_pt(previous, code, style.size) *
            100).round() /
            100
          advances[previous_index] += adjustment
          let previous_end = previous_index +
            (if previous > 0xffff { 1 } else { 0 })
          end_adjustments[previous_end] += adjustment
        }
        kerning.previous = Some((code, style, glyph_index))
      }
      advances.push(
        if code == 10 {
          0.0
        } else {
          pptx_advance(style.face.advance_pt(code, style.size)) + style.spacing
        },
      )
      if code > 0xffff {
        end_adjustments.push(0.0)
        end_adjustments.push(style.spacing)
        advances.push(0.0)
        end += 2
      } else {
        end_adjustments.push(if code == 10 { 0.0 } else { style.spacing })
        end += 1
      }
    }
    builder.write_view(text[start:end])
    spans.push({ start: offset, end: advances.length(), style, })
    start = end
  }
}

///|
fn spacing_value(
  source : @slide.TextSpacing?,
  size : Double,
  default : Double,
) -> Double {
  match source {
    Some(Points(value)) => value.value()
    Some(Percent(value)) => size * value.value() / 100.0
    None => default
  }
}

///|
fn draw_text(
  context : SlideContext,
  body : @slide.TextBody,
  width : Double,
  height : Double,
  ops : Array[@pagelayout.GraphicOp],
) -> Unit raise {
  let properties = body.body_properties.unwrap_or(
    @slide.BodyProperties::default(),
  )
  if properties.rotation is Some(angle) && angle.degrees() != 0 {
    raise Unsupported("text-body rotation in \{context.part}")
  }
  if properties.vertical_text is Some(kind) && kind != VertHorz {
    raise Unsupported("vertical text in \{context.part}")
  }
  match properties.auto_fit {
    Some(NormAutoFit(scale, reduction)) if scale.value() != 100 ||
      reduction.value() != 0 =>
      raise Unsupported("text auto-fit in \{context.part}")
    Some(SpAutoFit) => raise Unsupported("shape auto-fit in \{context.part}")
    _ => ()
  }
  let left = properties.left_inset.map(emu).unwrap_or(7.2)
  let right = properties.right_inset.map(emu).unwrap_or(7.2)
  let top = properties.top_inset.map(emu).unwrap_or(3.6)
  let bottom = properties.bottom_inset.map(emu).unwrap_or(3.6)
  let mut y = 0.0
  let placed : Array[TextLine] = []
  for paragraph in body.paragraphs {
    let builder = StringBuilder()
    let spans : Array[TextSpan] = []
    let advances : Array[Double] = []
    let end_adjustments : Array[Double] = []
    let kerning = KerningState::{ previous: None, }
    for content in paragraph.content {
      match content {
        RunContent(run) =>
          append_text(
            context,
            builder,
            spans,
            advances,
            end_adjustments,
            run.text,
            run.properties,
            kerning,
          )
        FieldContent(field) =>
          append_text(
            context,
            builder,
            spans,
            advances,
            end_adjustments,
            field.text,
            field.properties,
            kerning,
          )
        Break(properties) =>
          append_text(
            context, builder, spans, advances, end_adjustments, "\n", properties,
            kerning,
          )
      }
    }
    let text = builder.to_string()
    if spans.is_empty() && paragraph.end_run_properties is None {
      continue
    }
    let end_style = match paragraph.end_run_properties {
      Some(properties) => text_style(context, properties, false)
      None => spans[spans.length() - 1].style
    }
    let mut ascent = end_style.face.ascent_pt(end_style.size)
    let mut descent = -end_style.face.typographic_descent_pt(end_style.size)
    let mut natural_height = end_style.face.typographic_line_height_pt(
      end_style.size,
    )
    let mut size = 18.0
    if spans.is_empty() {
      let style = text_style(
        context,
        paragraph.end_run_properties.unwrap_or(@slide.RunProperties::default()),
        false,
      )
      ascent = style.face.ascent_pt(style.size)
      descent = -style.face.typographic_descent_pt(style.size)
      size = style.size
    } else {
      size = 0.0
      for span in spans {
        ascent = @cmp.maximum(
          ascent,
          span.style.face.ascent_pt(span.style.size),
        )
        descent = @cmp.maximum(
          descent,
          -span.style.face.typographic_descent_pt(span.style.size),
        )
        natural_height = @cmp.maximum(
          natural_height,
          span.style.face.typographic_line_height_pt(span.style.size),
        )
        size = @cmp.maximum(size, span.style.size)
      }
    }
    let p = paragraph.properties
    if p.rtl is Some(true) {
      raise Unsupported("right-to-left paragraph in \{context.part}")
    }
    match p.alignment {
      None | Some(AlignLeft | AlignCenter | AlignRight) => ()
      _ => raise Unsupported("paragraph justification in \{context.part}")
    }
    let line_height = spacing_value(
      p.line_spacing,
      natural_height,
      natural_height,
    )
    let baseline_offset = match p.line_spacing {
      Some(Points(_)) => line_height - descent
      _ => ascent + (line_height - natural_height) / 2.0
    }
    y += spacing_value(p.space_before, size, 0.0)
    let margin = p.margin_left.map(emu).unwrap_or(0.0)
    let indent = p.indent.map(emu).unwrap_or(0.0)
    let available = width - left - right - margin
    let has_bullet = p.bullet is Some(Char(_) | AutoNum(_, _) | Picture(_))
    let text_indent = if has_bullet { 0.0 } else { indent }
    let lines = if properties.wrap is Some(WrapNone) {
      @linebreak.break_lines(text, advances, 1.0e15, 1.0e15, line_end_adjustment=end => {
        end_adjustments.get(end - 1).unwrap_or(0.0)
      })
    } else {
      @linebreak.break_lines(
        text,
        advances,
        available - text_indent,
        available,
        line_end_adjustment=end => end_adjustments.get(end - 1).unwrap_or(0.0),
        break_opportunity=(text, index) => {
          pptx_break_at(context, text, index, spans)
        },
      )
    }
    for index, range in lines {
      let first_indent = if index == 0 { text_indent } else { 0.0 }
      let align_offset = match p.alignment {
        Some(AlignCenter) => (available - first_indent - range.width_pt) / 2.0
        Some(AlignRight) => available - first_indent - range.width_pt
        _ => 0.0
      }
      let x = left + margin + first_indent + align_offset
      let bullet = match p.bullet {
        Some(Char(bullet)) if index == 0 && spans.get(0) is Some(span) =>
          Some(
            (
              bullet,
              bullet_style(context, p, span.style.source, bullet),
              left + margin + indent,
            ),
          )
        Some(AutoNum(_, _) | Picture(_)) =>
          raise Unsupported("automatic or picture bullets in \{context.part}")
        _ => None
      }
      let mut visible_end = range.end
      while visible_end > range.start && text[visible_end - 1] == ' ' {
        visible_end -= 1
      }
      placed.push({
        end_adjustments,
        visible_end,
        baseline: y + baseline_offset,
        x,
        text,
        range,
        advances,
        spans,
        bullet,
      })
      y += line_height
    }
    y += spacing_value(p.space_after, size, 0.0)
  }
  let anchor_offset = match properties.anchor {
    Some(AnchorCenter) => (height - top - bottom - y) / 2.0
    Some(AnchorBottom) => height - top - bottom - y
    _ => 0.0
  }
  let shift_y = top + anchor_offset
  for line in placed {
    if line.bullet is Some((text, style, bullet_x)) {
      let measured = @linebreak.measure(text, style.face, style.size)
      ops.push(Alpha(style.alpha, style.alpha))
      ops.push(
        Text({
          font: context.model.add_font(style.font),
          size_pt: style.size,
          x_pt: bullet_x,
          baseline_pt: shift_y + line.baseline,
          text,
          advances_pt: measured.advances_pt.map(pptx_advance),
          color: style.color,
        }),
      )
    }
    let mut x = line.x
    for span in line.spans {
      let start = if span.start > line.range.start {
        span.start
      } else {
        line.range.start
      }
      let end = if span.end < line.range.end {
        span.end
      } else {
        line.range.end
      }
      if end <= start {
        continue
      }
      let text = line.text[start:end].to_owned()
      let advances = line.advances[start:end].to_owned()
      let tail = line.visible_end - 1
      if tail >= start && tail < end {
        let lead = if line.text[tail].to_int() >= 0xDC00 &&
          line.text[tail].to_int() <= 0xDFFF {
          tail - 1
        } else {
          tail
        }
        advances[lead - start] -= line.end_adjustments[tail]
      }
      let style = span.style
      ops.push(Alpha(style.alpha, style.alpha))
      ops.push(
        Text({
          font: context.model.add_font(style.font),
          size_pt: style.size,
          x_pt: x,
          baseline_pt: shift_y + line.baseline,
          text,
          advances_pt: advances,
          color: style.color,
        }),
      )
      if style.underline {
        let mut width = 0.0
        for advance in advances {
          width += advance
        }
        let thickness = style.face.underline_width_pt(style.size)
        let underline_y = shift_y +
          line.baseline +
          style.face.underline_offset_pt(style.size) +
          thickness / 2.0
        ops.push(
          Path({
            segments: [MoveTo(x, underline_y), LineTo(x + width, underline_y)],
            fill: None,
            fill_rule: NonZero,
            stroke: Some(Solid(style.color)),
            stroke_style: {
              ..@pagelayout.StrokeStyle::default(),
              width: Width(thickness),
            },
          }),
        )
      }
      for advance in advances {
        x += advance
      }
    }
  }
}

///|
fn bullet_style(
  context : SlideContext,
  paragraph : @slide.ParagraphProperties,
  source : @slide.RunProperties,
  text : String,
) -> TextStyle raise {
  let mut source = source
  for extension in paragraph.extension {
    if extension.name.uri != @oxml.drawing_ns {
      continue
    }
    match extension.name.local_name {
      "buFont" =>
        if attribute(extension, "typeface") is Some(family) {
          source = {
            ..source,
            latin: Some(family),
            east_asian: Some(family),
            complex_script: Some(family),
          }
        }
      "buSzPct" =>
        if attribute(extension, "val") is Some(value) {
          let scale = @string.parse_int(value).to_double() / 100000.0
          source = {
            ..source,
            font_size: Some(
              Pt(
                source.font_size.map(size => size.value()).unwrap_or(18) * scale,
              ),
            ),
          }
        }
      "buSzPts" =>
        if attribute(extension, "val") is Some(value) {
          source = {
            ..source,
            font_size: Some(Pt(@string.parse_int(value).to_double() / 100.0)),
          }
        }
      _ => ()
    }
  }
  let codepoint = text.get_char(0).map(ch => ch.to_int()).unwrap_or(32)
  let style = text_style(
    context,
    source,
    @linebreak.is_cjk(codepoint),
    codepoint~,
  )
  for ch in text {
    if !style.face.has_char(ch.to_int()) {
      raise MissingFont("\{style.font.family} lacks a bullet glyph")
    }
  }
  style
}

///|
/// DrawingML uses the presentation's kinsoku setting and the run language.
/// Do not impose Japanese punctuation rules on English-language slide text.
fn pptx_break_at(
  context : SlideContext,
  text : String,
  index : Int32,
  spans : Array[TextSpan],
) -> Bool {
  let dash_break = index > 0 &&
    index < text.length() &&
    text[index - 1] == '—' &&
    text[index] != '—'
  let language = spans
    .iter()
    .find_first(span => span.start <= index && span.end > index)
    .map(span => span.style.language.to_lower())
    .unwrap_or("")
  if context.kinsoku is Some(settings) &&
    (
      language == "" ||
      settings.language == "" ||
      language == settings.language ||
      language.has_prefix(settings.language + "-")
    ) {
    if index > 0 && index < text.length() {
      let next = text.get_char(index)
      let unit = text[index - 1].to_int()
      let previous = text.get_char(
        if unit >= 0xdc00 && unit <= 0xdfff && index >= 2 {
          index - 2
        } else {
          index - 1
        },
      )
      if settings.no_start.iter().any(ch => Some(ch) == next) ||
        settings.no_end.iter().any(ch => Some(ch) == previous) {
        return false
      }
    }
    return @linebreak.can_break_at(text, index, apply_default_kinsoku=false) ||
      dash_break
  }
  @linebreak.can_break_at(
    text,
    index,
    apply_default_kinsoku=language.has_prefix("ja") || language.has_prefix("zh"),
  ) ||
  dash_break
}

///|
/// A zero or omitted threshold disables kerning. Positive values enable it
/// from that point size onward, including at a run boundary of the same face.
fn kerning_enabled(properties : @slide.RunProperties, size : Double) -> Bool {
  match properties.kerning {
    Some(threshold) => threshold.value() > 0 && size >= threshold.value()
    None => false
  }
}

///|
/// PowerPoint rounds intrinsic glyph advances to eighths of a point before
/// applying character spacing. Tracking retains its hundredth-point precision.
/// Keep font sizes and shape geometry at their authored precision.
fn pptx_advance(points : Double) -> Double {
  pptx_round(points, 8)
}

///|
fn pptx_round(value : Double, scale : Double) -> Double {
  let scaled = value * scale
  let rounded = if scaled < 0 {
    (scaled - 0.5).to_int64()
  } else {
    (scaled + 0.5).to_int64()
  }
  rounded.to_double() / scale
}
