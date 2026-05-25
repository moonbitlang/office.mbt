///|
pub(all) struct PdfCompositionEntry {
  label : String
  bytes : Int
  percent : Double
} derive(Debug, Eq, ToJson)

///|
fn pdf_composition_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_composition_struct_tree_root_name : PdfName = pdf_composition_name(
  "/StructTreeRoot",
)

///|
fn pdf_composition_struct_tree_root() -> PdfName {
  pdf_composition_struct_tree_root_name
}

///|
let pdf_composition_pg_name : PdfName = pdf_composition_name("/Pg")

///|
fn pdf_composition_pg() -> PdfName {
  pdf_composition_pg_name
}

///|
let pdf_composition_piece_info_name : PdfName = pdf_composition_name(
  "/PieceInfo",
)

///|
fn pdf_composition_piece_info() -> PdfName {
  pdf_composition_piece_info_name
}

///|
let pdf_composition_subtype_name : PdfName = pdf_composition_name("/Subtype")

///|
fn pdf_composition_subtype() -> PdfName {
  pdf_composition_subtype_name
}

///|
let pdf_composition_image_name : PdfName = pdf_composition_name("/Image")

///|
fn pdf_composition_image() -> PdfName {
  pdf_composition_image_name
}

///|
let pdf_composition_form_name : PdfName = pdf_composition_name("/Form")

///|
fn pdf_composition_form() -> PdfName {
  pdf_composition_form_name
}

///|
let pdf_composition_type_name : PdfName = pdf_composition_name("/Type")

///|
fn pdf_composition_type() -> PdfName {
  pdf_composition_type_name
}

///|
let pdf_composition_font_name : PdfName = pdf_composition_name("/Font")

///|
fn pdf_composition_font() -> PdfName {
  pdf_composition_font_name
}

///|
let pdf_composition_page_name : PdfName = pdf_composition_name("/Page")

///|
fn pdf_composition_page() -> PdfName {
  pdf_composition_page_name
}

///|
let pdf_composition_contents_name : PdfName = pdf_composition_name("/Contents")

///|
fn pdf_composition_contents() -> PdfName {
  pdf_composition_contents_name
}

///|
fn pdf_composition_mark_unseen(
  marked : @hashmap.HashMap[Int, Bool],
  output : Array[Int],
  number : Int,
) -> Unit {
  if !marked.contains(number) {
    marked[number] = true
    output.push(number)
  }
}

///|
fn pdf_composition_mark_references(
  document : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
  output : Array[Int],
  object : PdfObject,
  no_follow_entries? : ArrayView[PdfName] = [],
) -> Unit {
  for number in document.referenced_object_numbers(object, no_follow_entries~) {
    pdf_composition_mark_unseen(marked, output, number)
  }
}

///|
fn PdfDocument::pdf_composition_structure_info(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
) -> Array[Int] raise PdfError {
  let output : Array[Int] = []
  match self.catalog().lookup_immediate(pdf_composition_struct_tree_root()) {
    Some(struct_tree_root) =>
      pdf_composition_mark_references(self, marked, output, struct_tree_root, no_follow_entries=[
        pdf_composition_pg(),
      ])
    None => ()
  }
  output
}

///|
fn PdfDocument::pdf_composition_piece_info(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
) -> Array[Int] {
  let output : Array[Int] = []
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_composition_piece_info(), entry.2) {
      Some(piece_info) =>
        pdf_composition_mark_references(self, marked, output, piece_info)
      None => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_composition_images(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
  number : Int,
  object : PdfObject,
) -> Array[Int] {
  let output : Array[Int] = []
  if !marked.contains(number) {
    match self.lookup_direct(pdf_composition_subtype(), object) {
      Some(PdfNameObject(name)) if name == pdf_composition_image() =>
        pdf_composition_mark_unseen(marked, output, number)
      _ => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_composition_fonts(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
  number : Int,
  object : PdfObject,
) -> Array[Int] {
  let output : Array[Int] = []
  if !marked.contains(number) {
    match self.lookup_direct(pdf_composition_type(), object) {
      Some(PdfNameObject(name)) if name == pdf_composition_font() =>
        pdf_composition_mark_references(
          self,
          marked,
          output,
          PdfIndirect(number),
        )
      _ => ()
    }
  }
  output
}

///|
fn pdf_composition_content_numbers(
  contents : PdfObject,
  output : Array[Int],
) -> Unit {
  match contents {
    PdfIndirect(number) => output.push(number)
    PdfArray(values) =>
      for value in values {
        match value {
          PdfIndirect(number) => output.push(number)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_composition_content_streams(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
  number : Int,
  object : PdfObject,
) -> Array[Int] {
  let output : Array[Int] = []
  if !marked.contains(number) {
    match self.lookup_direct(pdf_composition_type(), object) {
      Some(PdfNameObject(name)) if name == pdf_composition_page() =>
        match object.lookup_immediate(pdf_composition_contents()) {
          Some(contents) => {
            let content_numbers : Array[Int] = []
            pdf_composition_content_numbers(contents, content_numbers)
            for content_number in content_numbers {
              pdf_composition_mark_unseen(marked, output, content_number)
            }
          }
          None => ()
        }
      _ =>
        match self.lookup_direct(pdf_composition_subtype(), object) {
          Some(PdfNameObject(name)) if name == pdf_composition_form() =>
            pdf_composition_mark_unseen(marked, output, number)
          _ => ()
        }
    }
  }
  output
}

///|
fn PdfDocument::pdf_composition_find_objects(
  self : PdfDocument,
) -> (Array[Int], Array[Int], Array[Int], Array[Int], Array[Int]) raise PdfError {
  let marked : @hashmap.HashMap[Int, Bool] = HashMap([])
  let images : Array[Int] = []
  let fonts : Array[Int] = []
  let content_streams : Array[Int] = []
  for entry in self.parsed_object_entries() {
    if !marked.contains(entry.0) {
      images.append(self.pdf_composition_images(marked, entry.0, entry.2))
      content_streams.append(
        self.pdf_composition_content_streams(marked, entry.0, entry.2),
      )
      fonts.append(self.pdf_composition_fonts(marked, entry.0, entry.2))
    }
  }
  let structure_info = self.pdf_composition_structure_info(marked)
  let piece_info = self.pdf_composition_piece_info(marked)
  (images, fonts, content_streams, structure_info, piece_info)
}

///|
fn PdfDocument::pdf_composition_object_size(
  self : PdfDocument,
  number : Int,
) -> Int raise PdfError {
  pdf_write_object(self.lookup_object_or_null(number)).length()
}

///|
fn pdf_composition_unique_numbers(numbers : ArrayView[Int]) -> Array[Int] {
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  let output : Array[Int] = []
  for number in numbers {
    if !seen.contains(number) {
      seen[number] = true
      output.push(number)
    }
  }
  output
}

///|
fn PdfDocument::pdf_composition_compressed_size(
  self : PdfDocument,
  numbers : ArrayView[Int],
) -> Int raise PdfError {
  let unique_numbers = pdf_composition_unique_numbers(numbers)
  if unique_numbers.length() == 0 {
    0
  } else if self.objects.object_stream_ids.length() == 0 {
    let mut total = 0
    for number in unique_numbers {
      total += self.pdf_composition_object_size(number)
    }
    total
  } else {
    let combined : Array[Byte] = []
    let mut stream_total = 0
    for number in unique_numbers {
      let object = self.lookup_object_or_null(number)
      match object {
        PdfStreamObject(_) =>
          stream_total += self.pdf_composition_object_size(number)
        _ => {
          let bytes = pdf_write_object(object)
          for byte in bytes {
            combined.push(byte)
          }
        }
      }
    }
    stream_total + pdf_flate_encode(Bytes::from_array(combined)).length()
  }
}

///|
fn PdfDocument::pdf_composition_xref_table_size(
  self : PdfDocument,
) -> Int raise PdfError {
  if self.objects.object_stream_ids.length() == 0 {
    20 * self.object_count()
  } else {
    let numbers = self.objects.object_stream_ids.keys().to_array()
    numbers.sort()
    self.pdf_composition_compressed_size(numbers)
  }
}

///|
fn pdf_composition_entry(
  label : String,
  bytes : Int,
  file_size : Int,
) -> PdfCompositionEntry {
  { label, bytes, percent: bytes.to_double() / file_size.to_double() * 100.0 }
}

///|
/// Return cpdf-style composition buckets for a document.
///
/// The result order is stable: images, fonts, content streams, structure info,
/// attached files, xref table, piece info, then unclassified bytes.
pub fn PdfDocument::composition(
  self : PdfDocument,
  file_size : Int,
) -> Array[PdfCompositionEntry] raise PdfError {
  if file_size <= 0 {
    raise BadNumberArgument("file_size must be positive")
  }
  let (
    image_numbers,
    font_numbers,
    content_numbers,
    structure_numbers,
    piece_info_numbers,
  ) = self.pdf_composition_find_objects()
  let images = self.pdf_composition_compressed_size(image_numbers)
  let fonts = self.pdf_composition_compressed_size(font_numbers)
  let content_streams = self.pdf_composition_compressed_size(content_numbers)
  let structure_info = self.pdf_composition_compressed_size(structure_numbers)
  let attached_files = self.size_attached_files()
  let xref_table = self.pdf_composition_xref_table_size()
  let piece_info = self.pdf_composition_compressed_size(piece_info_numbers)
  let classified = images +
    fonts +
    content_streams +
    structure_info +
    attached_files +
    xref_table +
    piece_info
  [
    pdf_composition_entry("Images", images, file_size),
    pdf_composition_entry("Fonts", fonts, file_size),
    pdf_composition_entry("Content streams", content_streams, file_size),
    pdf_composition_entry("Structure Info", structure_info, file_size),
    pdf_composition_entry("Attached Files", attached_files, file_size),
    pdf_composition_entry("XRef Table", xref_table, file_size),
    pdf_composition_entry("Piece Info", piece_info, file_size),
    pdf_composition_entry("Unclassified", file_size - classified, file_size),
  ]
}

///|
/// Convert a composition entry to the cpdf JSON row shape:
/// `[label, byte_count, percent]`.
pub fn PdfCompositionEntry::to_json(self : PdfCompositionEntry) -> Json {
  Json::array([
    Json::string(self.label),
    pdf_util_json_number(self.bytes),
    Json::number(self.percent),
  ])
}

///|
/// Return the document composition in cpdf JSON row format.
pub fn PdfDocument::composition_json(
  self : PdfDocument,
  file_size : Int,
) -> Json raise PdfError {
  let values : Array[Json] = []
  for entry in self.composition(file_size) {
    values.push(entry.to_json())
  }
  Json::array(values)
}

///|
/// Return the document composition serialized as UTF-8 JSON bytes.
pub fn PdfDocument::composition_json_blob(
  self : PdfDocument,
  file_size : Int,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.composition_json(file_size).stringify())
}

///|
fn pdf_composition_push_utf8(output : Array[Byte], text : String) -> Unit {
  for byte in @utf8.encode(text) {
    output.push(byte)
  }
}

///|
fn pdf_composition_percent_text(percent : Double) -> String {
  let rounded = (percent * 100.0).round().to_int()
  let negative = rounded < 0
  let magnitude = if negative { -rounded } else { rounded }
  let whole = magnitude / 100
  let fraction = magnitude % 100
  let fraction_text = if fraction < 10 {
    "0" + fraction.to_string()
  } else {
    fraction.to_string()
  }
  (if negative { "-" } else { "" }) + whole.to_string() + "." + fraction_text
}

///|
fn pdf_composition_push_text_entry(
  output : Array[Byte],
  entry : PdfCompositionEntry,
) -> Unit {
  pdf_composition_push_utf8(output, entry.label)
  pdf_composition_push_utf8(output, ": ")
  pdf_composition_push_utf8(output, entry.bytes.to_string())
  pdf_composition_push_utf8(output, " bytes (")
  pdf_composition_push_utf8(output, pdf_composition_percent_text(entry.percent))
  pdf_composition_push_utf8(output, "%)\n")
}

///|
fn pdf_composition_utf8_length(text : String) -> Int {
  @utf8.encode(text).length()
}

///|
fn pdf_composition_text_entry_length(entry : PdfCompositionEntry) -> Int {
  pdf_composition_utf8_length(entry.label) +
  pdf_composition_utf8_length(": ") +
  pdf_composition_utf8_length(entry.bytes.to_string()) +
  pdf_composition_utf8_length(" bytes (") +
  pdf_composition_utf8_length(pdf_composition_percent_text(entry.percent)) +
  pdf_composition_utf8_length("%)\n")
}

///|
fn pdf_composition_text_length(entries : ArrayView[PdfCompositionEntry]) -> Int {
  let mut length = 0
  for entry in entries {
    length += pdf_composition_text_entry_length(entry)
  }
  length
}

///|
/// Return the text that cpdf's `show_composition` prints when `json=false`.
pub fn PdfDocument::composition_text(
  self : PdfDocument,
  file_size : Int,
) -> PdfBytes raise PdfError {
  let entries = self.composition(file_size)
  let output : Array[Byte] = Array::new(
    capacity=pdf_composition_text_length(entries),
  )
  for entry in entries {
    pdf_composition_push_text_entry(output, entry)
  }
  Bytes::from_array(output)
}

///|
fn pdf_composition_bytes_with_newline(bytes : BytesView) -> PdfBytes {
  let output = Array::make(bytes.length() + 1, b'\n')
  for i in 0..<bytes.length() {
    output[i] = bytes[i]
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::composition`.
pub fn pdf_composition(
  document : PdfDocument,
  file_size : Int,
) -> Array[PdfCompositionEntry] raise PdfError {
  document.composition(file_size)
}

///|
/// Compatibility wrapper for `PdfDocument::composition_json_blob`.
pub fn pdf_show_composition_json_blob(
  file_size : Int,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.composition_json_blob(file_size)
}

///|
/// Return the bytes cpdf's `show_composition` would print.
pub fn pdf_show_composition(
  file_size : Int,
  json : Bool,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  if json {
    pdf_composition_bytes_with_newline(
      document.composition_json_blob(file_size),
    )
  } else {
    document.composition_text(file_size)
  }
}
