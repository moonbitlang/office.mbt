///|
fn push_u16_le(out : Array[Byte], value : Int) -> Unit {
  let u = (value & 0xFFFF).reinterpret_as_uint()
  out.push((u & 0xFF).to_byte())
  out.push(((u >> 8) & 0xFF).to_byte())
}

///|
fn push_u16_be(out : Array[Byte], value : Int) -> Unit {
  let u = (value & 0xFFFF).reinterpret_as_uint()
  out.push(((u >> 8) & 0xFF).to_byte())
  out.push((u & 0xFF).to_byte())
}

///|
fn push_u32_le(out : Array[Byte], value : Int) -> Unit {
  let u = value.reinterpret_as_uint()
  out.push((u & 0xFF).to_byte())
  out.push(((u >> 8) & 0xFF).to_byte())
  out.push(((u >> 16) & 0xFF).to_byte())
  out.push(((u >> 24) & 0xFF).to_byte())
}

///|
fn push_u32_be(out : Array[Byte], value : Int) -> Unit {
  let u = value.reinterpret_as_uint()
  out.push(((u >> 24) & 0xFF).to_byte())
  out.push(((u >> 16) & 0xFF).to_byte())
  out.push(((u >> 8) & 0xFF).to_byte())
  out.push((u & 0xFF).to_byte())
}

///|
fn last_image_emu(sheet : Worksheet) -> (Int, Int) {
  let images = sheet.images()
  let last = images[images.length() - 1]
  (last.width_emu, last.height_emu)
}

///|
fn expected_image_emu(w_px : Int, h_px : Int) -> (Int, Int) {
  (9525 * w_px, 9525 * h_px)
}

///|
test "image dimensions: png/gif/jpeg/bmp/ico/tiff/svg/emf/wmf/emz/wmz" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")

  // PNG: signature + IHDR + width/height (big endian).
  let png : Array[Byte] = []
  for b in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
    png.push(b.to_byte())
  }
  push_u32_be(png, 13)
  for b in [0x49, 0x48, 0x44, 0x52] {
    png.push(b.to_byte())
  }
  push_u32_be(png, 2)
  push_u32_be(png, 3)
  sheet.add_image("A1", Bytes::from_array(png), "png", "image/png")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(2, 3)}")

  // GIF: GIF89a + width/height (little endian).
  let gif : Array[Byte] = []
  for b in [0x47, 0x49, 0x46, 0x38, 0x39, 0x61] {
    gif.push(b.to_byte())
  }
  push_u16_le(gif, 5)
  push_u16_le(gif, 6)
  sheet.add_image("A2", Bytes::from_array(gif), "gif", "image/gif")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(5, 6)}")

  // JPEG: SOI + SOF0 with height/width.
  let jpg : Array[Byte] = []
  for b in [0xFF, 0xD8, 0xFF, 0xC0] {
    jpg.push(b.to_byte())
  }
  push_u16_be(jpg, 17)
  jpg.push((8).to_byte()) // precision
  push_u16_be(jpg, 16) // height
  push_u16_be(jpg, 32) // width
  // padding
  for _ in 0..<10 {
    jpg.push((0).to_byte())
  }
  sheet.add_image("A3", Bytes::from_array(jpg), "jpg", "image/jpeg")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(32, 16)}")

  // BMP (BITMAPCOREHEADER): dib size 12, width/height are u16.
  let bmp_core : Array[Byte] = Array::make(26, (0).to_byte())
  bmp_core[0] = (0x42).to_byte()
  bmp_core[1] = (0x4D).to_byte()
  // DIB size @ 14
  bmp_core[14] = (12).to_byte()
  // width @ 18, height @ 20
  bmp_core[18] = (7).to_byte()
  bmp_core[20] = (8).to_byte()
  sheet.add_image("A4", Bytes::from_array(bmp_core), "bmp", "image/bmp")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(7, 8)}")

  // BMP (BITMAPINFOHEADER): dib size >=40, height may be negative.
  let bmp_info : Array[Byte] = Array::make(26, (0).to_byte())
  bmp_info[0] = (0x42).to_byte()
  bmp_info[1] = (0x4D).to_byte()
  bmp_info[14] = (40).to_byte()
  // width=9 @ 18, height=-10 @ 22
  bmp_info[18] = (9).to_byte()
  bmp_info[22] = (0xF6).to_byte()
  bmp_info[23] = (0xFF).to_byte()
  bmp_info[24] = (0xFF).to_byte()
  bmp_info[25] = (0xFF).to_byte()
  sheet.add_image("A5", Bytes::from_array(bmp_info), "bmp", "image/bmp")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(9, 10)}")

  // ICO: 0 width/height => 256.
  let ico : Array[Byte] = Array::make(22, (0).to_byte())
  // reserved=0
  ico[2] = (1).to_byte() // type=1
  ico[4] = (1).to_byte() // count=1
  ico[6] = (0).to_byte() // width=256
  ico[7] = (0).to_byte() // height=256
  sheet.add_image("A6", Bytes::from_array(ico), "ico", "image/x-icon")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(256, 256)}")

  // TIFF little-endian with LONG values.
  let tiff_le : Array[Byte] = []
  tiff_le.push((0x49).to_byte())
  tiff_le.push((0x49).to_byte())
  push_u16_le(tiff_le, 42)
  push_u32_le(tiff_le, 8)
  push_u16_le(tiff_le, 2) // entry count
  // tag 256 (width), type 4, count 1, value 300
  push_u16_le(tiff_le, 256)
  push_u16_le(tiff_le, 4)
  push_u32_le(tiff_le, 1)
  push_u32_le(tiff_le, 300)
  // tag 257 (height), type 4, count 1, value 200
  push_u16_le(tiff_le, 257)
  push_u16_le(tiff_le, 4)
  push_u32_le(tiff_le, 1)
  push_u32_le(tiff_le, 200)
  push_u32_le(tiff_le, 0)
  sheet.add_image("A7", Bytes::from_array(tiff_le), "tiff", "image/tiff")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(300, 200)}")

  // TIFF big-endian with SHORT values stored in high 16 bits.
  let tiff_be : Array[Byte] = []
  tiff_be.push((0x4D).to_byte())
  tiff_be.push((0x4D).to_byte())
  push_u16_be(tiff_be, 42)
  push_u32_be(tiff_be, 8)
  push_u16_be(tiff_be, 2)
  // tag 256 (width), type 3, count 1, value 10
  push_u16_be(tiff_be, 256)
  push_u16_be(tiff_be, 3)
  push_u32_be(tiff_be, 1)
  push_u32_be(tiff_be, 10 << 16)
  // tag 257 (height), type 3, count 1, value 20
  push_u16_be(tiff_be, 257)
  push_u16_be(tiff_be, 3)
  push_u32_be(tiff_be, 1)
  push_u32_be(tiff_be, 20 << 16)
  push_u32_be(tiff_be, 0)
  sheet.add_image("A8", Bytes::from_array(tiff_be), "tif", "image/tiff")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(10, 20)}")

  // SVG: width/height with units.
  let svg1 = @encoding/utf8.encode("<svg width=\"1in\" height=\"2in\"></svg>")
  sheet.add_image("A9", svg1, "svg", "image/svg+xml")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(96, 192)}")

  // SVG: viewBox fallback (no width/height attrs).
  let svg2 = @encoding/utf8.encode("<svg viewBox=\"0 0 10 20\"></svg>")
  sheet.add_image("A10", svg2, "svg", "image/svg+xml")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(10, 20)}")

  // EMF: 1 inch frame => 96 px.
  let emf : Array[Byte] = Array::make(44, (0).to_byte())
  // iType = 1 (u32 le)
  emf[0] = (1).to_byte()
  // rclFrame @ 24..36: left/top/right/bottom (u32 le)
  emf[32] = (0xEC).to_byte()
  emf[33] = (0x09).to_byte()
  emf[36] = (0xEC).to_byte()
  emf[37] = (0x09).to_byte()
  // signature @ 40: 0x464D4520 stored little-endian => 20 45 4D 46
  emf[40] = (0x20).to_byte()
  emf[41] = (0x45).to_byte()
  emf[42] = (0x4D).to_byte()
  emf[43] = (0x46).to_byte()
  sheet.add_image("A11", Bytes::from_array(emf), "emf", "image/emf")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(96, 96)}")

  // WMF: 1x2 inches (placeable header).
  let wmf : Array[Byte] = Array::make(22, (0).to_byte())
  // key 0x9AC6CDD7 (u32 le)
  wmf[0] = (0xD7).to_byte()
  wmf[1] = (0xCD).to_byte()
  wmf[2] = (0xC6).to_byte()
  wmf[3] = (0x9A).to_byte()
  // right=100, bottom=200, inch=100 (u16 le)
  wmf[10] = (0x64).to_byte()
  wmf[12] = (0xC8).to_byte()
  wmf[14] = (0x64).to_byte()
  sheet.add_image("A12", Bytes::from_array(wmf), "wmf", "image/wmf")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(96, 192)}")

  // EMZ/WMZ: gzip-compressed EMF/WMF.
  let emz = @zip.gzip(Bytes::from_array(emf)[:])
  sheet.add_image("A13", emz, "emz", "application/octet-stream")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(96, 96)}")
  let wmz = @zip.gzip(Bytes::from_array(wmf)[:])
  sheet.add_image("A14", wmz, "wmz", "application/octet-stream")
  inspect(last_image_emu(sheet), content="\{expected_image_emu(96, 192)}")

  // Malformed inputs should not crash and should fall back to default sizing.
  let bad = b""
  let bad_exts = [
    "png", "gif", "jpg", "bmp", "ico", "tif", "svg", "emf", "wmf", "emz", "wmz",
  ]
  for i in 0..<bad_exts.length() {
    let ext = bad_exts[i]
    sheet.add_image("B\{i + 1}", bad, ext, "application/octet-stream")
    let (w, h) = last_image_emu(sheet)
    inspect(w > 0 && h > 0, content="true")
  }
}
