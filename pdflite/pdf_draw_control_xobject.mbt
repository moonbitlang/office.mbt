///|
/// Append a reference to a previously defined XObject.
pub fn PdfDrawControl::use_xobject(
  self : PdfDrawControl,
  name : String,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawUse(name))
}

///|
/// Append an image-resource reference by name.
pub fn PdfDrawControl::add_image(
  self : PdfDrawControl,
  name : String,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawImage(name))
}

///|
/// Append a JPEG image XObject operation from supplied image bytes.
///
/// This ports the data-supplied branch of `cpdfdrawcontrol.ml`'s `addjpeg`.
pub fn PdfDrawControl::add_jpeg_data(
  self : PdfDrawControl,
  name : String,
  data : BytesView,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawImageXObject(name, pdf_image_object_of_jpeg_data(data)))
}

///|
/// Append a PNG image XObject operation from supplied image bytes.
///
/// `document` is used when the PNG needs an alpha-mask object, matching
/// `cpdfdrawcontrol.ml`'s `addpng pdf ?data` boundary.
pub fn PdfDrawControl::add_png_data(
  self : PdfDrawControl,
  document : PdfDocument,
  name : String,
  data : BytesView,
) -> Unit raise @core.PdfError {
  self.add_op(
    PdfDrawImageXObject(name, document.pdf_image_object_of_png_data(data)),
  )
}

///|
/// Append a JPEG2000 image XObject operation from supplied image bytes.
///
/// This ports the data-supplied branch of `cpdfdrawcontrol.ml`'s
/// `addjpeg2000`.
pub fn PdfDrawControl::add_jpeg2000_data(
  self : PdfDrawControl,
  name : String,
  data : BytesView,
) -> Unit raise @core.PdfError {
  self.add_op(
    PdfDrawImageXObject(name, pdf_image_object_of_jpeg2000_data(data)),
  )
}

///|
/// Source-spelled cpdfdrawcontrol `addjpeg` for supplied image bytes.
///
/// `path_to_im` is accepted for source API parity with cpdf's ImageMagick
/// fallback hook and is otherwise ignored by pdflite's in-process parser.
pub fn pdf_addjpeg(
  control : PdfDrawControl,
  name : String,
  data : BytesView,
  path_to_im? : String = "",
) -> Unit raise @core.PdfError {
  ignore(path_to_im)
  control.add_jpeg_data(name, data)
}

///|
/// Source-spelled cpdfdrawcontrol `addpng` for supplied image bytes.
pub fn pdf_addpng(
  control : PdfDrawControl,
  document : PdfDocument,
  name : String,
  data : BytesView,
) -> Unit raise @core.PdfError {
  control.add_png_data(document, name, data)
}

///|
/// Source-spelled cpdfdrawcontrol `addjpeg2000` for supplied image bytes.
pub fn pdf_addjpeg2000(
  control : PdfDrawControl,
  name : String,
  data : BytesView,
) -> Unit raise @core.PdfError {
  control.add_jpeg2000_data(name, data)
}

///|
/// Start collecting a named form XObject.
pub fn PdfDrawControl::start_xobject(
  self : PdfDrawControl,
  name : String,
) -> Unit {
  self.frames.push({ name, ops: [] })
}

///|
/// Set the bounding box used for the next closed form XObject.
pub fn PdfDrawControl::set_xobject_bbox(
  self : PdfDrawControl,
  bbox : @geometry.PdfCoordRectangle,
) -> Unit {
  self.xobject_bbox = bbox
}

///|
/// Parse and set the bounding box used for the next closed form XObject.
///
/// This ports `cpdfdrawcontrol.ml`'s `xobjbbox` command helper.
pub fn PdfDrawControl::set_xobject_bbox_from_string(
  self : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise @core.PdfError {
  self.xobject_bbox = document.parse_coordinate_rectangle(text)
}

///|
/// Finish the current form XObject and append a `PdfDrawFormXObject` op.
pub fn PdfDrawControl::end_xobject(
  self : PdfDrawControl,
) -> Unit raise @core.PdfError {
  match self.frames.pop() {
    Some(frame) if self.frames.length() > 0 => {
      let bbox = self.xobject_bbox
      self.add_op(
        PdfDrawFormXObject(
          bbox.x,
          bbox.y,
          bbox.width,
          bbox.height,
          frame.name,
          pdf_draw_control_copy_ops(frame.ops),
        ),
      )
    }
    Some(frame) => {
      self.frames.push(frame)
      raise SoftError("no drawops")
    }
    None => raise SoftError("too many -end-xobj or -et")
  }
}
