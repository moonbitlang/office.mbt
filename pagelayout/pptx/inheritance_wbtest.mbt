///|
test "layout placeholder geometry and master title style cascade without prompt text" {
  let placeholder = "<p:nvPr><p:ph type=\"title\" idx=\"1\"/></p:nvPr>"
  let template_body =
    #|<p:txBody><a:bodyPr lIns="12700"/><a:lstStyle/><a:p><a:r><a:t>B</a:t></a:r></a:p></p:txBody>
  let template_shape = source_shape(template_body).replace(
    old="<p:nvPr/>",
    new=placeholder,
  )
  let layout = parse_root(
    @utf8.encode(source_slide(template_shape)).to_fixedarray(),
  )
  let title_style =
    #|<p:txStyles><p:titleStyle><a:lvl1pPr><a:defRPr sz="2400" b="1"><a:latin typeface="Probe"/></a:defRPr></a:lvl1pPr></p:titleStyle></p:txStyles>
  let master = parse_root(
    @utf8.encode(
      source_slide(template_shape).replace(
        old="</p:sld>",
        new=title_style + "</p:sld>",
      ),
    ).to_fixedarray(),
  )
  let own =
    #|<p:sp><p:nvSpPr><p:cNvPr id="3" name="own"/><p:cNvSpPr/><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr lIns="0"/><a:lstStyle/><a:p><a:r><a:rPr b="0"/><a:t>A</a:t></a:r></a:p></p:txBody></p:sp>
  let root = parse_root(@utf8.encode(source_slide(own)).to_fixedarray())
  let resolved = resolved_slide(root, Some(layout), Some(master), None)
  guard resolved.shapes[0] is AutoShape(shape) &&
    shape.text_body is Some(body) &&
    body.paragraphs[0].content[0] is RunContent(run) else {
    fail("placeholder did not resolve")
  }
  assert_eq(shape.transform.unwrap().extent.cx, Emu(1270000L))
  assert_eq(run.text, "A")
  assert_eq(run.properties.font_size, Some(Pt(24)))
  assert_eq(run.properties.bold, Some(false))
  assert_eq(run.properties.latin, Some("Probe"))
  assert_eq(body.body_properties.unwrap().left_inset, Some(Emu(0L)))
}

///|
test "background, master artwork and layout artwork retain their paint order" {
  let archive = @zip.read(source_package([source_slide("")], [0]))
  let p = @oxml.presentation_ns
  let a = @oxml.drawing_ns
  let rel_ns = "http://schemas.openxmlformats.org/package/2006/relationships"
  archive.add(
    "ppt/slides/_rels/slide0.xml.rels",
    @utf8.encode(
      "<Relationships xmlns=\"\{rel_ns}\"><Relationship Id=\"layout\" Type=\"" +
      @opc.rt_slide_layout +
      "\" Target=\"../slideLayouts/layout.xml\"/></Relationships>",
    ),
  )
  archive.add(
    "ppt/slideLayouts/layout.xml",
    @utf8.encode(
      "<p:sldLayout xmlns:p=\"\{p}\" xmlns:a=\"\{a}\"><p:cSld><p:spTree>" +
      source_shape(
        "",
        fill="<a:solidFill><a:srgbClr val=\"00FF00\"/></a:solidFill>",
      ) +
      "</p:spTree></p:cSld></p:sldLayout>",
    ),
  )
  archive.add(
    "ppt/slideLayouts/_rels/layout.xml.rels",
    @utf8.encode(
      "<Relationships xmlns=\"\{rel_ns}\"><Relationship Id=\"master\" Type=\"" +
      @opc.rt_slide_master +
      "\" Target=\"../slideMasters/master.xml\"/></Relationships>",
    ),
  )
  let colors =
    #|<p:clrMap accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" folHlink="folHlink" hlink="hlink" tx1="dk1" tx2="dk2"/>
  archive.add(
    "ppt/slideMasters/master.xml",
    @utf8.encode(
      "<p:sldMaster xmlns:p=\"\{p}\" xmlns:a=\"\{a}\"><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"0000FF\"/></a:solidFill></p:bgPr></p:bg><p:spTree>" +
      source_shape(
        "",
        fill="<a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>",
      ) +
      "</p:spTree></p:cSld>" +
      colors +
      "</p:sldMaster>",
    ),
  )
  fn fills(bytes : Bytes) -> Array[String] raise {
    let layout = layout_presentation(bytes)
    guard layout.model.pages[0].items[0] is Graphic(graphic) else {
      fail("missing graphic")
    }
    graphic.ops.filter_map(op => {
      match op {
        Path(path) =>
          match path.fill {
            Some(Solid(color)) => Some(color.to_hex())
            _ => None
          }
        _ => None
      }
    })
  }
  debug_inspect(
    fills(@zip.write(archive)),
    content="[\"#0000ff\", \"#ff0000\", \"#00ff00\"]",
  )
  archive.replace(
    "ppt/slides/slide0.xml",
    @utf8.encode(
      source_slide("").replace(old="<p:sld ", new="<p:sld showMasterSp=\"0\" "),
    ),
  )
  |> ignore
  debug_inspect(
    fills(@zip.write(archive)),
    content="[\"#0000ff\", \"#00ff00\"]",
  )
}
