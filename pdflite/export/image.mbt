// Raster images (port of the parts of krilla's `graphics::image` that Typst
// uses: 8-bit gray/RGB samples with an optional alpha channel and ICC
// profile, and JPEG passthrough).

///|
/// The color space of image samples.
pub(all) enum ImageColorspace {
  Luma
  Rgb
  Cmyk
} derive(Eq, Debug)

///|
fn ImageColorspace::components(self : ImageColorspace) -> Int {
  match self {
    Luma => 1
    Rgb => 3
    Cmyk => 4
  }
}

///|
fn ImageColorspace::device_name(self : ImageColorspace) -> String {
  match self {
    Luma => "DeviceGray"
    Rgb => "DeviceRGB"
    Cmyk => "DeviceCMYK"
  }
}

///|
/// The data of an image.
pub(all) enum ImageData {
  /// Raw 8-bit samples (row-major, interleaved components) and an optional
  /// 8-bit alpha channel.
  Samples(Bytes, Bytes?)
  /// A JPEG file, embedded as is.
  Jpeg(Bytes)
}

///|
/// A raster image.
pub(all) struct Image {
  /// A key identifying the image, used to embed equal images only once.
  key : String
  width : Int
  height : Int
  colorspace : ImageColorspace
  data : ImageData
  /// An ICC profile for the color channels.
  icc : Bytes?
  interpolate : Bool
  /// Whether the JPEG uses Adobe's inverted CMYK convention.
  inverted_cmyk : Bool
}

///|
fn SerializeContext::register_image(
  self : SerializeContext,
  image : Image,
) -> Int {
  let key = "image:\{image.key}:\{image.interpolate}"
  self.cached(key, r => {
    if image.interpolate {
      self.register_validation_error(ImageInterpolation(self.location))
    }
    let d = DictBuilder::new()
    d.set("Type", Name("XObject"))
    d.set("Subtype", Name("Image"))
    d.set("Width", Int(image.width))
    d.set("Height", Int(image.height))
    match image.icc {
      Some(icc) => {
        let icc_ref = self.new_ref()
        self.put_stream(
          icc_ref,
          [
            ("N", Int(image.colorspace.components())),
            ("Alternate", Name(image.colorspace.device_name())),
          ],
          icc,
        )
        d.set("ColorSpace", Arr([Name("ICCBased"), Ref(icc_ref)]))
      }
      None => d.set("ColorSpace", Name(image.colorspace.device_name()))
    }
    d.set("BitsPerComponent", Int(8))
    if image.interpolate {
      d.set("Interpolate", Bool(true))
    }
    match image.data {
      Samples(color, alpha) => {
        if alpha is Some(alpha) {
          let mask_ref = self.new_ref()
          let md = DictBuilder::new()
          md.set("Type", Name("XObject"))
          md.set("Subtype", Name("Image"))
          md.set("Width", Int(image.width))
          md.set("Height", Int(image.height))
          md.set("ColorSpace", Name("DeviceGray"))
          md.set("BitsPerComponent", Int(8))
          if image.interpolate {
            md.set("Interpolate", Bool(true))
          }
          self.put_stream(mask_ref, md.entries(), alpha)
          d.set("SMask", Ref(mask_ref))
          self.register_validation_error(Transparency(self.location))
        }
        self.put_stream(r, d.entries(), color)
      }
      Jpeg(data) => {
        if image.colorspace == Cmyk && image.inverted_cmyk {
          d.set(
            "Decode",
            Arr([Int(1), Int(0), Int(1), Int(0), Int(1), Int(0), Int(1), Int(0)]),
          )
        }
        d.set("Filter", Name("DCTDecode"))
        self.put_stream(r, d.entries(), data, compress=false)
      }
    }
  })
}
