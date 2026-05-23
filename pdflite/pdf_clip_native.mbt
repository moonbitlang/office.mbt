///|
#cfg(target="native")
#borrow(subject, clip, status)
extern "C" fn pdf_clip_polygon_clip_ffi(
  subject : PdfBytes,
  clip : PdfBytes,
  operation : Int,
  status : Ref[Int],
) -> PdfBytes = "pdflite_gpc_clip"

///|
#cfg(target="native")
fn pdf_clip_raise_bad_native_encoding() -> Unit raise PdfError {
  raise BadNumberArgument("pdf_clip_polygon_clip: malformed native polygon")
}

///|
#cfg(target="native")
fn pdf_clip_push_i32_le(
  output : Array[Byte],
  value : Int,
) -> Unit raise PdfError {
  if value < 0 {
    pdf_clip_raise_bad_native_encoding()
  }
  output.push((value & 0xff).to_byte())
  output.push(((value >> 8) & 0xff).to_byte())
  output.push(((value >> 16) & 0xff).to_byte())
  output.push(((value >> 24) & 0xff).to_byte())
}

///|
#cfg(target="native")
fn pdf_clip_push_u64_le(output : Array[Byte], value : UInt64) -> Unit {
  for byte in value.to_le_bytes() {
    output.push(byte)
  }
}

///|
#cfg(target="native")
fn pdf_clip_encode_polygon(polygon : PdfClipPolygon) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_clip_push_i32_le(output, polygon.contours.length())
  for contour in polygon.contours {
    pdf_clip_push_i32_le(output, contour.hole_flag())
    pdf_clip_push_i32_le(output, contour.vertices.length())
    for vertex in contour.vertices {
      pdf_clip_push_u64_le(output, vertex.x.reinterpret_as_uint64())
      pdf_clip_push_u64_le(output, vertex.y.reinterpret_as_uint64())
    }
  }
  Bytes::from_array(output)
}

///|
#cfg(target="native")
fn pdf_clip_read_i32_le(
  data : BytesView,
  position : Ref[Int],
) -> Int raise PdfError {
  if position.val < 0 ||
    position.val > data.length() ||
    data.length() - position.val < 4 {
    raise EndOfInput
  }
  let index = position.val
  let value = data[index].to_int() |
    (data[index + 1].to_int() << 8) |
    (data[index + 2].to_int() << 16) |
    (data[index + 3].to_int() << 24)
  position.val += 4
  if value < 0 {
    pdf_clip_raise_bad_native_encoding()
  }
  value
}

///|
#cfg(target="native")
fn pdf_clip_read_u64_le(
  data : BytesView,
  position : Ref[Int],
) -> UInt64 raise PdfError {
  if position.val < 0 ||
    position.val > data.length() ||
    data.length() - position.val < 8 {
    raise EndOfInput
  }
  let index = position.val
  let mut value : UInt64 = 0
  for offset in 0..<8 {
    value = value | (data[index + offset].to_uint64() << (offset * 8))
  }
  position.val += 8
  value
}

///|
#cfg(target="native")
fn pdf_clip_decode_count_for_remaining_bytes(
  count : Int,
  bytes_per_item : Int,
  data : BytesView,
  position : Ref[Int],
) -> Unit raise PdfError {
  if count < 0 ||
    bytes_per_item <= 0 ||
    count > (data.length() - position.val) / bytes_per_item {
    pdf_clip_raise_bad_native_encoding()
  }
}

///|
#cfg(target="native")
fn pdf_clip_decode_polygon(data : BytesView) -> PdfClipPolygon raise PdfError {
  let position = Ref::{ val: 0 }
  let contour_count = pdf_clip_read_i32_le(data, position)
  pdf_clip_decode_count_for_remaining_bytes(contour_count, 8, data, position)
  let contours : Array[PdfClipContour] = []
  for _ in 0..<contour_count {
    let hole_flag = pdf_clip_read_i32_le(data, position)
    if hole_flag != 0 && hole_flag != 1 {
      pdf_clip_raise_bad_native_encoding()
    }
    let vertex_count = pdf_clip_read_i32_le(data, position)
    pdf_clip_decode_count_for_remaining_bytes(vertex_count, 16, data, position)
    let vertices : Array[PdfClipVertex] = []
    for _ in 0..<vertex_count {
      vertices.push(
        pdf_clip_vertex(
          pdf_clip_read_u64_le(data, position).reinterpret_as_double(),
          pdf_clip_read_u64_le(data, position).reinterpret_as_double(),
        ),
      )
    }
    contours.push(pdf_clip_contour(hole_flag == 1, vertices))
  }
  if position.val != data.length() {
    pdf_clip_raise_bad_native_encoding()
  }
  pdf_clip_polygon(contours)
}

///|
/// Clip `subject` by `clip` using cpdf's GPC-backed polygon operation.
///
/// This native-target wrapper preserves cpdf's operation-code mapping and
/// raises `PdfError::BadNumberArgument` when the native GPC bridge rejects the
/// encoded polygon payload.
#cfg(target="native")
pub fn pdf_clip_polygon_clip(
  operation : PdfClipOperation,
  subject : PdfClipPolygon,
  clip : PdfClipPolygon,
) -> PdfClipPolygon raise PdfError {
  let subject_bytes = pdf_clip_encode_polygon(subject)
  let clip_bytes = pdf_clip_encode_polygon(clip)
  let status = Ref::{ val: 0 }
  let result = pdf_clip_polygon_clip_ffi(
    subject_bytes,
    clip_bytes,
    operation.gpc_code(),
    status,
  )
  if status.val != 1 {
    raise BadNumberArgument("pdf_clip_polygon_clip: native GPC failure")
  }
  pdf_clip_decode_polygon(result)
}

///|
/// Clip `subject` by `clip` using this cpdf/GPC operation.
#cfg(target="native")
pub fn PdfClipOperation::clip_polygons(
  self : PdfClipOperation,
  subject : PdfClipPolygon,
  clip : PdfClipPolygon,
) -> PdfClipPolygon raise PdfError {
  pdf_clip_polygon_clip(self, subject, clip)
}

///|
/// Source-spelled compatibility wrapper for cpdfclip's native clip operation.
#cfg(target="native")
pub fn pdf_gpcml_clippolygon(
  operation : PdfClipOperation,
  subject : PdfClipPolygon,
  clip : PdfClipPolygon,
) -> PdfClipPolygon raise PdfError {
  pdf_clip_polygon_clip(operation, subject, clip)
}
