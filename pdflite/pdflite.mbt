// Main package file for your library code.
// Put public APIs and shared helpers here.
// Keep blocks small and focused for easy refactors.

///|
pub using @core {
  type PdfCryptType,
  type PdfError,
  type PdfBytes,
  type PdfName,
  pdf_byte_of_int,
  pdf_bytes_of_array_view,
  pdf_bytes_of_view,
  pdf_bytes_copy,
  pdf_bytes_make,
  pdf_bytes_concat_views,
  pdf_bytes_of_int_array,
  pdf_bytes_of_int_arrays,
  pdf_bytes_map_int,
  pdf_int_array_of_bytes,
  pdf_string_of_int_arrays,
  pdf_string_of_int_array,
  pdf_bytes_length,
  pdf_bytes_get,
  pdf_bytes_to_array,
  pdf_bytes_to_fixed_array,
  pdf_name_of_bytes,
  pdf_name_of_view,
}
