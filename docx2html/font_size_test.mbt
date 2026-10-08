///|
test "odd OOXML half-point sizes render and round trip exactly" {
  let body =
    #|<w:p><w:r><w:rPr><w:sz w:val="21"/><w:szCs w:val="25"/></w:rPr><w:t>half</w:t></w:r><w:r><w:rPr><w:sz w:val="28"/></w:rPr><w:t>whole</w:t></w:r><w:r><w:t>absent</w:t></w:r></w:p>
  let bytes = color_document(body)
  debug_inspect(
    @docx2html.convert_to_html(bytes).value,
    content=(
      #|"<p><span style=\"font-size: 10.5pt\">half</span><span style=\"font-size: 14pt\">whole</span>absent</p>"
    ),
  )
  guard @docx2html.read_docx(bytes) is Document(children~, ..) else {
    fail("document")
  }
  let written = @docx2html.write_docx(children)
  debug_inspect(
    @docx2html.read_docx(written) ==
    @docx2html.document(with_writer_font_defaults(children)),
    content=(
      #|true
    ),
  )
  debug_inspect(
    @docx2html.convert_to_html(written).value,
    content=(
      #|"<p><span style=\"font-size: 10.5pt\">half</span><span style=\"font-size: 14pt\">whole</span><span style=\"font-size: 12pt\">absent</span></p>"
    ),
  )
}

///|
test "font sizes inherit independently with direct overrides" {
  let styles =
    #|<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="21"/><w:szCs w:val="25"/></w:rPr></w:rPrDefault></w:docDefaults>
    #|<w:style w:type="paragraph" w:styleId="Base"><w:rPr><w:sz w:val="28"/></w:rPr></w:style>
    #|<w:style w:type="paragraph" w:styleId="Body"><w:basedOn w:val="Base"/></w:style>
    #|<w:style w:type="character" w:styleId="Small"><w:rPr><w:sz w:val="19"/></w:rPr></w:style>
  let body =
    #|<w:p><w:r><w:t>default</w:t></w:r></w:p>
    #|<w:p><w:pPr><w:pStyle w:val="Body"/></w:pPr><w:r><w:t>paragraph</w:t></w:r><w:r><w:rPr><w:rStyle w:val="Small"/></w:rPr><w:t>character</w:t></w:r><w:r><w:rPr><w:rStyle w:val="Small"/><w:sz w:val="23"/></w:rPr><w:t>direct</w:t></w:r></w:p>
    #|<w:p><w:r><w:t>default again</w:t></w:r></w:p>
  for strict in [false, true] {
    let bytes = color_document(body, styles~, strict~)
    debug_inspect(
      @docx2html.convert_to_html(bytes).value,
      content=(
        #|"<p><span style=\"font-size: 10.5pt\">default</span></p><p><span style=\"font-size: 14pt\">paragraph</span><span style=\"font-size: 9.5pt\">character</span><span style=\"font-size: 11.5pt\">direct</span></p><p><span style=\"font-size: 10.5pt\">default again</span></p>"
      ),
    )
    guard @docx2html.read_docx(bytes)
      is Document(
        children=[Paragraph(children=[Run(properties~, ..)], ..), ..],
        ..
      ) else {
      fail("run")
    }
    debug_inspect(
      (properties.font_size, properties.font_size_cs),
      content=(
        #|(Some(10.5), Some(12.5))
      ),
    )
  }
}

///|
test "authored sizes keep point units and complex-script authoring defaults" {
  let sizes = [0.5, 10.5, 14.0, 1638.0]
  let body = [
    @docx2html.paragraph(
      sizes.map(size => {
        @docx2html.run(
          [@docx2html.text(size.to_string())],
          properties=@docx2html.run_properties(font_size=Some(size)),
        )
      }),
    ),
  ]
  debug_inspect(
    @docx2html.read_docx(@docx2html.write_docx(body)) ==
    @docx2html.document(with_writer_font_defaults(body)),
    content=(
      #|true
    ),
  )
  debug_inspect(
    @docx2html.run_properties(font_size=Some(14)).font_size_cs,
    content=(
      #|Some(14)
    ),
  )
  debug_inspect(
    @docx2html.run_properties(font_size=Some(14), font_size_cs=None).font_size_cs,
    content=(
      #|None
    ),
  )
}

///|
test "invalid sizes do not round or produce font-size CSS" {
  for size in [0.0, -1.0, 10.25, 1638.5, 0.0 / 0.0, 1.0 / 0.0] {
    let run = @docx2html.run(
      [@docx2html.text("text")],
      properties=@docx2html.run_properties(font_size=Some(size)),
    )
    debug_inspect(
      @docx2html.convert_document_to_html(run).value,
      content="\"text\"",
    )
    let rejected = try {
      let _ = @docx2html.write_docx([@docx2html.paragraph([run])])
      false
    } catch {
      _ => true
    }
    debug_inspect(rejected, content="true")
  }
}

///|
test "batch accepts half points and preserves distinct complex-script sizes" {
  let text =
    #|{"schema":"docx.batch/1","ops":[{"op":"paragraph","params":{"runs":[{"text":"half","size":10.50,"size_cs":12.5}]}}]}
  @batch.check_script_text(text)
  let body = @batch.parse_batch(@json.parse(text)).build_body(Map([]))
  debug_inspect(
    @docx2html.read_docx(@docx2html.write_docx(body)) ==
    @docx2html.document(with_writer_font_defaults(body)),
    content=(
      #|true
    ),
  )
  debug_inspect(
    @docx2html.convert_to_html(@docx2html.write_docx(body)).value,
    content=(
      #|"<p><span style=\"font-size: 10.5pt\">half</span></p>"
    ),
  )
  for invalid in ["10.25", "10.500000000000000001", "1e1"] {
    let text = "{\"size\":" + invalid + "}"
    let rejected = try {
      @batch.check_script_text(text)
      false
    } catch {
      _ => true
    }
    debug_inspect(rejected, content="true")
  }
}

///|
// The writer has always emitted 12pt docDefaults. Reading now materializes
// those defaults; source-absent formatting is intentionally enriched.
fn with_writer_font_defaults(
  body : Array[@docx2html.DocumentElement],
) -> Array[@docx2html.DocumentElement] {
  body.map(element => {
    @docx2html.transform_elements(element, node => {
      match node {
        Run(children~, properties~) =>
          @docx2html.run(children, properties={
            ..properties,
            font_size: match properties.font_size {
              Some(_) => properties.font_size
              None => Some(12.0)
            },
            font_size_cs: match properties.font_size_cs {
              Some(_) => properties.font_size_cs
              None => Some(12.0)
            },
          })
        _ => node
      }
    })
  })
}

///|
test "batch null keeps complex-script size absent rather than copying regular size" {
  let text =
    #|{"schema":"docx.batch/1","ops":[{"op":"paragraph","params":{"runs":[{"text":"regular","size":10.5,"size_cs":null}]}}]}
  @batch.check_script_text(text)
  let body = @batch.parse_batch(@json.parse(text)).build_body(Map([]))
  guard body is [Paragraph(children=[Run(properties~, ..)], ..)] else {
    fail("run")
  }
  debug_inspect(
    (properties.font_size, properties.font_size_cs),
    content="(Some(10.5), None)",
  )
}

///|
test "invalid direct size inherits and complex-script size does not replace regular size" {
  let styles =
    #|<w:style w:type="paragraph" w:styleId="Default" w:default="1"><w:rPr><w:sz w:val="21"/><w:szCs w:val="31"/></w:rPr></w:style>
    #|<w:style w:type="character" w:styleId="CS"><w:rPr><w:szCs w:val="25"/></w:rPr></w:style>
  let body =
    #|<w:p><w:r><w:rPr><w:rStyle w:val="CS"/><w:sz w:val="bad"/></w:rPr><w:t>text</w:t></w:r></w:p>
  let bytes = color_document(body, styles~)
  guard @docx2html.read_docx(bytes)
    is Document(children=[Paragraph(children=[Run(properties~, ..)], ..)], ..) else {
    fail("run")
  }
  debug_inspect(
    (properties.font_size, properties.font_size_cs),
    content="(Some(10.5), Some(12.5))",
  )
  debug_inspect(
    @docx2html.convert_to_html(bytes).value,
    content=(
      #|"<p><span style=\"font-size: 10.5pt\">text</span></p>"
    ),
  )
}
