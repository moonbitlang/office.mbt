///|
fn wb_count_substr(text : StringView, needle : StringView) -> Int {
  let mut count = 0
  let mut rest = text.to_string()
  let target = needle.to_string()
  if target == "" {
    return 0
  }
  while true {
    match rest.find(target) {
      Some(pos) => {
        count = count + 1
        let next = pos + target.length()
        rest = (rest[next:] catch { _ => "" }).to_string()
      }
      None => break
    }
  }
  count
}

///|
fn wb_drawing_image(positioning : PicturePositioning) -> DrawingImage {
  let image : Image = {
    reference: "B3",
    data: @encoding/utf8.encode("img"),
    extension: "png",
    content_type: "image/png",
    offset_x: 0,
    offset_y: 0,
    scale_x: 1.0,
    scale_y: 1.0,
    width_emu: 1000,
    height_emu: 2000,
    print_object: true,
    locked: true,
    hyperlink: "",
    hyperlink_type: Unset,
    name: "",
    alt_text: "",
    lock_aspect_ratio: false,
    positioning,
  }
  { image, rel_id: 1, hyperlink_rel_id: None }
}

///|
test "write hardening wb: write_drawing_xml uses None-sheet fallback for two-cell anchors" {
  let xml = write_drawing_xml(None, [wb_drawing_image(TwoCell)], [], [], [])
  inspect(xml.contains("<xdr:twoCellAnchor>"), content="true")
  inspect(xml.contains("<xdr:col>1</xdr:col>"), content="true")
  inspect(xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(xml.contains("<xdr:colOff>1000</xdr:colOff>"), content="true")
  inspect(xml.contains("<xdr:rowOff>2000</xdr:rowOff>"), content="true")
}

///|
test "write hardening wb: write_drawing_xml uses None-sheet fallback for absolute anchors" {
  let xml = write_drawing_xml(None, [wb_drawing_image(Absolute)], [], [], [])
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(xml.contains("<xdr:col>1</xdr:col>"), content="true")
  inspect(xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(xml.contains("<xdr:colOff>1000</xdr:colOff>"), content="true")
  inspect(xml.contains("<xdr:rowOff>2000</xdr:rowOff>"), content="true")
}

///|
test "write hardening wb: write_shared_strings rich-text color and preserve-space branches" {
  let font_indexed_tint : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: Some(64),
    color_tint: Some(0.25),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_rgb_tint : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: None,
    color: Some("FF00AA00"),
    color_theme: None,
    color_indexed: None,
    color_tint: Some(0.5),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_tint_only : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: None,
    color_tint: Some(0.75),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let entries : Array[SharedStringEntry] = [
    { text: "I", runs: Some([{ text: "I", font: Some(font_indexed_tint) }]) },
    { text: "R", runs: Some([{ text: "R", font: Some(font_rgb_tint) }]) },
    { text: "T", runs: Some([{ text: "T", font: Some(font_tint_only) }]) },
    { text: " plain", runs: None },
  ]
  let xml = write_shared_strings_xml(entries, 4)
  inspect(xml.contains("<color indexed=\"64\" tint=\"0.25\"/>"), content="true")
  inspect(
    xml.contains("<color rgb=\"FF00AA00\" tint=\"0.5\"/>"),
    content="true",
  )
  inspect(wb_count_substr(xml, "<color ") >= 2, content="true")
  inspect(xml.contains("<t xml:space=\"preserve\">"), content="true")
}
