///|
fn pdf_md5_rotate_left(value : UInt, bits : Int) -> UInt {
  (value << bits) | (value >> (32 - bits))
}

///|
fn pdf_md5_low_byte(value : UInt, shift : Int) -> Byte {
  ((value >> shift) & 0xff).reinterpret_as_int().to_byte()
}

///|
fn pdf_md5_word_from_message(message : ArrayView[Byte], offset : Int) -> UInt {
  message[offset].to_int().reinterpret_as_uint() |
  (message[offset + 1].to_int().reinterpret_as_uint() << 8) |
  (message[offset + 2].to_int().reinterpret_as_uint() << 16) |
  (message[offset + 3].to_int().reinterpret_as_uint() << 24)
}

///|
let pdf_md5_shifts : FixedArray[Int] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9,
  14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
]

///|
let pdf_md5_constants : FixedArray[UInt] = [
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613,
  0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193,
  0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d,
  0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122,
  0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa,
  0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244,
  0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb,
  0xeb86d391,
]

///|
/// Return the MD5 digest of `data`.
pub fn pdf_md5_digest(data : BytesView) -> @core.PdfBytes {
  let padded_length = (data.length() + 1 + 8 + 63) / 64 * 64
  let message = Array::make(padded_length, b'\x00')
  for index in 0..<data.length() {
    message[index] = data[index]
  }
  let bit_length_low = data.length().reinterpret_as_uint() << 3
  let bit_length_high = data.length().reinterpret_as_uint() >> 29
  message[data.length()] = 0x80
  let mut length_position = padded_length - 8
  for shift in [0, 8, 16, 24] {
    message[length_position] = pdf_md5_low_byte(bit_length_low, shift)
    length_position += 1
  }
  for shift in [0, 8, 16, 24] {
    message[length_position] = pdf_md5_low_byte(bit_length_high, shift)
    length_position += 1
  }
  let mut a0 : UInt = 0x67452301
  let mut b0 : UInt = 0xefcdab89
  let mut c0 : UInt = 0x98badcfe
  let mut d0 : UInt = 0x10325476
  for block in 0..<(message.length() / 64) {
    let offset = block * 64
    let words = FixedArray::make(16, 0U)
    for index in 0..<16 {
      words[index] = pdf_md5_word_from_message(message, offset + index * 4)
    }
    let mut a = a0
    let mut b = b0
    let mut c = c0
    let mut d = d0
    for index in 0..<64 {
      let (f, word_index) = if index < 16 {
        ((b & c) | (b.lnot() & d), index)
      } else if index < 32 {
        ((d & b) | (d.lnot() & c), (5 * index + 1) % 16)
      } else if index < 48 {
        (b ^ c ^ d, (3 * index + 5) % 16)
      } else {
        (c ^ (b | d.lnot()), 7 * index % 16)
      }
      let previous_d = d
      d = c
      c = b
      b += pdf_md5_rotate_left(
        a + f + pdf_md5_constants[index] + words[word_index],
        pdf_md5_shifts[index],
      )
      a = previous_d
    }
    a0 += a
    b0 += b
    c0 += c
    d0 += d
  }
  let output = Array::make(16, b'\x00')
  let mut output_position = 0
  for value in [a0, b0, c0, d0] {
    output[output_position] = pdf_md5_low_byte(value, 0)
    output[output_position + 1] = pdf_md5_low_byte(value, 8)
    output[output_position + 2] = pdf_md5_low_byte(value, 16)
    output[output_position + 3] = pdf_md5_low_byte(value, 24)
    output_position += 4
  }
  Bytes::from_array(output)
}
