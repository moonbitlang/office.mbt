///|
fn pdf_util_stream_of_json_ops(
  dictionary_json : Json,
  op_jsons : ArrayView[Json],
) -> PdfObject raise PdfError {
  let ops : Array[@content.PdfContentOp] = Array::new(
    capacity=op_jsons.length(),
  )
  for op_json in op_jsons {
    ops.push(pdf_util_content_op_of_json(op_json))
  }
  let stream_data = pdf_content_bytes_of_ops(ops)
  let dictionary = pdf_object_of_json(dictionary_json).add_dict_entry(
    @syntax.pdf_object_length_name(),
    PdfInteger(stream_data.length()),
  )
  pdf_stream(dictionary, StreamGot(stream_data))
}
