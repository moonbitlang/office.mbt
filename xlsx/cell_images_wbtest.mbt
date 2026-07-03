///|
test "parse_cell_images handles unprefixed blip without matching blipFill" {
  // an unprefixed cellimages.xml: <blipFill> must not be mistaken for <blip>
  let cellimages_xml =
    #|<cellImages>
    #|  <cellImage>
    #|    <pic>
    #|      <nvPicPr><cNvPr id="1" name="ID_U" descr="u"/></nvPicPr>
    #|      <blipFill><blip embed="rId1"/></blipFill>
    #|    </pic>
    #|  </cellImage>
    #|</cellImages>
  let rels_xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/u.png"/>
    #|</Relationships>
  let archive = @zip.Archive::new()
  archive.add("xl/media/u.png", b"\x89PNGunprefixed")
  let images = parse_cell_images(cellimages_xml, rels_xml, archive)
  inspect(images.length(), content="1")
  inspect(images[0].name, content="ID_U")
  inspect(images[0].extension, content=".png")
}
