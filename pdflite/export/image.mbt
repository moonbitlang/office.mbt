// Raster images (port of the parts of krilla's `graphics::image` that Typst
// uses: 8-bit gray/RGB samples with an optional alpha channel and ICC
// profile, and JPEG and PNG passthrough).

///|
/// The color space of image samples.
#derive(Eq, Debug)
pub(all) enum ImageColorspace {
  Luma
  Rgb
  Cmyk
}

///|
fn ImageColorspace::components(self : ImageColorspace) -> Int32 {
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
  /// The image data of a PNG file (its concatenated `IDAT` chunks), embedded
  /// as is with a PNG predictor (krilla's `Repr::Png`): the zlib stream, the
  /// number of samples per pixel, the bit depth and, for indexed images, the
  /// palette (`PLTE`). Only non-interlaced images without alpha qualify
  /// (images with alpha use `Samples` with a mask): grayscale (`Luma`, 1
  /// sample of 1, 2, 4, 8 or 16 bits), RGB (`Rgb`, 3 samples of 8 or 16
  /// bits) and indexed images (`Rgb`, the base of the palette; 1 sample of 1,
  /// 2, 4 or 8 bits; 1 to 256 RGB palette entries, at most `2^bits`). Other
  /// combinations make `Document::finish` raise an `ImageError`, as do 16-bit
  /// samples before PDF 1.5.
  Png(Bytes, Int32, Int32, Bytes?)
  /// The samples of `Samples`, compressed: the zlib stream of the colour
  /// samples and, if the image has an alpha channel, the zlib stream of its
  /// alpha samples, each written as it is with `/FlateDecode`. This is the
  /// form an image is embedded in (krilla's `SampledRepr`, which is all its
  /// images keep of their samples), and [Image::deflated] makes it from
  /// `Samples`: a caller that embeds an image in several documents (an
  /// export after every edit) keeps this form and pays for the compression
  /// once. A stream that does not start as a zlib stream makes
  /// `Document::finish` raise an `ImageError`; whether it is the stream of
  /// the image's samples is the caller's to know, as the length of
  /// `Samples` is.
  Deflated(Bytes, Bytes?)
}

///|
/// A raster image.
pub(all) struct Image {
  /// A key identifying the image, used to embed equal images only once.
  key : String
  width : Int32
  height : Int32
  colorspace : ImageColorspace
  data : ImageData
  /// An ICC profile for the color channels.
  icc : Bytes?
  interpolate : Bool
  /// Whether the JPEG uses Adobe's inverted CMYK convention.
  inverted_cmyk : Bool
}

///|
/// The image with its samples compressed, for a caller that keeps it for
/// more than one document: `Samples` become `Deflated`, compressed as
/// `Document::finish` compresses the samples of an image that was drawn
/// with `Samples`. A document is, byte for byte, the same whether its
/// images were drawn in one form or the other.
///
/// An image that has nothing to compress is returned as it is: a JPEG and
/// the image data of a PNG are embedded as they are (a PNG that cannot be
/// embedded is refused by every document it is drawn in), and samples
/// without a byte are written without a filter.
///
/// krilla compresses when an image is made and keeps the result in the
/// image (`Image::from_custom`: `deflate_encode` of the colour and of the
/// alpha channel, behind the image's `Arc`), so that every document that is
/// given the image writes the same streams. Here the result is the image
/// value itself: this package has no table of images, and nothing of one
/// document is looked up for another. What a document adds (its colour
/// space, the stream of the profile, `/Interpolate`, the reference of the
/// mask, validation, the object numbers) is not part of it and is made for
/// every document.
pub fn Image::deflated(self : Image) -> Image {
  match self.data {
    Samples(color, alpha) => {
      // `put_stream` gives data without a byte no filter.
      if color.length() == 0 || (alpha is Some(alpha) && alpha.length() == 0) {
        return self
      }
      {
        ..self,
        data: Deflated(
          deflate_stream_data(color),
          alpha.map(deflate_stream_data),
        ),
      }
    }
    Deflated(_) | Jpeg(_) | Png(_) => self
  }
}

///|
/// Write the image XObject of 8-bit samples and, if the image has an alpha
/// channel, the soft mask. `deflated` says that the samples are zlib
/// streams already ([ImageData::Deflated]).
fn SerializeContext::put_sampled_image(
  self : SerializeContext,
  ref_ : Int32,
  d : DictBuilder,
  image : Image,
  color : Bytes,
  alpha : Bytes?,
  deflated~ : Bool,
) -> Unit {
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
    if deflated {
      self.put_deflated_stream(mask_ref, md.entries(), alpha)
    } else {
      self.put_stream(mask_ref, md.entries(), alpha)
    }
    d.set("SMask", Ref(mask_ref))
    self.register_validation_error(Transparency(self.location))
  }
  if deflated {
    self.put_deflated_stream(ref_, d.entries(), color)
  } else {
    self.put_stream(ref_, d.entries(), color)
  }
}

///|
fn SerializeContext::register_image(
  self : SerializeContext,
  image : Image,
) -> Int32 {
  let key = "image:\{image.key}:\{image.interpolate}"
  self.cached(key, r => {
    if image.data is Png(data, colors, bit_depth, palette) {
      match png_error(image, data, colors, bit_depth, palette) {
        Some(msg) => {
          self.register_error(ImageError(self.location, msg))
          return
        }
        None => ()
      }
      // krilla `KrillaError::SixteenBitImage`.
      if bit_depth == 16 && self.settings.pdf_version() < Pdf15 {
        self.register_error(
          ImageError(
            self.location,
            "16 bit images are not supported in this export mode",
          ),
        )
        return
      }
    }
    if image.data is Deflated(color, alpha) &&
      !(is_zlib_stream(color) && alpha.map_or(true, is_zlib_stream)) {
      self.register_error(
        ImageError(
          self.location,
          "the compressed samples of the image are not a zlib stream",
        ),
      )
      return
    }
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
      None =>
        d.set(
          "ColorSpace",
          self.regular_color_space_obj(
            match image.colorspace {
              Luma => Luma(0)
              Rgb => Rgb(0, 0, 0)
              Cmyk => Cmyk(0, 0, 0, 0)
            },
          ),
        )
    }
    // An indexed PNG uses the color space as the base of its palette
    // (krilla's `set_indexed_colorspace`).
    if image.data is Png(_, _, _, Some(palette)) &&
      d.get("ColorSpace") is Some(base) {
      d.set(
        "ColorSpace",
        Arr([Name("Indexed"), base, Int(palette.length() / 3 - 1), Str(palette)]),
      )
    }
    let bits_per_component = match image.data {
      Png(_, _, bit_depth, _) => bit_depth
      Samples(_) | Deflated(_) | Jpeg(_) => 8
    }
    d.set("BitsPerComponent", Int(bits_per_component))
    if image.interpolate {
      d.set("Interpolate", Bool(true))
    }
    match image.data {
      Samples(color, alpha) =>
        self.put_sampled_image(r, d, image, color, alpha, deflated=false)
      Deflated(color, alpha) =>
        self.put_sampled_image(r, d, image, color, alpha, deflated=true)
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
      Png(data, colors, bit_depth, _) => {
        d.set("Filter", Name("FlateDecode"))
        d.set(
          "DecodeParms",
          Dict([
            ("Predictor", Int(15)),
            ("Colors", Int(colors)),
            ("BitsPerComponent", Int(bit_depth)),
            ("Columns", Int(image.width)),
          ]),
        )
        self.put_stream(r, d.entries(), data, compress=false)
      }
    }
  })
}

///|
/// Whether data starts like a zlib stream that `/FlateDecode` decodes (RFC
/// 1950: the deflate method, a header whose check bits are right, no preset
/// dictionary) and is long enough to be one. This is not a check of the
/// stream, which would cost what keeping it saves: it tells compressed
/// samples from samples that were not compressed.
fn is_zlib_stream(data : Bytes) -> Bool {
  // The header, at least one block and the checksum.
  if data.length() < 8 {
    return false
  }
  let cmf = data[0].to_int()
  let flg = data[1].to_int()
  (cmf & 0x0f) == 8 &&
  cmf >> 4 <= 7 &&
  ((cmf << 8) | flg) % 31 == 0 &&
  (flg & 0x20) == 0
}

///|
/// Why PNG data can't be embedded as is, if it can't.
fn png_error(
  image : Image,
  data : Bytes,
  colors : Int32,
  bit_depth : Int32,
  palette : Bytes?,
) -> String? {
  if data.is_empty() {
    return Some("the PNG image data is empty")
  }
  if image.width <= 0 || image.height <= 0 {
    return Some("the PNG image is empty")
  }
  match palette {
    Some(palette) => {
      let entries = palette.length() / 3
      if colors != 1 || !(bit_depth is (1 | 2 | 4 | 8)) {
        Some(
          "an indexed PNG image needs 1 sample of 1, 2, 4 or 8 bits per pixel",
        )
      } else if palette.length() % 3 != 0 ||
        entries < 1 ||
        entries > 256 ||
        entries > 1 << bit_depth {
        Some("invalid PNG palette")
      } else if image.colorspace != Rgb {
        Some("the palette of an indexed PNG image must be RGB")
      } else {
        None
      }
    }
    None =>
      match (image.colorspace, colors, bit_depth) {
        (Luma, 1, 1 | 2 | 4 | 8 | 16) | (Rgb, 3, 8 | 16) => None
        _ =>
          Some(
            "unsupported PNG image (\{colors} samples of \{bit_depth} bits per pixel)",
          )
      }
  }
}
