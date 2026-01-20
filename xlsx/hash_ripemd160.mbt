///|
let ripemd_r1 : Array[Int] = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 7, 4, 13, 1, 10, 6, 15, 3,
  12, 0, 9, 5, 2, 14, 11, 8, 3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
  1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2, 4, 0, 5, 9, 7, 12, 2, 10,
  14, 1, 3, 8, 11, 6, 15, 13,
]

///|
let ripemd_r2 : Array[Int] = [
  5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12, 6, 11, 3, 7, 0, 13, 5, 10,
  14, 15, 8, 12, 4, 9, 1, 2, 15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
  8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14, 12, 15, 10, 4, 1, 5, 8, 7,
  6, 2, 13, 14, 0, 3, 9, 11,
]

///|
let ripemd_s1 : Array[Int] = [
  11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8, 7, 6, 8, 13, 11, 9, 7,
  15, 7, 12, 15, 9, 11, 7, 13, 12, 11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5,
  12, 7, 5, 11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12, 9, 15, 5, 11,
  6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6,
]

///|
let ripemd_s2 : Array[Int] = [
  8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6, 9, 13, 15, 7, 12, 8, 9,
  11, 7, 7, 12, 7, 6, 15, 13, 11, 9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13,
  7, 5, 15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8, 8, 5, 12, 9, 12,
  5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11,
]

///|
let ripemd_k1 : Array[UInt] = [
  0x0000_0000, 0x5a82_7999, 0x6ed9_eba1, 0x8f1b_bcdc, 0xa953_fd4e,
]

///|
let ripemd_k2 : Array[UInt] = [
  0x50a2_8be6, 0x5c4d_d124, 0x6d70_3ef3, 0x7a6d_76e9, 0x0000_0000,
]

///|
fn ripemd_f1(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

///|
fn ripemd_f2(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x.lnot() & z)
}

///|
fn ripemd_f3(x : UInt, y : UInt, z : UInt) -> UInt {
  (x | y.lnot()) ^ z
}

///|
fn ripemd_f4(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & z) | (y & z.lnot())
}

///|
fn ripemd_f5(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ (y | z.lnot())
}

///|
fn ripemd160_hash(input : BytesView) -> Bytes {
  let padded = pad_message_32(input, true)
  let mut h0 : UInt = 0x6745_2301
  let mut h1 : UInt = 0xefcd_ab89
  let mut h2 : UInt = 0x98ba_dcfe
  let mut h3 : UInt = 0x1032_5476
  let mut h4 : UInt = 0xc3d2_e1f0
  let mut offset = 0
  while offset < padded.length() {
    let x : Array[UInt] = Array::make(16, (0 : UInt))
    for i in 0..<=15 {
      x[i] = u32_from_le(padded, offset + i * 4)
    }
    let mut a1 = h0
    let mut b1 = h1
    let mut c1 = h2
    let mut d1 = h3
    let mut e1 = h4
    let mut a2 = h0
    let mut b2 = h1
    let mut c2 = h2
    let mut d2 = h3
    let mut e2 = h4
    for i in 0..<=79 {
      let round = i / 16
      let f1 = if i < 16 {
        ripemd_f1(b1, c1, d1)
      } else if i < 32 {
        ripemd_f2(b1, c1, d1)
      } else if i < 48 {
        ripemd_f3(b1, c1, d1)
      } else if i < 64 {
        ripemd_f4(b1, c1, d1)
      } else {
        ripemd_f5(b1, c1, d1)
      }
      let t1 = rotl32(
          a1 + f1 + x[ripemd_r1[i]] + ripemd_k1[round],
          ripemd_s1[i],
        ) +
        e1
      a1 = e1
      e1 = d1
      d1 = rotl32(c1, 10)
      c1 = b1
      b1 = t1
      let f2 = if i < 16 {
        ripemd_f5(b2, c2, d2)
      } else if i < 32 {
        ripemd_f4(b2, c2, d2)
      } else if i < 48 {
        ripemd_f3(b2, c2, d2)
      } else if i < 64 {
        ripemd_f2(b2, c2, d2)
      } else {
        ripemd_f1(b2, c2, d2)
      }
      let t2 = rotl32(
          a2 + f2 + x[ripemd_r2[i]] + ripemd_k2[round],
          ripemd_s2[i],
        ) +
        e2
      a2 = e2
      e2 = d2
      d2 = rotl32(c2, 10)
      c2 = b2
      b2 = t2
    }
    let t = h1 + c1 + d2
    h1 = h2 + d1 + e2
    h2 = h3 + e1 + a2
    h3 = h4 + a1 + b2
    h4 = h0 + b1 + c2
    h0 = t
    offset = offset + 64
  }
  let out : Array[Byte] = []
  push_u32_le(out, h0)
  push_u32_le(out, h1)
  push_u32_le(out, h2)
  push_u32_le(out, h3)
  push_u32_le(out, h4)
  Bytes::from_array(out)
}
