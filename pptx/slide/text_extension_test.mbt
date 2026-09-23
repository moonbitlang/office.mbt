// Modified for office.mbt: follow the workspace warning conventions.
// Lossless preservation tests for the text-side parsers.
// Targets the `extension` fields on TextBody, Paragraph, Run, Field,
// BodyProperties, ParagraphProperties, RunProperties, and ListStyle.

///|
test "TextBody captures foreign-namespace child" {
  let inner = "<a:bodyPr/><x:ext xmlns:x=\"http://example.org/ext\"/>" +
    "<a:p><a:r><a:t>Hi</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let tb = first_auto_shape(slide).text_body.unwrap()
  debug_inspect(tb.extension.length(), content="1")
  debug_inspect(tb.extension[0].name.uri, content="\"http://example.org/ext\"")
  debug_inspect(tb.extension[0].name.local_name, content="\"ext\"")
}

///|
test "BodyProperties captures prstTxWarp / extLst" {
  let inner = "<a:bodyPr>" +
    "<a:prstTxWarp prst=\"textArchUp\"><a:avLst/></a:prstTxWarp>" +
    "<a:extLst><a:ext uri=\"{x}\"/></a:extLst>" +
    "</a:bodyPr>" +
    "<a:p><a:r><a:t>x</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let bp = first_auto_shape(slide).text_body.unwrap().body_properties.unwrap()
  debug_inspect(bp.extension.length(), content="2")
  let names = []
  for el in bp.extension {
    names.push(el.name.local_name)
  }
  debug_inspect(names.contains("prstTxWarp"), content="true")
  debug_inspect(names.contains("extLst"), content="true")
}

///|
test "Paragraph models endParaRPr rather than preserving it verbatim" {
  let inner = "<a:p><a:r><a:t>hello</a:t></a:r><a:endParaRPr lang=\"en-US\" sz=\"1800\"/></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  // It is typed now, so it no longer lands on the extension array.
  debug_inspect(p.extension.length(), content="0")
  let end = p.end_run_properties.unwrap()
  debug_inspect(end.lang, content="\"en-US\"")
  debug_inspect(end.font_size, content="Some(Pt(18))")
}

///|
test "RunProperties captures hlinkMouseOver; effectLst now typed" {
  let inner = "<a:p><a:r>" +
    "<a:rPr lang=\"en-US\" b=\"1\">" +
    "<a:effectLst><a:outerShdw blurRad=\"40000\"><a:srgbClr val=\"000000\"/></a:outerShdw></a:effectLst>" +
    "<a:hlinkMouseOver r:id=\"rId7\" xmlns:r=\"" +
    off_rel_ns +
    "\"/>" +
    "</a:rPr>" +
    "<a:t>linked</a:t>" +
    "</a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  match p.content[0] {
    RunContent(r) => {
      debug_inspect(r.properties.bold.unwrap(), content="true")
      // effectLst lifts into the typed `text_effects` field; only the
      // still-unmodelled hlinkMouseOver remains in `extension`.
      debug_inspect(r.properties.text_effects is Some(_), content="true")
      debug_inspect(r.properties.extension.length(), content="1")
      debug_inspect(
        r.properties.extension[0].name.local_name,
        content="\"hlinkMouseOver\"",
      )
    }
    _ => fail("expected Run")
  }
}

///|
test "ParagraphProperties captures buFont and tabLst" {
  let inner = "<a:p>" +
    "<a:pPr lvl=\"1\">" +
    "<a:buFont typeface=\"Symbol\" panose=\"05050102010706020507\"/>" +
    "<a:tabLst><a:tab pos=\"914400\" algn=\"l\"/></a:tabLst>" +
    "</a:pPr>" +
    "<a:r><a:t>x</a:t></a:r>" +
    "</a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  debug_inspect(p.properties.level, content="1")
  debug_inspect(p.properties.extension.length(), content="2")
  let names = []
  for el in p.properties.extension {
    names.push(el.name.local_name)
  }
  debug_inspect(names.contains("buFont"), content="true")
  debug_inspect(names.contains("tabLst"), content="true")
}

///|
test "ListStyle captures extLst" {
  let inner = "<a:lstStyle>" +
    "<a:defPPr><a:defRPr/></a:defPPr>" +
    "<a:extLst><a:ext uri=\"{x}\"><a:placeholder/></a:ext></a:extLst>" +
    "</a:lstStyle>" +
    "<a:p><a:r><a:t>x</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let ls = first_auto_shape(slide).text_body.unwrap().list_style.unwrap()
  debug_inspect(ls.extension.length(), content="1")
  debug_inspect(ls.extension[0].name.local_name, content="\"extLst\"")
}

///|
test "Field captures rPr extensions" {
  let inner = "<a:p><a:fld id=\"{F-0}\" type=\"slidenum\">" +
    "<a:rPr lang=\"en-US\"><a:extLst><a:ext uri=\"{x}\"/></a:extLst></a:rPr>" +
    "<a:t>1</a:t>" +
    "</a:fld></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  match p.content[0] {
    FieldContent(f) => {
      debug_inspect(f.id, content="\"{F-0}\"")
      debug_inspect(f.text, content="\"1\"")
      // The field's rPr extension carries the extLst.
      debug_inspect(f.properties.extension.length(), content="1")
      debug_inspect(
        f.properties.extension[0].name.local_name,
        content="\"extLst\"",
      )
    }
    _ => fail("expected Field")
  }
}

///|
test "Break preserves its rPr (no longer drops it)" {
  let inner = "<a:p>" +
    "<a:r><a:t>one</a:t></a:r>" +
    "<a:br><a:rPr lang=\"en-US\" sz=\"2400\"/></a:br>" +
    "<a:r><a:t>two</a:t></a:r>" +
    "</a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  match p.content[1] {
    Break(rpr) => {
      debug_inspect(rpr.lang, content="\"en-US\"")
      debug_inspect(rpr.font_size.unwrap(), content="Pt(24)")
    }
    _ => fail("expected Break")
  }
}
