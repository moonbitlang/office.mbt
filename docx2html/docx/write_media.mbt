// F4 of the content writers: hyperlinks and inline images. Hyperlinks
// become `w:hyperlink` (an external relationship for `href`, the `w:anchor`
// attribute for internal anchors — the reader folds r:id+anchor into the
// href fragment, so setting BOTH fails closed to keep round trips exact).
// Images become minimal DrawingML `wp:inline` pictures with a media part
// per image; dimensions come from the image bytes themselves (PNG, JPEG,
// GIF — anything else fails closed), rendered at 96 DPI.

///|
const EMU_PER_PIXEL : Int64 = 9525

///|
/// ST_PositiveCoordinate's upper bound (EMUs).
const MAX_EMU : Int64 = 27273042316900

///|
fn write_hyperlink(
  children : Array[DocumentElement],
  href : String?,
  anchor : String?,
  target_frame : String?,
  ctx : WriteContext,
) -> XmlElement raise DocxError {
  let attributes : Map[String, String] = Map([])
  match (href, anchor) {
    (Some(_), Some(_)) =>
      raise Unsupported(
        message="a hyperlink with both href and anchor cannot round-trip (the reader folds the anchor into the href fragment); put the fragment in the href",
      )
    (Some(href), None) => {
      if href == "" {
        raise Unsupported(
          message="a hyperlink href must not be empty (the reader treats blank attributes as absent)",
        )
      }
      check_attribute_value("a hyperlink href", href)
      let rel_id = ctx.allocate_relationship(
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
        href,
        external=true,
      )
      attributes["r:id"] = rel_id
    }
    (None, Some(anchor)) => {
      if anchor == "" {
        raise Unsupported(
          message="a hyperlink anchor must not be empty (the reader treats blank attributes as absent)",
        )
      }
      check_attribute_value("a hyperlink anchor", anchor)
      attributes["w:anchor"] = anchor
    }
    (None, None) =>
      raise Unsupported(message="a hyperlink needs an href or an anchor")
  }
  match target_frame {
    Some(frame) => {
      if frame == "" {
        raise Unsupported(
          message="a hyperlink target frame must not be empty (the reader treats blank attributes as absent)",
        )
      }
      check_attribute_value("a hyperlink target frame", frame)
      attributes["w:tgtFrame"] = frame
    }
    None => ()
  }
  let nodes : Array[XmlNode] = []
  for child in children {
    nodes.push(XmlElement(write_inline(child, ctx)))
  }
  @xml.xml_element("w:hyperlink", attributes~, children=nodes)
}

///|
fn write_image(image : Image, ctx : WriteContext) -> XmlElement raise DocxError {
  let extension = match image.content_type {
    "image/png" => "png"
    "image/jpeg" => "jpeg"
    "image/gif" => "gif"
    other =>
      raise Unsupported(
        message="the image writer supports image/png, image/jpeg, and image/gif (got '\{other}')",
      )
  }
  let (width, height) = image_dimensions(image.content_type, image.data)
  // Extents in Int64: a 32-bit Int overflows at ~225k px, and OOXML bounds
  // coordinates at ST_PositiveCoordinate's max.
  let cx_emu = width.to_int64() * EMU_PER_PIXEL
  let cy_emu = height.to_int64() * EMU_PER_PIXEL
  if cx_emu <= 0 || cy_emu <= 0 || cx_emu > MAX_EMU || cy_emu > MAX_EMU {
    raise Unsupported(
      message="image dimensions \{width}x\{height} px are outside OOXML coordinate bounds",
    )
  }
  let cx = cx_emu.to_string()
  let cy = cy_emu.to_string()
  let index = ctx.media.length() + 1
  let part_name = "media/image\{index}.\{extension}"
  ctx.media.push((part_name, extension, image.content_type, image.data))
  let rel_id = ctx.allocate_relationship(
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
    part_name,
    external=false,
  )
  let name = "Picture \{index}"
  let doc_pr_attributes : Map[String, String] = {
    "id": index.to_string(),
    "name": name,
  }
  let c_nv_pr_attributes : Map[String, String] = { "id": "0", "name": name }
  match image.alt_text {
    Some(alt) => {
      if alt.trim(chars=" \t\r\n") == "" {
        raise Unsupported(
          message="image alt text must not be blank (the reader treats blank descr as absent)",
        )
      }
      check_attribute_value("image alt text", alt)
      doc_pr_attributes["descr"] = alt
      c_nv_pr_attributes["descr"] = alt
    }
    None => ()
  }
  let extent : Map[String, String] = { "cx": cx, "cy": cy }
  @xml.xml_element("w:drawing", children=[
    XmlElement(
      @xml.xml_element(
        "wp:inline",
        attributes={ "distT": "0", "distB": "0", "distL": "0", "distR": "0" },
        children=[
          XmlElement(@xml.xml_element("wp:extent", attributes=extent)),
          XmlElement(@xml.xml_element("wp:docPr", attributes=doc_pr_attributes)),
          XmlElement(
            @xml.xml_element("a:graphic", children=[
              XmlElement(
                @xml.xml_element(
                  "a:graphicData",
                  attributes={
                    "uri": "http://schemas.openxmlformats.org/drawingml/2006/picture",
                  },
                  children=[
                    XmlElement(
                      @xml.xml_element("pic:pic", children=[
                        XmlElement(
                          @xml.xml_element("pic:nvPicPr", children=[
                            XmlElement(
                              @xml.xml_element(
                                "pic:cNvPr",
                                attributes=c_nv_pr_attributes,
                              ),
                            ),
                            XmlElement(@xml.xml_element("pic:cNvPicPr")),
                          ]),
                        ),
                        XmlElement(
                          @xml.xml_element("pic:blipFill", children=[
                            XmlElement(
                              @xml.xml_element("a:blip", attributes={
                                "r:embed": rel_id,
                              }),
                            ),
                            XmlElement(
                              @xml.xml_element("a:stretch", children=[
                                XmlElement(@xml.xml_element("a:fillRect")),
                              ]),
                            ),
                          ]),
                        ),
                        XmlElement(
                          @xml.xml_element("pic:spPr", children=[
                            XmlElement(
                              @xml.xml_element("a:xfrm", children=[
                                XmlElement(
                                  @xml.xml_element("a:off", attributes={
                                    "x": "0",
                                    "y": "0",
                                  }),
                                ),
                                XmlElement(
                                  @xml.xml_element("a:ext", attributes=extent),
                                ),
                              ]),
                            ),
                            XmlElement(
                              @xml.xml_element(
                                "a:prstGeom",
                                attributes={ "prst": "rect" },
                                children=[
                                  XmlElement(@xml.xml_element("a:avLst")),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    ),
  ])
}

///|
/// Pixel dimensions from the image header. Fail-closed: a file whose
/// header cannot be parsed (truncated, wrong magic) raises rather than
/// writing a picture with invented geometry.
fn image_dimensions(
  content_type : String,
  data : Bytes,
) -> (Int, Int) raise DocxError {
  let dims = match content_type {
    "image/png" => png_dimensions(data)
    "image/jpeg" => jpeg_dimensions(data)
    "image/gif" => gif_dimensions(data)
    _ => None
  }
  match dims {
    Some((width, height)) if width > 0 && height > 0 => (width, height)
    _ =>
      raise Unsupported(
        message="could not read the image's dimensions from its \{content_type} header",
      )
  }
}

///|
fn be_u32(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn png_dimensions(data : Bytes) -> (Int, Int)? {
  // Full 8-byte signature, then the IHDR chunk: length(4)=13, 'IHDR'(4),
  // width(4), height(4).
  if data.length() < 24 {
    return None
  }
  if data[0] != 0x89 ||
    data[1] != b'P' ||
    data[2] != b'N' ||
    data[3] != b'G' ||
    data[4] != 0x0D ||
    data[5] != 0x0A ||
    data[6] != 0x1A ||
    data[7] != 0x0A {
    return None
  }
  if be_u32(data, 8) != 13 {
    return None
  }
  if data[12] != b'I' ||
    data[13] != b'H' ||
    data[14] != b'D' ||
    data[15] != b'R' {
    return None
  }
  Some((be_u32(data, 16), be_u32(data, 20)))
}

///|
fn gif_dimensions(data : Bytes) -> (Int, Int)? {
  // Exactly 'GIF87a' or 'GIF89a', then the complete 7-byte logical screen
  // descriptor (little-endian u16 width, height lead it).
  if data.length() < 13 {
    return None
  }
  if data[0] != b'G' ||
    data[1] != b'I' ||
    data[2] != b'F' ||
    data[3] != b'8' ||
    !(data[4] is (b'7' | b'9')) ||
    data[5] != b'a' {
    return None
  }
  let width = data[6].to_int() | (data[7].to_int() << 8)
  let height = data[8].to_int() | (data[9].to_int() << 8)
  Some((width, height))
}

///|
fn jpeg_dimensions(data : Bytes) -> (Int, Int)? {
  // Scan JPEG segments for a start-of-frame marker (SOF0..SOF15 except
  // DHT/JPG/DAC). Reads are bounded by each segment's DECLARED length —
  // dimension bytes must lie inside the SOF segment and inside the data —
  // legal 0xFF fill bytes are skipped, TEM (0x01) and RSTn/SOI are
  // standalone, and EOI terminates the scan.
  if data.length() < 4 || data[0] != 0xFF || data[1] != 0xD8 {
    return None
  }
  let mut offset = 2
  while offset + 1 < data.length() {
    if data[offset] != 0xFF {
      return None
    }
    // Skip marker fill bytes (any number of 0xFF before the marker code).
    let mut marker_at = offset + 1
    while marker_at < data.length() && data[marker_at] == 0xFF {
      marker_at += 1
    }
    if marker_at >= data.length() {
      return None
    }
    let marker = data[marker_at].to_int()
    if marker == 0xD9 {
      // EOI: no frame header seen.
      return None
    }
    if marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8) {
      // TEM / RSTn / SOI: standalone, no length field.
      offset = marker_at + 1
      continue
    }
    if marker_at + 2 >= data.length() {
      return None
    }
    let length = (data[marker_at + 1].to_int() << 8) |
      data[marker_at + 2].to_int()
    if length < 2 {
      return None
    }
    let segment_end = marker_at + 1 + length
    if segment_end > data.length() {
      return None
    }
    let is_sof = marker >= 0xC0 &&
      marker <= 0xCF &&
      marker != 0xC4 &&
      marker != 0xC8 &&
      marker != 0xCC
    if is_sof {
      // Payload: precision(1) height(2) width(2) — must fit the declared
      // segment (length covers the 2 length bytes + payload).
      if length < 7 || marker_at + 7 >= data.length() {
        return None
      }
      let height = (data[marker_at + 4].to_int() << 8) |
        data[marker_at + 5].to_int()
      let width = (data[marker_at + 6].to_int() << 8) |
        data[marker_at + 7].to_int()
      return Some((width, height))
    }
    offset = segment_end
  }
  None
}
