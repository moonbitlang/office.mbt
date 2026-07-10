///|
test "get base color priority" {
  let workbook = @xlsx.Workbook::new()
  inspect(workbook.get_base_color("AABBCC", 0), content="AABBCC")
  inspect(workbook.get_base_color("FFAABBCC", 0), content="AABBCC")
  inspect(workbook.get_base_color("", 2), content="FF0000")
  inspect(workbook.get_base_color("", 0, theme_color=4), content="4F81BD")
}

///|
test "get base color from theme and indexed colors" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let archive = @zip.read(@xlsx.write(workbook)) catch {
    err => fail("zip read failed: \{err}")
  }
  let theme_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Custom">
    #|  <a:themeElements>
    #|    <a:clrScheme name="Custom">
    #|      <a:dk1><a:srgbClr val="111111"/></a:dk1>
    #|      <a:lt1><a:srgbClr val="EEEEEE"/></a:lt1>
    #|      <a:dk2><a:srgbClr val="222222"/></a:dk2>
    #|      <a:lt2><a:srgbClr val="DDDDDD"/></a:lt2>
    #|      <a:accent1><a:srgbClr val="ABCDEF"/></a:accent1>
    #|      <a:accent2><a:srgbClr val="123123"/></a:accent2>
    #|      <a:accent3><a:srgbClr val="456456"/></a:accent3>
    #|      <a:accent4><a:srgbClr val="789789"/></a:accent4>
    #|      <a:accent5><a:srgbClr val="0A0A0A"/></a:accent5>
    #|      <a:accent6><a:srgbClr val="0B0B0B"/></a:accent6>
    #|    </a:clrScheme>
    #|  </a:themeElements>
    #|  <a:objectDefaults/>
    #|</a:theme>
  let styles_xml = match archive.get("xl/styles.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing styles.xml")
  }
  let colors_block = "  <colors><indexedColors>" +
    "<rgbColor rgb=\"FF123456\"/>" +
    "<rgbColor rgb=\"FF654321\"/>" +
    "</indexedColors>" +
    "<mruColors><color rgb=\"FFABCDEF\"/></mruColors>" +
    "</colors>\n"
  let updated_styles = styles_xml.replace_all(
    old="</styleSheet>",
    new="\{colors_block}</styleSheet>",
  )
  let updated_archive = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != "xl/theme/theme1.xml" && entry.name() != "xl/styles.xml" {
      updated_archive.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  updated_archive.add("xl/theme/theme1.xml", @encoding/utf8.encode(theme_xml))
  updated_archive.add("xl/styles.xml", @encoding/utf8.encode(updated_styles))
  let updated_bytes = @zip.write(updated_archive) catch {
    err => fail("zip write failed: \{repr(err)}")
  }
  let parsed = @xlsx.read(updated_bytes)
  inspect(parsed.get_base_color("", 0, theme_color=4), content="ABCDEF")
  inspect(parsed.get_base_color("", 1), content="654321")
  let roundtrip = @xlsx.write(parsed)
  let roundtrip_archive = @zip.read(roundtrip) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let roundtrip_theme = match roundtrip_archive.get("xl/theme/theme1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing theme1.xml")
  }
  inspect(roundtrip_theme.contains("accent1"), content="true")
  inspect(roundtrip_theme.contains("val=\"ABCDEF\""), content="true")
  inspect(roundtrip_theme.contains("objectDefaults"), content="true")
  let roundtrip_styles = match roundtrip_archive.get("xl/styles.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing styles.xml")
  }
  inspect(roundtrip_styles.contains("<indexedColors>"), content="true")
  inspect(
    roundtrip_styles.contains("rgbColor rgb=\"FF123456\""),
    content="true",
  )
  inspect(
    roundtrip_styles.contains("rgbColor rgb=\"FF654321\""),
    content="true",
  )
  inspect(roundtrip_styles.contains("<mruColors>"), content="true")
  inspect(roundtrip_styles.contains("color rgb=\"FFABCDEF\""), content="true")
}
