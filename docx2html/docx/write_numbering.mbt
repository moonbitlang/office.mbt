// F3 numbering part: two fixed definitions — an unordered (bullet) list
// and an ordered (decimal) list, nine levels each — matching what the AST
// can express (`Numbering { is_ordered, level }`). numId 1 = unordered,
// numId 2 = ordered; the reader maps them back through numFmt ("bullet" ⇒
// unordered) and ilvl (+1), so read(write(x)) preserves the numbering.

///|
const UNORDERED_NUM_ID : String = "1"

///|
const ORDERED_NUM_ID : String = "2"

///|
/// The complete `word/numbering.xml` for written documents. CT_Lvl is an
/// enforced sequence: start, numFmt, lvlText, lvlJc, pPr.
fn numbering_xml() -> String {
  let children : Array[XmlNode] = [
    XmlElement(abstract_num("0", is_ordered=false)),
    XmlElement(abstract_num("1", is_ordered=true)),
    XmlElement(num_instance(UNORDERED_NUM_ID, "0")),
    XmlElement(num_instance(ORDERED_NUM_ID, "1")),
  ]
  @xml.write_xml_string(@xml.xml_element("w:numbering", children~), namespaces={
    "w": WORDPROCESSINGML_NAMESPACE,
  })
}

///|
fn abstract_num(abstract_id : String, is_ordered~ : Bool) -> XmlElement {
  let levels : Array[XmlNode] = []
  for index in 0..<9 {
    let num_fmt = if is_ordered { "decimal" } else { "bullet" }
    let level_text = if is_ordered { "%\{index + 1}." } else { "•" }
    // Word's conventional cascade: 720 twips (0.5in) per level, hanging 360.
    let indent = ((index + 1) * 720).to_string()
    levels.push(
      XmlElement(
        @xml.xml_element("w:lvl", attributes={ "w:ilvl": index.to_string() }, children=[
          XmlElement(@xml.xml_element("w:start", attributes={ "w:val": "1" })),
          XmlElement(
            @xml.xml_element("w:numFmt", attributes={ "w:val": num_fmt }),
          ),
          XmlElement(
            @xml.xml_element("w:lvlText", attributes={ "w:val": level_text }),
          ),
          XmlElement(
            @xml.xml_element("w:lvlJc", attributes={ "w:val": "left" }),
          ),
          XmlElement(
            @xml.xml_element("w:pPr", children=[
              XmlElement(
                @xml.xml_element("w:ind", attributes={
                  "w:left": indent,
                  "w:hanging": "360",
                }),
              ),
            ]),
          ),
        ]),
      ),
    )
  }
  @xml.xml_element(
    "w:abstractNum",
    attributes={ "w:abstractNumId": abstract_id },
    children=levels,
  )
}

///|
fn num_instance(num_id : String, abstract_id : String) -> XmlElement {
  @xml.xml_element("w:num", attributes={ "w:numId": num_id }, children=[
    XmlElement(
      @xml.xml_element("w:abstractNumId", attributes={ "w:val": abstract_id }),
    ),
  ])
}
