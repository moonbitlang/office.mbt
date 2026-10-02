///|
fn rgb_image(
  key? : String = "rgb",
  alpha? : Bytes? = None,
  interpolate? : Bool = false,
  icc? : Bytes? = None,
) -> @export.Image {
  {
    key,
    width: 2,
    height: 1,
    colorspace: Rgb,
    data: Samples(b"\xff\x00\x00\x00\x00\xff", alpha),
    icc,
    interpolate,
    inverted_cmyk: false,
  }
}

///|
/// A minimal JPEG-like byte string (the exporter passes JPEGs through
/// without decoding them).
let fake_jpeg : Bytes = b"\xff\xd8\xff\xe0JFIF\x00fake\xff\xd9"

///|
/// The raw (undecoded) data of a stream.
fn Parsed::raw_stream_data(
  self : Parsed,
  obj : @syntax.PdfObject,
) -> Bytes raise {
  guard self.resolve(obj) is PdfStreamObject(s) else {
    fail("expected a stream")
  }
  @syntax.pdf_stream_data_bytes(s.data)
}

///|
test "raw samples are embedded as an image XObject" {
  let p = parse(
    one_page(s => {
      s.push_transform(@export.Transform::from_translate(10.0, 20.0))
      s.draw_image(rgb_image(), @export.Size::from_wh(40.0, 20.0).unwrap())
      s.pop()
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|40 0 0 20 10 60 cm
      #|/x0 Do
      #|Q
      #|
    ),
  )
  let x0 = p.path(p.page(0), ["Resources", "XObject", "x0"])
  inspect(
    p.show(x0),
    content=(
      #|stream<</Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length 12>>
    ),
  )
  debug_inspect(
    p.stream_data(x0),
    content=(
      #|<Bytes: [0xff, 0x00, 0x00, 0x00, 0x00, 0xff]>
    ),
  )
}

///|
test "an alpha channel becomes a soft mask" {
  let p = parse(
    one_page(s => {
      s.draw_image(
        rgb_image(alpha=Some(b"\x80\xff"), interpolate=true),
        @export.Size::from_wh(2.0, 1.0).unwrap(),
      )
    }),
  )
  let x0 = p.path(p.page(0), ["Resources", "XObject", "x0"])
  inspect(
    p.show(x0),
    content=(
      #|stream<</Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Interpolate true /SMask R /Filter /FlateDecode /Length 12>>
    ),
  )
  let smask = p.get(x0, "SMask")
  inspect(
    p.show(p.resolve(smask)),
    content=(
      #|stream<</Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Interpolate true /Filter /FlateDecode /Length 10>>
    ),
  )
  debug_inspect(
    p.stream_data(smask),
    content=(
      #|<Bytes: [0x80, 0xff]>
    ),
  )
}

///|
test "ICC profiles are embedded as ICCBased color spaces" {
  let p = parse(
    one_page(s => {
      s.draw_image(
        {
          ..rgb_image(icc=Some(b"fake icc profile")),
          colorspace: Luma,
          data: Samples(b"\x00\xff", None),
        },
        @export.Size::from_wh(2.0, 1.0).unwrap(),
      )
    }),
  )
  let x0 = p.path(p.page(0), ["Resources", "XObject", "x0"])
  let cs = p.items(p.get(x0, "ColorSpace"))
  inspect(
    p.show(cs[0]),
    content=(
      #|/ICCBased
    ),
  )
  inspect(
    p.show(cs[1]),
    content=(
      #|stream<</N 1 /Alternate /DeviceGray /Filter /FlateDecode /Length 24>>
    ),
  )
  inspect(latin1(p.stream_data(cs[1])), content="fake icc profile")
}

///|
test "JPEG data is passed through with DCTDecode" {
  let jpeg = @export.Image::{
    key: "jpeg",
    width: 3,
    height: 4,
    colorspace: Rgb,
    data: Jpeg(fake_jpeg),
    icc: None,
    interpolate: false,
    inverted_cmyk: false,
  }
  let cmyk = @export.Image::{
    ..jpeg,
    key: "cmyk",
    colorspace: Cmyk,
    inverted_cmyk: true,
  }
  let p = parse(
    one_page(s => {
      s.draw_image(jpeg, @export.Size::from_wh(3.0, 4.0).unwrap())
      s.draw_image(cmyk, @export.Size::from_wh(3.0, 4.0).unwrap())
    }),
  )
  let x0 = p.path(p.page(0), ["Resources", "XObject", "x0"])
  inspect(
    p.show(x0),
    content=(
      #|stream<</Type /XObject /Subtype /Image /Width 3 /Height 4 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length 15>>
    ),
  )
  inspect(p.raw_stream_data(x0) == fake_jpeg, content="true")
  let x1 = p.path(p.page(0), ["Resources", "XObject", "x1"])
  inspect(
    p.show(x1),
    content=(
      #|stream<</Type /XObject /Subtype /Image /Width 3 /Height 4 /ColorSpace /DeviceCMYK /BitsPerComponent 8 /Decode [1 0 1 0 1 0 1 0] /Filter /DCTDecode /Length 15>>
    ),
  )
}

///|
test "images with the same key are embedded once" {
  let p = parse(
    one_page(s => {
      s.draw_image(rgb_image(), @export.Size::from_wh(2.0, 1.0).unwrap())
      s.draw_image(rgb_image(), @export.Size::from_wh(4.0, 2.0).unwrap())
      s.draw_image(
        rgb_image(key="other"),
        @export.Size::from_wh(4.0, 2.0).unwrap(),
      )
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|2 0 0 1 0 99 cm
      #|/x0 Do
      #|Q
      #|q
      #|4 0 0 2 0 98 cm
      #|/x0 Do
      #|Q
      #|q
      #|4 0 0 2 0 98 cm
      #|/x1 Do
      #|Q
      #|
    ),
  )
  inspect(
    p.keys(p.path(p.page(0), ["Resources", "XObject"])).join(" "),
    content=(
      #|x0 x1
    ),
  )
}

///|
test "image validation" {
  let draw = (image : @export.Image, a : @export.Archival) => {
    export_result(() => {
      one_page(
        s => s.draw_image(image, @export.Size::from_wh(1.0, 1.0).unwrap()),
        settings=settings_with(a=Some(a)),
      )
    })
  }
  inspect(
    draw(rgb_image(interpolate=true), A2_B),
    content=(
      #|Validation: ImageInterpolation by PDF/A-2b
    ),
  )
  inspect(
    draw(rgb_image(alpha=Some(b"\x00\x00")), A1_B),
    content=(
      #|Validation: Transparency by PDF/A-1b
    ),
  )
  inspect(draw(rgb_image(alpha=Some(b"\x00\x00")), A2_B), content="ok")
}

///|
/// A PNG passthrough image from unfiltered scanlines (filter type 0).
fn png_image(
  width : Int,
  rows : Array[Array[Int]],
  colorspace : @export.ImageColorspace,
  colors : Int,
  bit_depth : Int,
  palette? : Bytes? = None,
  icc? : Bytes? = None,
) -> @export.Image {
  let raw : Array[Byte] = []
  for row in rows {
    raw.push(b'\x00')
    for b in row {
      raw.push(b.to_byte())
    }
  }
  {
    key: "png:\{colors}:\{bit_depth}:\{palette is Some(_)}:\{icc is Some(_)}",
    width,
    height: rows.length(),
    colorspace,
    data: Png(
      @flate.pdf_flate_encode(Bytes::from_array(raw)),
      colors,
      bit_depth,
      palette,
    ),
    icc,
    interpolate: false,
    inverted_cmyk: false,
  }
}

///|
test "PNG passthrough images keep their IDAT data with a PNG predictor" {
  let images = [
    png_image(2, [[255, 0, 0, 0, 0, 255]], Rgb, 3, 8),
    png_image(3, [[0, 128, 255]], Luma, 1, 8),
    png_image(
      4,
      [[0b00011011]],
      Rgb,
      1,
      2,
      palette=Some(b"\xff\x00\x00\x00\xff\x00\x00\x00\xff\xff\xff\xff"),
    ),
    png_image(
      1,
      [[0]],
      Rgb,
      1,
      8,
      palette=Some(b"\x10\x20\x30"),
      icc=Some(b"icc"),
    ),
    png_image(1, [[0x12, 0x34]], Luma, 1, 16),
  ]
  let p = parse(
    one_page(s => {
      for image in images {
        s.draw_image(image, @export.Size::from_wh(10.0, 10.0).unwrap())
      }
    }),
  )
  let xobjects = p.path(p.page(0), ["Resources", "XObject"])
  inspect(
    p.keys(xobjects).map(k => p.show(p.get(xobjects, k))).join("\n"),
    content=(
      #|stream<</Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /DecodeParms <</Predictor 15 /Colors 3 /BitsPerComponent 8 /Columns 2>> /Length 13>>
      #|stream<</Type /XObject /Subtype /Image /Width 3 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode /DecodeParms <</Predictor 15 /Colors 1 /BitsPerComponent 8 /Columns 3>> /Length 12>>
      #|stream<</Type /XObject /Subtype /Image /Width 4 /Height 1 /ColorSpace [/Indexed /DeviceRGB 3 <FF000000FF000000FFFFFFFF>] /BitsPerComponent 2 /Filter /FlateDecode /DecodeParms <</Predictor 15 /Colors 1 /BitsPerComponent 2 /Columns 4>> /Length 10>>
      #|stream<</Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace [/Indexed [/ICCBased R] 0 <102030>] /BitsPerComponent 8 /Filter /FlateDecode /DecodeParms <</Predictor 15 /Colors 1 /BitsPerComponent 8 /Columns 1>> /Length 10>>
      #|stream<</Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 16 /Filter /FlateDecode /DecodeParms <</Predictor 15 /Colors 1 /BitsPerComponent 16 /Columns 1>> /Length 11>>
    ),
  )
  // The reader undoes the predictor.
  debug_inspect(
    p.stream_data(p.get(xobjects, "x0")),
    content=(
      #|<Bytes: [0xff, 0x00, 0x00, 0x00, 0x00, 0xff]>
    ),
  )
  debug_inspect(
    p.stream_data(p.get(xobjects, "x2")),
    content=(
      #|<Bytes: [0x1b]>
    ),
  )
}

///|
test "invalid PNG passthrough images are rejected" {
  let draw = (image : @export.Image) => {
    export_result(() => {
      one_page(s => {
        s.draw_image(image, @export.Size::from_wh(1.0, 1.0).unwrap())
      })
    })
  }
  let rgb = png_image(1, [[1, 2, 3]], Rgb, 3, 8)
  let results = [
    // Alpha channels must use samples with a mask.
    draw(png_image(1, [[1, 2, 3, 4]], Rgb, 4, 8)),
    draw(png_image(1, [[1, 2]], Luma, 2, 8)),
    // Unsupported depths and color spaces.
    draw(png_image(1, [[1]], Rgb, 3, 4)),
    draw(png_image(1, [[1]], Cmyk, 4, 8)),
    draw(png_image(1, [[1]], Luma, 3, 8)),
    // Palettes.
    draw(png_image(1, [[0]], Rgb, 3, 8, palette=Some(b"\x00\x00\x00"))),
    draw(png_image(1, [[0]], Rgb, 1, 16, palette=Some(b"\x00\x00\x00"))),
    draw(png_image(1, [[0]], Rgb, 1, 8, palette=Some(b"\x00\x00"))),
    draw(
      png_image(
        1,
        [[0]],
        Rgb,
        1,
        1,
        palette=Some(b"\x00\x00\x00\x01\x01\x01\x02\x02\x02"),
      ),
    ),
    draw(png_image(1, [[0]], Rgb, 1, 8, palette=Some(b""))),
    draw(png_image(1, [[0]], Luma, 1, 8, palette=Some(b"\x00\x00\x00"))),
    // Empty data.
    draw({ ..rgb, data: Png(b"", 3, 8, None), }),
  ]
  inspect(
    results.join("\n"),
    content=(
      #|ImageError: unsupported PNG image (4 samples of 8 bits per pixel)
      #|ImageError: unsupported PNG image (2 samples of 8 bits per pixel)
      #|ImageError: unsupported PNG image (3 samples of 4 bits per pixel)
      #|ImageError: unsupported PNG image (4 samples of 8 bits per pixel)
      #|ImageError: unsupported PNG image (3 samples of 8 bits per pixel)
      #|ImageError: an indexed PNG image needs 1 sample of 1, 2, 4 or 8 bits per pixel
      #|ImageError: an indexed PNG image needs 1 sample of 1, 2, 4 or 8 bits per pixel
      #|ImageError: invalid PNG palette
      #|ImageError: invalid PNG palette
      #|ImageError: invalid PNG palette
      #|ImageError: the palette of an indexed PNG image must be RGB
      #|ImageError: the PNG image data is empty
    ),
  )
  // 16-bit samples need PDF 1.5.
  let sixteen = png_image(1, [[0, 1, 0, 2, 0, 3]], Rgb, 3, 16)
  inspect(
    export_result(() => {
      one_page(
        s => s.draw_image(sixteen, @export.Size::from_wh(1.0, 1.0).unwrap()),
        settings=settings_with(version=Pdf14),
      )
    }),
    content=(
      #|ImageError: 16 bit images are not supported in this export mode
    ),
  )
  inspect(
    export_result(() => {
      one_page(
        s => s.draw_image(sixteen, @export.Size::from_wh(1.0, 1.0).unwrap()),
        settings=settings_with(version=Pdf15),
      )
    }),
    content="ok",
  )
}
