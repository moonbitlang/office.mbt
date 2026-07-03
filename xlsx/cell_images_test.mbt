///|
/// Injects synthetic WPS embedded-cell-image parts into a written
/// workbook: cellimages.xml, its relationships, and one media file.
fn inject_cell_images(base : Bytes, media : Bytes) -> Bytes raise {
  let archive = @zip.read(base)
  let cellimages_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<etc:cellImages xmlns:etc="http://www.wps.cn/officeDocument/2017/etCustomData" xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    #|  <etc:cellImage>
    #|    <xdr:pic>
    #|      <xdr:nvPicPr>
    #|        <xdr:cNvPr id="1" name="ID_ONE" descr="first image"/>
    #|        <xdr:cNvPicPr/>
    #|      </xdr:nvPicPr>
    #|      <xdr:blipFill>
    #|        <a:blip r:embed="rId1"/>
    #|      </xdr:blipFill>
    #|    </xdr:pic>
    #|  </etc:cellImage>
    #|</etc:cellImages>
  let rels_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/cellimage1.png"/>
    #|</Relationships>
  archive.add("xl/cellimages.xml", @encoding/utf8.encode(cellimages_xml))
  archive.add("xl/_rels/cellimages.xml.rels", @encoding/utf8.encode(rels_xml))
  archive.add("xl/media/cellimage1.png", media)
  @zip.write(archive)
}

///|
test "get_pictures resolves a DISPIMG cell image" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "DISPIMG(\"ID_ONE\",1)")
  let media : Bytes = b"\x89PNG\r\n\x1a\nfake-png-bytes"
  let bytes = inject_cell_images(@xlsx.write(workbook), media)
  let parsed = @xlsx.read(bytes)
  let pics = parsed.get_pictures("Sheet1", "A1")
  inspect(pics.length(), content="1")
  let pic = pics[0]
  inspect(pic.extension, content=".png")
  inspect(pic.content_type, content="image/png")
  inspect(pic.name, content="ID_ONE")
  inspect(pic.alt_text, content="first image")
  inspect(pic.data == media, content="true")
  // a cell without a DISPIMG formula returns nothing
  inspect(parsed.get_pictures("Sheet1", "B2").length(), content="0")
}

///|
test "get_pictures ignores DISPIMG cells with an unknown image id" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  // references an id that is not present in cellimages.xml
  sheet.set_cell_formula("A1", "DISPIMG(\"ID_MISSING\",1)")
  let bytes = inject_cell_images(
    @xlsx.write(workbook),
    b"\x89PNG\r\n\x1a\nfake",
  )
  let parsed = @xlsx.read(bytes)
  inspect(parsed.get_pictures("Sheet1", "A1").length(), content="0")
}

///|
test "_xlfn.DISPIMG prefix is recognized" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "_xlfn.DISPIMG(\"ID_ONE\",1)")
  let bytes = inject_cell_images(
    @xlsx.write(workbook),
    b"\x89PNG\r\n\x1a\nfake",
  )
  let parsed = @xlsx.read(bytes)
  inspect(parsed.get_pictures("Sheet1", "A1").length(), content="1")
}
