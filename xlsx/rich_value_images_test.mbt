///|
/// Rewrites a written workbook into a rich-value "Place in cell" image
/// layout: injects a `vm` attribute onto the A1 cell and adds the
/// metadata, richData, and media parts a modern embedded image needs.
fn inject_rich_value_image(base : Bytes, media : Bytes) -> Bytes raise {
  let archive = @zip.read(base)
  let patched = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() == "xl/worksheets/sheet1.xml" {
      let xml = @encoding/utf8.decode(entry.data())
      // give the #VALUE! cell its value-metadata index
      let mutated = xml.replace(old="<c r=\"A1\"", new="<c r=\"A1\" vm=\"1\"")
      patched.add(entry.name(), @encoding/utf8.encode(mutated))
    } else {
      patched.add(entry.name(), entry.data())
    }
  }
  patched.add(
    "xl/metadata.xml",
    @encoding/utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8"?>
        #|<metadata>
        #|  <valueMetadata count="1">
        #|    <bk><rc t="1" v="0"/></bk>
        #|  </valueMetadata>
        #|</metadata>
      ),
    ),
  )
  patched.add(
    "xl/richData/rdrichvalue.xml",
    @encoding/utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8"?>
        #|<rvData count="1">
        #|  <rv s="0"><v>0</v><v>a placed image</v></rv>
        #|</rvData>
      ),
    ),
  )
  patched.add(
    "xl/richData/rdrichvaluestructure.xml",
    @encoding/utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8"?>
        #|<rvStructures count="1">
        #|  <s t="_localImage">
        #|    <k n="_rvRel:LocalImageIdentifier" t="i"/>
        #|    <k n="Text" t="s"/>
        #|  </s>
        #|</rvStructures>
      ),
    ),
  )
  patched.add(
    "xl/richData/richValueRel.xml",
    @encoding/utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8"?>
        #|<richValueRels xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        #|  <rel r:id="rId1"/>
        #|</richValueRels>
      ),
    ),
  )
  patched.add(
    "xl/richData/_rels/richValueRel.xml.rels",
    @encoding/utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8"?>
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        #|  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/rv1.png"/>
        #|</Relationships>
      ),
    ),
  )
  patched.add("xl/media/rv1.png", media)
  @zip.write(patched)
}

///|
test "get_pictures resolves a rich-value place-in-cell image" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Error("#VALUE!"))
  let media : Bytes = b"\x89PNG\r\n\x1a\nplaced-image"
  let bytes = inject_rich_value_image(@xlsx.write(workbook), media)
  let parsed = @xlsx.read(bytes)
  let pics = parsed.get_pictures("Sheet1", "A1")
  inspect(pics.length(), content="1")
  let pic = pics[0]
  inspect(pic.extension, content=".png")
  inspect(pic.content_type, content="image/png")
  inspect(pic.alt_text, content="a placed image")
  inspect(pic.data == media, content="true")
  // a cell without a vm/#VALUE! rich value returns nothing
  inspect(parsed.get_pictures("Sheet1", "B2").length(), content="0")
}

///|
test "rich-value image ignored when cell is not a #VALUE! error" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  // a plain value cell with a vm should not resolve to an image
  sheet.set_cell_value("A1", String("hello"))
  let bytes = inject_rich_value_image(
    @xlsx.write(workbook),
    b"\x89PNG\r\n\x1a\nx",
  )
  let parsed = @xlsx.read(bytes)
  inspect(parsed.get_pictures("Sheet1", "A1").length(), content="0")
}

///|
/// Injects a rich value whose structure keys and values have mismatched
/// lengths, which Excelize refuses to resolve.
fn inject_mismatched_rich_value(base : Bytes) -> Bytes raise {
  let archive = @zip.read(base)
  let patched = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() == "xl/worksheets/sheet1.xml" {
      let xml = @encoding/utf8.decode(entry.data())
      patched.add(
        entry.name(),
        @encoding/utf8.encode(
          xml.replace(old="<c r=\"A1\"", new="<c r=\"A1\" vm=\"1\""),
        ),
      )
    } else {
      patched.add(entry.name(), entry.data())
    }
  }
  patched.add(
    "xl/metadata.xml",
    @encoding/utf8.encode(
      (
        #|<metadata><valueMetadata count="1"><bk><rc t="1" v="0"/></bk></valueMetadata></metadata>
      ),
    ),
  )
  // three keys but only one value: Excelize suppresses the image
  patched.add(
    "xl/richData/rdrichvalue.xml",
    @encoding/utf8.encode(
      (
        #|<rvData count="1"><rv s="0"><v>0</v></rv></rvData>
      ),
    ),
  )
  patched.add(
    "xl/richData/rdrichvaluestructure.xml",
    @encoding/utf8.encode(
      (
        #|<rvStructures count="1"><s t="_localImage"><k n="_rvRel:LocalImageIdentifier" t="i"/><k n="CalcOrigin" t="i"/><k n="Text" t="s"/></s></rvStructures>
      ),
    ),
  )
  patched.add(
    "xl/richData/richValueRel.xml",
    @encoding/utf8.encode(
      (
        #|<richValueRels xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><rel r:id="rId1"/></richValueRels>
      ),
    ),
  )
  patched.add(
    "xl/richData/_rels/richValueRel.xml.rels",
    @encoding/utf8.encode(
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/rv1.png"/></Relationships>
      ),
    ),
  )
  patched.add("xl/media/rv1.png", b"png")
  @zip.write(patched)
}

///|
test "rich-value image suppressed when keys and values length mismatch" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Error("#VALUE!"))
  let bytes = inject_mismatched_rich_value(@xlsx.write(workbook))
  let parsed = @xlsx.read(bytes)
  inspect(parsed.get_pictures("Sheet1", "A1").length(), content="0")
}

///|
/// Injects a rich value that uses the IMAGE() web-image path
/// (WebImageIdentifier) instead of a local place-in-cell image.
fn inject_web_image(base : Bytes, media : Bytes) -> Bytes raise {
  let archive = @zip.read(base)
  let patched = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() == "xl/worksheets/sheet1.xml" {
      let xml = @encoding/utf8.decode(entry.data())
      patched.add(
        entry.name(),
        @encoding/utf8.encode(
          xml.replace(old="<c r=\"A1\"", new="<c r=\"A1\" vm=\"1\""),
        ),
      )
    } else {
      patched.add(entry.name(), entry.data())
    }
  }
  patched.add(
    "xl/metadata.xml",
    @encoding/utf8.encode(
      (
        #|<metadata><valueMetadata count="1"><bk><rc t="1" v="0"/></bk></valueMetadata></metadata>
      ),
    ),
  )
  patched.add(
    "xl/richData/rdrichvalue.xml",
    @encoding/utf8.encode(
      (
        #|<rvData count="1"><rv s="0"><v>0</v><v>a web image</v></rv></rvData>
      ),
    ),
  )
  patched.add(
    "xl/richData/rdrichvaluestructure.xml",
    @encoding/utf8.encode(
      (
        #|<rvStructures count="1"><s t="_webImage"><k n="WebImageIdentifier" t="i"/><k n="Text" t="s"/></s></rvStructures>
      ),
    ),
  )
  patched.add(
    "xl/richData/rdRichValueWebImage.xml",
    @encoding/utf8.encode(
      (
        #|<webImagesSrd xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        #|  <webImageSrd><address r:id=""/><blip r:id="rId1"/></webImageSrd>
        #|</webImagesSrd>
      ),
    ),
  )
  patched.add(
    "xl/richData/_rels/rdRichValueWebImage.xml.rels",
    @encoding/utf8.encode(
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/web1.png"/></Relationships>
      ),
    ),
  )
  patched.add("xl/media/web1.png", media)
  @zip.write(patched)
}

///|
test "get_pictures resolves an IMAGE() web image" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Error("#VALUE!"))
  let media : Bytes = b"\x89PNG\r\n\x1a\nweb-image-bytes"
  let bytes = inject_web_image(@xlsx.write(workbook), media)
  let parsed = @xlsx.read(bytes)
  let pics = parsed.get_pictures("Sheet1", "A1")
  inspect(pics.length(), content="1")
  inspect(pics[0].extension, content=".png")
  inspect(pics[0].content_type, content="image/png")
  inspect(pics[0].alt_text, content="a web image")
  inspect(pics[0].data == media, content="true")
}

///|
/// Injects a rich value that has BOTH a (bad) LocalImageIdentifier and a
/// valid WebImageIdentifier. Excelize commits to the local key once it
/// is present, so no image resolves.
fn inject_local_key_wins(base : Bytes, media : Bytes) -> Bytes raise {
  let archive = @zip.read(base)
  let patched = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() == "xl/worksheets/sheet1.xml" {
      let xml = @encoding/utf8.decode(entry.data())
      patched.add(
        entry.name(),
        @encoding/utf8.encode(
          xml.replace(old="<c r=\"A1\"", new="<c r=\"A1\" vm=\"1\""),
        ),
      )
    } else {
      patched.add(entry.name(), entry.data())
    }
  }
  patched.add(
    "xl/metadata.xml",
    @encoding/utf8.encode(
      (
        #|<metadata><valueMetadata count="1"><bk><rc t="1" v="0"/></bk></valueMetadata></metadata>
      ),
    ),
  )
  // local id 9 is out of range; web id 0 is valid - Go still returns the
  // local (nil) result and never uses the web image
  patched.add(
    "xl/richData/rdrichvalue.xml",
    @encoding/utf8.encode(
      (
        #|<rvData count="1"><rv s="0"><v>9</v><v>0</v></rv></rvData>
      ),
    ),
  )
  patched.add(
    "xl/richData/rdrichvaluestructure.xml",
    @encoding/utf8.encode(
      (
        #|<rvStructures count="1"><s t="_mixed"><k n="_rvRel:LocalImageIdentifier" t="i"/><k n="WebImageIdentifier" t="i"/></s></rvStructures>
      ),
    ),
  )
  patched.add(
    "xl/richData/richValueRel.xml",
    @encoding/utf8.encode(
      (
        #|<richValueRels xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><rel r:id="rId1"/></richValueRels>
      ),
    ),
  )
  patched.add(
    "xl/richData/_rels/richValueRel.xml.rels",
    @encoding/utf8.encode(
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/rv1.png"/></Relationships>
      ),
    ),
  )
  patched.add(
    "xl/richData/rdRichValueWebImage.xml",
    @encoding/utf8.encode(
      (
        #|<webImagesSrd xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><webImageSrd><blip r:id="rId1"/></webImageSrd></webImagesSrd>
      ),
    ),
  )
  patched.add(
    "xl/richData/_rels/rdRichValueWebImage.xml.rels",
    @encoding/utf8.encode(
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/web1.png"/></Relationships>
      ),
    ),
  )
  patched.add("xl/media/web1.png", media)
  @zip.write(patched)
}

///|
test "rich value with a present local key never falls back to the web image" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Error("#VALUE!"))
  let bytes = inject_local_key_wins(@xlsx.write(workbook), b"\x89PNGweb")
  let parsed = @xlsx.read(bytes)
  // the local key is present but unresolvable; Go does not use the web
  // image, so no picture is returned
  inspect(parsed.get_pictures("Sheet1", "A1").length(), content="0")
}

///|
test "rich-value image survives sheet rename and copy" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Error("#VALUE!"))
  let media : Bytes = b"\x89PNG\r\n\x1a\nrenamed"
  let bytes = inject_rich_value_image(@xlsx.write(workbook), media)
  let parsed = @xlsx.read(bytes)
  // sanity: resolves before any lifecycle change
  inspect(parsed.get_pictures("Sheet1", "A1").length(), content="1")
  // rename must not orphan the vm map (it lives on the worksheet now)
  parsed.set_sheet_name("Sheet1", "Renamed")
  let after_rename = parsed.get_pictures("Renamed", "A1")
  inspect(after_rename.length(), content="1")
  inspect(after_rename[0].data == media, content="true")
  // copy the sheet onto a second sheet; the copy keeps the image
  ignore(parsed.add_sheet("Target"))
  let target_index = parsed.sheet_index("Target")
  let source_index = parsed.sheet_index("Renamed")
  parsed.copy_sheet(source_index, target_index)
  inspect(parsed.get_pictures("Target", "A1").length(), content="1")
}
