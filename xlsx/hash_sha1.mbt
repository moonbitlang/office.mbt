///|
fn sha1_hash(input : BytesView) -> Bytes {
  let padded = pad_message_32(input, false)
  let mut h0 : UInt = 0x6745_2301
  let mut h1 : UInt = 0xefcd_ab89
  let mut h2 : UInt = 0x98ba_dcfe
  let mut h3 : UInt = 0x1032_5476
  let mut h4 : UInt = 0xc3d2_e1f0
  let mut offset = 0
  while offset < padded.length() {
    let w : Array[UInt] = Array::make(80, (0 : UInt))
    for i in 0..<=15 {
      w[i] = u32_from_be(padded, offset + i * 4)
    }
    for i in 16..<=79 {
      w[i] = rotl32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    for i in 0..<=79 {
      let (f, k) : (UInt, UInt) = if i < 20 {
        ((b & c) | (b.lnot() & d), 0x5a82_7999)
      } else if i < 40 {
        (b ^ c ^ d, 0x6ed9_eba1)
      } else if i < 60 {
        ((b & c) | (b & d) | (c & d), 0x8f1b_bcdc)
      } else {
        (b ^ c ^ d, 0xca62_c1d6)
      }
      let temp = (rotl32(a, 5) + f + e + k + w[i]) & mask_u32
      e = d
      d = c
      c = rotl32(b, 30)
      b = a
      a = temp
    }
    h0 = (h0 + a) & mask_u32
    h1 = (h1 + b) & mask_u32
    h2 = (h2 + c) & mask_u32
    h3 = (h3 + d) & mask_u32
    h4 = (h4 + e) & mask_u32
    offset = offset + 64
  }
  let out : Array[Byte] = []
  push_u32_be(out, h0)
  push_u32_be(out, h1)
  push_u32_be(out, h2)
  push_u32_be(out, h3)
  push_u32_be(out, h4)
  Bytes::from_array(out)
}
