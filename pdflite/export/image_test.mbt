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
