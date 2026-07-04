///|
fn pdf_truetype_read_u16(data : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset > data.length() - 2 {
    None
  } else {
    Some(data[offset].to_int() * 256 + data[offset + 1].to_int())
  }
}

///|
fn pdf_truetype_read_i16(data : BytesView, offset : Int) -> Int? {
  match pdf_truetype_read_u16(data, offset) {
    Some(value) if value >= 0x8000 => Some(value - 0x10000)
    other => other
  }
}

///|
fn pdf_truetype_read_tag(data : BytesView, offset : Int) -> String? {
  if offset < 0 || offset > data.length() - 4 {
    None
  } else {
    Some(@ascii.decode_lossy(data[offset:offset + 4]))
  }
}

///|
fn pdf_truetype_read_u32(data : BytesView, offset : Int) -> UInt? {
  if offset < 0 || offset > data.length() - 4 {
    None
  } else {
    let a = data[offset].to_uint()
    let b = data[offset + 1].to_uint()
    let c = data[offset + 2].to_uint()
    let d = data[offset + 3].to_uint()
    Some((a << 24) | (b << 16) | (c << 8) | d)
  }
}

///|
fn pdf_truetype_read_u32_as_int(data : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset > data.length() - 4 {
    None
  } else {
    let value = data[offset].to_int().to_int64() * 16777216L +
      data[offset + 1].to_int().to_int64() * 65536L +
      data[offset + 2].to_int().to_int64() * 256L +
      data[offset + 3].to_int().to_int64()
    if value > 2147483647L {
      None
    } else {
      Some(value.to_int())
    }
  }
}

///|
fn pdf_truetype_normalize_u16(value : Int) -> Int {
  let mut result = value % 0x10000
  if result < 0 {
    result += 0x10000
  }
  result
}

///|
fn pdf_truetype_pdf_unit(units_per_em : Int, value : Int) -> Int {
  if units_per_em == 0 {
    0
  } else {
    (value.to_double() * 1000.0 / units_per_em.to_double()).round().to_int()
  }
}

///|
fn pdf_truetype_sorted_unique(values : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = []
  for value in values {
    output.push(value)
  }
  output.sort()
  let unique : Array[Int] = []
  for value in output {
    if unique.length() == 0 || unique[unique.length() - 1] != value {
      unique.push(value)
    }
  }
  unique
}

///|
fn pdf_truetype_table_padding(length : Int) -> Int {
  if length % 4 == 0 {
    0
  } else {
    4 - length % 4
  }
}

///|
fn pdf_truetype_write_u16_at(
  output : Array[Byte],
  position : Int,
  value : Int,
) -> Int raise @core.PdfError {
  if value < 0 || value > 0xFFFF {
    raise SoftError("TrueType unsigned 16-bit value out of range")
  }
  output[position] = @core.pdf_byte_of_int((value >> 8) & 0xFF)
  output[position + 1] = @core.pdf_byte_of_int(value & 0xFF)
  position + 2
}

///|
fn pdf_truetype_write_u32_at(
  output : Array[Byte],
  position : Int,
  value : Int,
) -> Int raise @core.PdfError {
  if value < 0 {
    raise SoftError("TrueType unsigned 32-bit value out of range")
  }
  output[position] = @core.pdf_byte_of_int((value >> 24) & 0xFF)
  output[position + 1] = @core.pdf_byte_of_int((value >> 16) & 0xFF)
  output[position + 2] = @core.pdf_byte_of_int((value >> 8) & 0xFF)
  output[position + 3] = @core.pdf_byte_of_int(value & 0xFF)
  position + 4
}

///|
fn pdf_truetype_write_u32_uint_at(
  output : Array[Byte],
  position : Int,
  value : UInt,
) -> Int raise @core.PdfError {
  output[position] = @core.pdf_byte_of_int((value >> 24).reinterpret_as_int())
  output[position + 1] = @core.pdf_byte_of_int(
    ((value >> 16) & 0xFFU).reinterpret_as_int(),
  )
  output[position + 2] = @core.pdf_byte_of_int(
    ((value >> 8) & 0xFFU).reinterpret_as_int(),
  )
  output[position + 3] = @core.pdf_byte_of_int(
    (value & 0xFFU).reinterpret_as_int(),
  )
  position + 4
}

///|
fn pdf_truetype_write_tag_at(
  output : Array[Byte],
  position : Int,
  tag : String,
) -> Int raise @core.PdfError {
  let bytes = @ascii.encode(tag)
  for index in 0..<4 {
    output[position + index] = @core.pdf_byte_of_int(
      if index < bytes.length() {
        bytes[index].to_int()
      } else {
        32
      },
    )
  }
  position + 4
}

///|
fn pdf_truetype_write_view_at(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut position = position
  for byte in bytes {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn pdf_truetype_power_two_leq(value : Int) -> Int {
  let mut current = 1
  while current * 2 <= value {
    current *= 2
  }
  current
}

///|
fn pdf_truetype_source_entry_selector(power_two : Int) -> Int {
  @math.ln(power_two.to_double()).to_int()
}
