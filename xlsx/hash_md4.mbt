///|
fn md4_f(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x.lnot() & z)
}

///|
fn md4_g(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x & z) | (y & z)
}

///|
fn md4_h(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

///|
fn md4_ff(a : UInt, b : UInt, c : UInt, d : UInt, x : UInt, s : Int) -> UInt {
  rotl32(a + md4_f(b, c, d) + x, s)
}

///|
fn md4_gg(a : UInt, b : UInt, c : UInt, d : UInt, x : UInt, s : Int) -> UInt {
  rotl32(a + md4_g(b, c, d) + x + 0x5a82_7999, s)
}

///|
fn md4_hh(a : UInt, b : UInt, c : UInt, d : UInt, x : UInt, s : Int) -> UInt {
  rotl32(a + md4_h(b, c, d) + x + 0x6ed9_eba1, s)
}

///|
fn md4_hash(input : BytesView) -> Bytes {
  let padded = pad_message_32(input, true)
  let mut a0 : UInt = 0x6745_2301
  let mut b0 : UInt = 0xefcd_ab89
  let mut c0 : UInt = 0x98ba_dcfe
  let mut d0 : UInt = 0x1032_5476
  let mut offset = 0
  while offset < padded.length() {
    let x : Array[UInt] = Array::make(16, (0 : UInt))
    for i in 0..<=15 {
      x[i] = u32_from_le(padded, offset + i * 4)
    }
    let mut a = a0
    let mut b = b0
    let mut c = c0
    let mut d = d0
    a = md4_ff(a, b, c, d, x[0], 3)
    d = md4_ff(d, a, b, c, x[1], 7)
    c = md4_ff(c, d, a, b, x[2], 11)
    b = md4_ff(b, c, d, a, x[3], 19)
    a = md4_ff(a, b, c, d, x[4], 3)
    d = md4_ff(d, a, b, c, x[5], 7)
    c = md4_ff(c, d, a, b, x[6], 11)
    b = md4_ff(b, c, d, a, x[7], 19)
    a = md4_ff(a, b, c, d, x[8], 3)
    d = md4_ff(d, a, b, c, x[9], 7)
    c = md4_ff(c, d, a, b, x[10], 11)
    b = md4_ff(b, c, d, a, x[11], 19)
    a = md4_ff(a, b, c, d, x[12], 3)
    d = md4_ff(d, a, b, c, x[13], 7)
    c = md4_ff(c, d, a, b, x[14], 11)
    b = md4_ff(b, c, d, a, x[15], 19)
    a = md4_gg(a, b, c, d, x[0], 3)
    d = md4_gg(d, a, b, c, x[4], 5)
    c = md4_gg(c, d, a, b, x[8], 9)
    b = md4_gg(b, c, d, a, x[12], 13)
    a = md4_gg(a, b, c, d, x[1], 3)
    d = md4_gg(d, a, b, c, x[5], 5)
    c = md4_gg(c, d, a, b, x[9], 9)
    b = md4_gg(b, c, d, a, x[13], 13)
    a = md4_gg(a, b, c, d, x[2], 3)
    d = md4_gg(d, a, b, c, x[6], 5)
    c = md4_gg(c, d, a, b, x[10], 9)
    b = md4_gg(b, c, d, a, x[14], 13)
    a = md4_gg(a, b, c, d, x[3], 3)
    d = md4_gg(d, a, b, c, x[7], 5)
    c = md4_gg(c, d, a, b, x[11], 9)
    b = md4_gg(b, c, d, a, x[15], 13)
    a = md4_hh(a, b, c, d, x[0], 3)
    d = md4_hh(d, a, b, c, x[8], 9)
    c = md4_hh(c, d, a, b, x[4], 11)
    b = md4_hh(b, c, d, a, x[12], 15)
    a = md4_hh(a, b, c, d, x[2], 3)
    d = md4_hh(d, a, b, c, x[10], 9)
    c = md4_hh(c, d, a, b, x[6], 11)
    b = md4_hh(b, c, d, a, x[14], 15)
    a = md4_hh(a, b, c, d, x[1], 3)
    d = md4_hh(d, a, b, c, x[9], 9)
    c = md4_hh(c, d, a, b, x[5], 11)
    b = md4_hh(b, c, d, a, x[13], 15)
    a = md4_hh(a, b, c, d, x[3], 3)
    d = md4_hh(d, a, b, c, x[11], 9)
    c = md4_hh(c, d, a, b, x[7], 11)
    b = md4_hh(b, c, d, a, x[15], 15)
    a0 = a0 + a
    b0 = b0 + b
    c0 = c0 + c
    d0 = d0 + d
    offset = offset + 64
  }
  let out : Array[Byte] = []
  push_u32_le(out, a0)
  push_u32_le(out, b0)
  push_u32_le(out, c0)
  push_u32_le(out, d0)
  Bytes::from_array(out)
}
