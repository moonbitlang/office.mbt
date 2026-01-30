///|
let sha256_k : Array[UInt] = [
  0x428a_2f98, 0x7137_4491, 0xb5c0_fbcf, 0xe9b5_dba5, 0x3956_c25b, 0x59f1_11f1, 0x923f_82a4,
  0xab1c_5ed5, 0xd807_aa98, 0x1283_5b01, 0x2431_85be, 0x550c_7dc3, 0x72be_5d74, 0x80de_b1fe,
  0x9bdc_06a7, 0xc19b_f174, 0xe49b_69c1, 0xefbe_4786, 0x0fc1_9dc6, 0x240c_a1cc, 0x2de9_2c6f,
  0x4a74_84aa, 0x5cb0_a9dc, 0x76f9_88da, 0x983e_5152, 0xa831_c66d, 0xb003_27c8, 0xbf59_7fc7,
  0xc6e0_0bf3, 0xd5a7_9147, 0x06ca_6351, 0x1429_2967, 0x27b7_0a85, 0x2e1b_2138, 0x4d2c_6dfc,
  0x5338_0d13, 0x650a_7354, 0x766a_0abb, 0x81c2_c92e, 0x9272_2c85, 0xa2bf_e8a1, 0xa81a_664b,
  0xc24b_8b70, 0xc76c_51a3, 0xd192_e819, 0xd699_0624, 0xf40e_3585, 0x106a_a070, 0x19a4_c116,
  0x1e37_6c08, 0x2748_774c, 0x34b0_bcb5, 0x391c_0cb3, 0x4ed8_aa4a, 0x5b9c_ca4f, 0x682e_6ff3,
  0x748f_82ee, 0x78a5_636f, 0x84c8_7814, 0x8cc7_0208, 0x90be_fffa, 0xa450_6ceb, 0xbef9_a3f7,
  0xc671_78f2,
]

///|
fn sha256_small_sigma0(x : UInt) -> UInt {
  rotr32(x, 7) ^ rotr32(x, 18) ^ (x >> 3)
}

///|
fn sha256_small_sigma1(x : UInt) -> UInt {
  rotr32(x, 17) ^ rotr32(x, 19) ^ (x >> 10)
}

///|
fn sha256_big_sigma0(x : UInt) -> UInt {
  rotr32(x, 2) ^ rotr32(x, 13) ^ rotr32(x, 22)
}

///|
fn sha256_big_sigma1(x : UInt) -> UInt {
  rotr32(x, 6) ^ rotr32(x, 11) ^ rotr32(x, 25)
}

///|
fn sha256_hash(input : BytesView) -> Bytes {
  let padded = pad_message_32(input, false)
  let mut h0 : UInt = 0x6a09_e667
  let mut h1 : UInt = 0xbb67_ae85
  let mut h2 : UInt = 0x3c6e_f372
  let mut h3 : UInt = 0xa54f_f53a
  let mut h4 : UInt = 0x510e_527f
  let mut h5 : UInt = 0x9b05_688c
  let mut h6 : UInt = 0x1f83_d9ab
  let mut h7 : UInt = 0x5be0_cd19
  let mut offset = 0
  while offset < padded.length() {
    let w : Array[UInt] = Array::make(64, (0 : UInt))
    for i in 0..<=15 {
      w[i] = u32_from_be(padded, offset + i * 4)
    }
    for i in 16..<=63 {
      w[i] = sha256_small_sigma1(w[i - 2]) +
        w[i - 7] +
        sha256_small_sigma0(w[i - 15]) +
        w[i - 16]
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    let mut f = h5
    let mut g = h6
    let mut h = h7
    for i in 0..<=63 {
      let ch = (e & f) ^ (e.lnot() & g)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let t1 = h + sha256_big_sigma1(e) + ch + sha256_k[i] + w[i]
      let t2 = sha256_big_sigma0(a) + maj
      h = g
      g = f
      f = e
      e = d + t1
      d = c
      c = b
      b = a
      a = t1 + t2
    }
    h0 = h0 + a
    h1 = h1 + b
    h2 = h2 + c
    h3 = h3 + d
    h4 = h4 + e
    h5 = h5 + f
    h6 = h6 + g
    h7 = h7 + h
    offset = offset + 64
  }
  let out : Array[Byte] = []
  push_u32_be(out, h0)
  push_u32_be(out, h1)
  push_u32_be(out, h2)
  push_u32_be(out, h3)
  push_u32_be(out, h4)
  push_u32_be(out, h5)
  push_u32_be(out, h6)
  push_u32_be(out, h7)
  Bytes::from_array(out)
}
