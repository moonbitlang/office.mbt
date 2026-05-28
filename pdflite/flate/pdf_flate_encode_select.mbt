///|
fn pdf_flate_default_header() -> Array[Byte] {
  [0x78, 0x01]
}

///|
fn pdf_flate_header_for_level(level : Int) -> Array[Byte] raise @core.PdfError {
  guard level >= 0 && level <= 9 else { raise InvalidFlateData }
  let compression_hint = if level <= 1 {
    0
  } else if level <= 5 {
    1
  } else if level == 6 {
    2
  } else {
    3
  }
  let cmf = 0x78
  let flg_without_check = compression_hint << 6
  let remainder = ((cmf << 8) + flg_without_check) % 31
  let fcheck = if remainder == 0 { 0 } else { 31 - remainder }
  [cmf.to_byte(), (flg_without_check + fcheck).to_byte()]
}

///|
fn pdf_flate_output_with_header(
  header : ArrayView[Byte],
  body_capacity_hint : Int,
) -> Array[Byte] {
  let output : Array[Byte] = Array::new(
    capacity=header.length() + body_capacity_hint,
  )
  for byte in header {
    output.push(byte)
  }
  output
}

///|
fn pdf_flate_shortest(a : @core.PdfBytes, b : @core.PdfBytes) -> @core.PdfBytes {
  if b.length() < a.length() {
    b
  } else {
    a
  }
}

///|
fn pdf_flate_shortest_result(
  current : @core.PdfBytes,
  candidate : Result[@core.PdfBytes, Error],
) -> @core.PdfBytes {
  match candidate {
    Ok(bytes) => pdf_flate_shortest(current, bytes)
    Err(_) => current
  }
}

///|
fn pdf_flate_encode_shortest_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
  max_probes : Int,
) -> @core.PdfBytes {
  let stored = pdf_flate_encode_stored_view_with_header(data, header)
  let fixed = pdf_flate_encode_fixed_literal_view_with_header(data, header)
  let mut shortest = pdf_flate_shortest(stored, fixed)
  let repeat : Result[@core.PdfBytes, Error] = try? pdf_flate_encode_fixed_repeat_view_with_header(
    data, header,
  )
  shortest = pdf_flate_shortest_result(shortest, repeat)
  let matched : Result[@core.PdfBytes, Error] = try? pdf_flate_encode_fixed_match_view_with_header(
    data, header, max_probes,
  )
  shortest = pdf_flate_shortest_result(shortest, matched)
  let dynamic : Result[@core.PdfBytes, Error] = try? pdf_flate_encode_dynamic_match_view_with_header(
    data, header, max_probes,
  )
  pdf_flate_shortest_result(shortest, dynamic)
}

///|
fn pdf_flate_encode_fast_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
  max_probes : Int,
) -> @core.PdfBytes {
  let stored = pdf_flate_encode_stored_view_with_header(data, header)
  let matched : Result[@core.PdfBytes, Error] = try? pdf_flate_encode_fixed_match_view_with_header(
    data, header, max_probes,
  )
  pdf_flate_shortest_result(stored, matched)
}

///|
fn pdf_flate_max_probes_for_level(level : Int) -> Int {
  if level <= 1 {
    8
  } else if level <= 3 {
    16
  } else if level <= 5 {
    32
  } else if level == 6 {
    64
  } else if level <= 8 {
    128
  } else {
    256
  }
}

///|
fn pdf_flate_encode_view_with_level_pure(
  data : BytesView,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  let header = pdf_flate_header_for_level(level)
  if level == 0 {
    pdf_flate_encode_stored_view_with_header(data, header)
  } else if level <= 3 {
    pdf_flate_encode_fast_view_with_header(
      data,
      header,
      pdf_flate_max_probes_for_level(level),
    )
  } else {
    pdf_flate_encode_shortest_view_with_header(
      data,
      header,
      pdf_flate_max_probes_for_level(level),
    )
  }
}

///|
fn pdf_flate_encode_view_pure(data : BytesView) -> @core.PdfBytes {
  pdf_flate_encode_shortest_view_with_header(
    data,
    pdf_flate_default_header(),
    64,
  )
}
