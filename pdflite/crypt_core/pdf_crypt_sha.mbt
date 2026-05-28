///|
/// Return the SHA-256 digest of `data`.
pub fn pdf_sha256_digest(data : BytesView) -> @core.PdfBytes {
  Bytes::from_array(@crypto.sha256(data))
}

///|
let pdf_sha512_k : Array[UInt64] = [
  0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
  0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
  0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
  0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
  0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
  0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
  0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
  0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
  0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
  0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
  0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
  0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
  0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
  0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
  0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
  0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
  0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
  0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
  0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
  0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817,
]

///|
fn pdf_sha512_rotr(value : UInt64, bits : Int) -> UInt64 {
  (value >> bits) | (value << (64 - bits))
}

///|
fn pdf_sha512_small_sigma0(value : UInt64) -> UInt64 {
  pdf_sha512_rotr(value, 1) ^ pdf_sha512_rotr(value, 8) ^ (value >> 7)
}

///|
fn pdf_sha512_small_sigma1(value : UInt64) -> UInt64 {
  pdf_sha512_rotr(value, 19) ^ pdf_sha512_rotr(value, 61) ^ (value >> 6)
}

///|
fn pdf_sha512_big_sigma0(value : UInt64) -> UInt64 {
  pdf_sha512_rotr(value, 28) ^
  pdf_sha512_rotr(value, 34) ^
  pdf_sha512_rotr(value, 39)
}

///|
fn pdf_sha512_big_sigma1(value : UInt64) -> UInt64 {
  pdf_sha512_rotr(value, 14) ^
  pdf_sha512_rotr(value, 18) ^
  pdf_sha512_rotr(value, 41)
}

///|
fn pdf_sha512_u64_from_be(data : BytesView, offset : Int) -> UInt64 {
  let mut value : UInt64 = 0
  for index in 0..<8 {
    value = (value << 8) | data[offset + index].to_uint64()
  }
  value
}

///|
fn pdf_sha512_write_u64_be(
  output : Array[Byte],
  position : Int,
  value : UInt64,
) -> Unit {
  let mut offset = position
  for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
    output[offset] = ((value >> shift) & 0xff).to_byte()
    offset += 1
  }
}

///|
fn pdf_sha512_padded(data : BytesView) -> @core.PdfBytes {
  let bit_length = data.length().to_uint64() * 8
  let padded_length = (data.length() + 1 + 16 + 127) / 128 * 128
  let output = Array::make(padded_length, b'\x00')
  for index in 0..<data.length() {
    output[index] = data[index]
  }
  output[data.length()] = 0x80
  pdf_sha512_write_u64_be(output, padded_length - 8, bit_length)
  Bytes::from_array(output)
}

///|
fn pdf_sha512_process_block(block : BytesView, state : Array[UInt64]) -> Unit {
  let words : Array[UInt64] = Array::make(80, 0)
  for index in 0..<16 {
    words[index] = pdf_sha512_u64_from_be(block, index * 8)
  }
  for index in 16..<80 {
    words[index] = pdf_sha512_small_sigma1(words[index - 2]) +
      words[index - 7] +
      pdf_sha512_small_sigma0(words[index - 15]) +
      words[index - 16]
  }
  let mut a = state[0]
  let mut b = state[1]
  let mut c = state[2]
  let mut d = state[3]
  let mut e = state[4]
  let mut f = state[5]
  let mut g = state[6]
  let mut h = state[7]
  for index in 0..<80 {
    let choice = (e & f) ^ (e.lnot() & g)
    let majority = (a & b) ^ (a & c) ^ (b & c)
    let temp1 = h +
      pdf_sha512_big_sigma1(e) +
      choice +
      pdf_sha512_k[index] +
      words[index]
    let temp2 = pdf_sha512_big_sigma0(a) + majority
    h = g
    g = f
    f = e
    e = d + temp1
    d = c
    c = b
    b = a
    a = temp1 + temp2
  }
  state[0] = state[0] + a
  state[1] = state[1] + b
  state[2] = state[2] + c
  state[3] = state[3] + d
  state[4] = state[4] + e
  state[5] = state[5] + f
  state[6] = state[6] + g
  state[7] = state[7] + h
}

///|
fn pdf_sha512_digest_with_state(
  data : BytesView,
  state : Array[UInt64],
  output_words : Int,
) -> @core.PdfBytes {
  let padded = pdf_sha512_padded(data)
  let mut offset = 0
  while offset < padded.length() {
    pdf_sha512_process_block(padded[offset:offset + 128], state)
    offset += 128
  }
  let output = Array::make(output_words * 8, b'\x00')
  for index in 0..<output_words {
    pdf_sha512_write_u64_be(output, index * 8, state[index])
  }
  Bytes::from_array(output)
}

///|
/// Return the SHA-384 digest of `data`.
pub fn pdf_sha384_digest(data : BytesView) -> @core.PdfBytes {
  pdf_sha512_digest_with_state(
    data,
    [
      0xcbbb9d5dc1059ed8, 0x629a292a367cd507, 0x9159015a3070dd17, 0x152fecd8f70e5939,
      0x67332667ffc00b31, 0x8eb44a8768581511, 0xdb0c2e0d64f98fa7, 0x47b5481dbefa4fa4,
    ],
    6,
  )
}

///|
/// Return the SHA-512 digest of `data`.
pub fn pdf_sha512_digest(data : BytesView) -> @core.PdfBytes {
  pdf_sha512_digest_with_state(
    data,
    [
      0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
      0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
    ],
    8,
  )
}
