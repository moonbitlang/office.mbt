///|
// These nodes are accepted by the XML reader but are not represented by the
// current layout model. Keep the omissions observable to preview consumers.
fn collect_layout_warnings(
  element : @xml.XmlElement,
  warnings : Array[String],
  in_table~ : Bool = false,
  in_paragraph~ : Bool = false,
) -> Unit {
  if element.name
    is ("w:del"
    | "w:moveFrom"
    | "w:pPrChange"
    | "w:rPrChange"
    | "w:tblPrChange"
    | "w:trPrChange"
    | "w:tcPrChange"
    | "w:sectPrChange") {
    return
  }
  if element.name == "mc:AlternateContent" {
    warnings.push("alternate content")
    return
  }
  match element.name {
    "wp:anchor" => warnings.push("floating drawing")
    "w:sdt" if !in_paragraph => warnings.push("content control")
    "w:tbl" if in_table => warnings.push("nested table")
    "w:sectPr" if in_paragraph => warnings.push("paragraph section break")
    "w:footnoteReference" => warnings.push("footnote")
    "w:endnoteReference" => warnings.push("endnote")
    "w:txbxContent" => warnings.push("text box")
    "m:oMath" => warnings.push("equation")
    "w:drawing" =>
      if in_table && read_drawing(element) is Some(_) {
        warnings.push("inline drawing in table")
      } else if element.first("wp:anchor") is None &&
        read_drawing(element) is None {
        warnings.push("unsupported drawing")
      }
    _ => ()
  }
  for child in element.children {
    if child is XmlElement(child) {
      collect_layout_warnings(
        child,
        warnings,
        in_table=in_table || element.name == "w:tbl",
        in_paragraph=in_paragraph || element.name == "w:p",
      )
    }
  }
}

///|
// Preserve the displayed content of block controls while leaving control
// semantics to the host. Direct paragraphs keep their original XML nodes.
fn layout_body_elements(element : @xml.XmlElement) -> Array[@xml.XmlElement] {
  let result : Array[@xml.XmlElement] = []
  for node in element.children {
    guard node is XmlElement(child) else { continue }
    if child.name == "w:sdt" {
      if child.first("w:sdtContent") is Some(content) {
        result.append(layout_body_elements(content))
      }
    } else {
      result.push(child)
    }
  }
  result
}
