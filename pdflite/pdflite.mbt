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

///|
pub using @geometry {
  type PdfUnit,
  type PaperSize,
  type Point2,
  type TransformOp,
  type TransformMatrix,
  type TransformDecomposition,
  unit_points,
  unit_inches,
  unit_centimetres,
  unit_millimetres,
  paper_size_make,
  paper_a0,
  paper_a1,
  paper_a2,
  paper_a3,
  paper_a4,
  paper_a5,
  paper_a6,
  paper_a7,
  paper_a8,
  paper_a9,
  paper_a10,
  paper_usletter,
  paper_uslegal,
  transform_string_of_op,
  transform_string_of_ops,
  transform_string_of_transform,
  transform_string_of_matrix,
  point2,
  transform_identity_matrix,
  transform_identity,
  transform_translate,
  transform_matrix_compose,
  transform_scale,
  transform_rotate,
  transform_shear_x,
  transform_shear_y,
  transform_compose_op,
  transform_append,
  transform_apply_matrix,
  transform_matrix_of_op,
  transform_matrix_of_ops,
  transform_matrix_of_transform,
  transform_apply_ops,
  transform_apply,
  transform_matrix_invert,
  transform_decompose,
  transform_recompose,
  transform_recompose_components,
}

///|
using @number_set {type PdfNumberSet, pdf_number_set, pdf_push_unique_number}

///|
pub using @crypt_core {
  type PdfPermission,
  pdf_p_of_permissions,
  pdf_permissions_of_p,
}

///|
using @crypt_core {
  pdf_arc4_crypt,
  pdf_md5_digest,
  pdf_sha256_digest,
  pdf_sha384_digest,
  pdf_sha512_digest,
  pdf_aes_encrypt_block,
  pdf_aes_cbc_decrypt,
  pdf_aes_cbc_encrypt_with_iv,
  pdf_aes_ecb_decrypt,
  pdf_encryption_object_key,
  pdf_arc4_crypt_object,
}
