///|
priv struct AesSchedule {
  round_keys : Array[Byte]
  rounds : Int
  sbox : Array[Byte]
  inv_sbox : Array[Byte]
}

///|
fn gf_mul(a : Int, b : Int) -> Int {
  let mut x = a & 0xff
  let mut y = b & 0xff
  let mut res = 0
  for _ in 0..<=7 {
    if (y & 1) != 0 {
      res = res ^ x
    }
    let hi = x & 0x80
    x = (x << 1) & 0xff
    if hi != 0 {
      x = x ^ 0x1b
    }
    y = y >> 1
  }
  res & 0xff
}

///|
fn gf_pow(x : Int, exp : Int) -> Int {
  let mut result = 1
  let mut base = x & 0xff
  let mut e = exp
  while e > 0 {
    if (e & 1) != 0 {
      result = gf_mul(result, base)
    }
    base = gf_mul(base, base)
    e = e >> 1
  }
  result & 0xff
}

///|
fn rotl8(x : Int, bits : Int) -> Int {
  ((x << bits) | (x >> (8 - bits))) & 0xff
}

///|
fn aes_tables() -> (Array[Byte], Array[Byte]) {
  let sbox : Array[Byte] = Array::make(256, (0).to_byte())
  let inv_sbox : Array[Byte] = Array::make(256, (0).to_byte())
  for i in 0..<=255 {
    let inv = if i == 0 { 0 } else { gf_pow(i, 254) }
    let mut s = inv
    s = s ^ rotl8(inv, 1) ^ rotl8(inv, 2) ^ rotl8(inv, 3) ^ rotl8(inv, 4) ^ 0x63
    s = s & 0xff
    sbox[i] = s.to_byte()
    inv_sbox[s] = i.to_byte()
  }
  (sbox, inv_sbox)
}

///|
fn aes_rcon() -> Array[UInt] {
  let rcon : Array[UInt] = []
  let mut value = 1
  for _ in 0..<=13 {
    rcon.push(value.reinterpret_as_uint() << 24)
    value = gf_mul(value, 2)
  }
  rcon
}

///|
fn aes_sub_word(word : UInt, sbox : Array[Byte]) -> UInt {
  let b0 = sbox[((word >> 24) & 0xff).to_uint64().to_int()].to_uint()
  let b1 = sbox[((word >> 16) & 0xff).to_uint64().to_int()].to_uint()
  let b2 = sbox[((word >> 8) & 0xff).to_uint64().to_int()].to_uint()
  let b3 = sbox[(word & 0xff).to_uint64().to_int()].to_uint()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
fn aes_rot_word(word : UInt) -> UInt {
  (word << 8) | (word >> 24)
}

///|
fn aes_schedule(key : BytesView) -> AesSchedule raise CryptoError {
  let (sbox, inv_sbox) = aes_tables()
  let key_len = key.length()
  if key_len != 16 && key_len != 24 && key_len != 32 {
    raise InvalidCrypto(msg="invalid AES key size")
  }
  let nk = key_len / 4
  let rounds = nk + 6
  let total_words = 4 * (rounds + 1)
  let w : Array[UInt] = Array::make(total_words, (0 : UInt))
  for i in 0..<nk {
    w[i] = u32_from_be(key, i * 4)
  }
  let rcon = aes_rcon()
  for i in nk..<total_words {
    let mut temp = w[i - 1]
    if i % nk == 0 {
      temp = aes_sub_word(aes_rot_word(temp), sbox) ^ rcon[i / nk - 1]
    } else if nk > 6 && i % nk == 4 {
      temp = aes_sub_word(temp, sbox)
    }
    w[i] = w[i - nk] ^ temp
  }
  let round_keys : Array[Byte] = []
  for word in w {
    round_keys.push(((word >> 24) & 0xff).to_uint64().to_byte())
    round_keys.push(((word >> 16) & 0xff).to_uint64().to_byte())
    round_keys.push(((word >> 8) & 0xff).to_uint64().to_byte())
    round_keys.push((word & 0xff).to_uint64().to_byte())
  }
  { round_keys, rounds, sbox, inv_sbox }
}

///|
fn byte_xor(a : Byte, b : Byte) -> Byte {
  (a.to_int() ^ b.to_int()).to_byte()
}

///|
fn aes_add_round_key(
  state : Array[Byte],
  round_keys : Array[Byte],
  round : Int,
) -> Unit {
  let offset = round * 16
  for i in 0..<=15 {
    state[i] = byte_xor(state[i], round_keys[offset + i])
  }
}

///|
fn aes_sub_bytes(state : Array[Byte], sbox : Array[Byte]) -> Unit {
  for i in 0..<=15 {
    state[i] = sbox[state[i].to_int()]
  }
}

///|
fn aes_inv_sub_bytes(state : Array[Byte], inv_sbox : Array[Byte]) -> Unit {
  for i in 0..<=15 {
    state[i] = inv_sbox[state[i].to_int()]
  }
}

///|
fn aes_shift_rows(state : Array[Byte]) -> Unit {
  let tmp = state.copy()
  state[0] = tmp[0]
  state[4] = tmp[4]
  state[8] = tmp[8]
  state[12] = tmp[12]
  state[1] = tmp[5]
  state[5] = tmp[9]
  state[9] = tmp[13]
  state[13] = tmp[1]
  state[2] = tmp[10]
  state[6] = tmp[14]
  state[10] = tmp[2]
  state[14] = tmp[6]
  state[3] = tmp[15]
  state[7] = tmp[3]
  state[11] = tmp[7]
  state[15] = tmp[11]
}

///|
fn aes_inv_shift_rows(state : Array[Byte]) -> Unit {
  let tmp = state.copy()
  state[0] = tmp[0]
  state[4] = tmp[4]
  state[8] = tmp[8]
  state[12] = tmp[12]
  state[1] = tmp[13]
  state[5] = tmp[1]
  state[9] = tmp[5]
  state[13] = tmp[9]
  state[2] = tmp[10]
  state[6] = tmp[14]
  state[10] = tmp[2]
  state[14] = tmp[6]
  state[3] = tmp[7]
  state[7] = tmp[11]
  state[11] = tmp[15]
  state[15] = tmp[3]
}

///|
fn mul_byte(value : Byte, factor : Int) -> Byte {
  gf_mul(value.to_int(), factor).to_byte()
}

///|
fn aes_mix_columns(state : Array[Byte]) -> Unit {
  for col in 0..<=3 {
    let i = col * 4
    let s0 = state[i]
    let s1 = state[i + 1]
    let s2 = state[i + 2]
    let s3 = state[i + 3]
    state[i] = byte_xor(
      byte_xor(mul_byte(s0, 2), mul_byte(s1, 3)),
      byte_xor(s2, s3),
    )
    state[i + 1] = byte_xor(
      byte_xor(s0, mul_byte(s1, 2)),
      byte_xor(mul_byte(s2, 3), s3),
    )
    state[i + 2] = byte_xor(
      byte_xor(s0, s1),
      byte_xor(mul_byte(s2, 2), mul_byte(s3, 3)),
    )
    state[i + 3] = byte_xor(
      byte_xor(mul_byte(s0, 3), s1),
      byte_xor(s2, mul_byte(s3, 2)),
    )
  }
}

///|
fn aes_inv_mix_columns(state : Array[Byte]) -> Unit {
  for col in 0..<=3 {
    let i = col * 4
    let s0 = state[i]
    let s1 = state[i + 1]
    let s2 = state[i + 2]
    let s3 = state[i + 3]
    state[i] = byte_xor(
      byte_xor(mul_byte(s0, 14), mul_byte(s1, 11)),
      byte_xor(mul_byte(s2, 13), mul_byte(s3, 9)),
    )
    state[i + 1] = byte_xor(
      byte_xor(mul_byte(s0, 9), mul_byte(s1, 14)),
      byte_xor(mul_byte(s2, 11), mul_byte(s3, 13)),
    )
    state[i + 2] = byte_xor(
      byte_xor(mul_byte(s0, 13), mul_byte(s1, 9)),
      byte_xor(mul_byte(s2, 14), mul_byte(s3, 11)),
    )
    state[i + 3] = byte_xor(
      byte_xor(mul_byte(s0, 11), mul_byte(s1, 13)),
      byte_xor(mul_byte(s2, 9), mul_byte(s3, 14)),
    )
  }
}

///|
fn aes_encrypt_state(schedule : AesSchedule, state : Array[Byte]) -> Unit {
  aes_add_round_key(state, schedule.round_keys, 0)
  for round in 1..<schedule.rounds {
    aes_sub_bytes(state, schedule.sbox)
    aes_shift_rows(state)
    aes_mix_columns(state)
    aes_add_round_key(state, schedule.round_keys, round)
  }
  aes_sub_bytes(state, schedule.sbox)
  aes_shift_rows(state)
  aes_add_round_key(state, schedule.round_keys, schedule.rounds)
}

///|
fn aes_encrypt_block(
  schedule : AesSchedule,
  block : BytesView,
) -> Array[Byte] raise CryptoError {
  if block.length() != 16 {
    raise InvalidCrypto(msg="invalid AES block size")
  }
  let state = block.to_array()
  aes_encrypt_state(schedule, state)
  state
}

///|
fn aes_decrypt_state(schedule : AesSchedule, state : Array[Byte]) -> Unit {
  aes_add_round_key(state, schedule.round_keys, schedule.rounds)
  let mut round = schedule.rounds - 1
  while round > 0 {
    aes_inv_shift_rows(state)
    aes_inv_sub_bytes(state, schedule.inv_sbox)
    aes_add_round_key(state, schedule.round_keys, round)
    aes_inv_mix_columns(state)
    round = round - 1
  }
  aes_inv_shift_rows(state)
  aes_inv_sub_bytes(state, schedule.inv_sbox)
  aes_add_round_key(state, schedule.round_keys, 0)
}

///|
fn aes_decrypt_block(
  schedule : AesSchedule,
  block : BytesView,
) -> Array[Byte] raise CryptoError {
  if block.length() != 16 {
    raise InvalidCrypto(msg="invalid AES block size")
  }
  let state = block.to_array()
  aes_decrypt_state(schedule, state)
  state
}

///|
pub fn aes_ecb_encrypt(
  key : BytesView,
  data : BytesView,
) -> Bytes raise CryptoError {
  if data.length() % 16 != 0 {
    raise InvalidCrypto(msg="invalid AES data length")
  }
  let schedule = aes_schedule(key)
  let out : Array[Byte] = Array::new(capacity=data.length())
  let mut offset = 0
  while offset < data.length() {
    let block = data[offset:offset + 16]
    let enc = aes_encrypt_block(schedule, block)
    out.append(enc[:])
    offset = offset + 16
  }
  Bytes::from_array(out)
}

///|
pub fn aes_ecb_decrypt(
  key : BytesView,
  data : BytesView,
) -> Bytes raise CryptoError {
  if data.length() % 16 != 0 {
    raise InvalidCrypto(msg="invalid AES data length")
  }
  let schedule = aes_schedule(key)
  let out : Array[Byte] = Array::new(capacity=data.length())
  let mut offset = 0
  while offset < data.length() {
    let block = data[offset:offset + 16]
    let dec = aes_decrypt_block(schedule, block)
    out.append(dec[:])
    offset = offset + 16
  }
  Bytes::from_array(out)
}

///|
pub fn aes_cbc_decrypt(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> Bytes raise CryptoError {
  if iv.length() != 16 {
    raise InvalidCrypto(msg="invalid AES IV length")
  }
  if data.length() % 16 != 0 {
    raise InvalidCrypto(msg="invalid AES data length")
  }
  let schedule = aes_schedule(key)
  let out : Array[Byte] = Array::new(capacity=data.length())
  let mut prev = iv
  let mut offset = 0
  while offset < data.length() {
    let block = data[offset:offset + 16]
    let dec = aes_decrypt_block(schedule, block)
    for i in 0..<=15 {
      dec[i] = byte_xor(dec[i], prev[i])
    }
    out.append(dec[:])
    prev = block
    offset = offset + 16
  }
  Bytes::from_array(out)
}

///|
pub fn aes_cbc_encrypt(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> Bytes raise CryptoError {
  if iv.length() != 16 {
    raise InvalidCrypto(msg="invalid AES IV length")
  }
  if data.length() % 16 != 0 {
    raise InvalidCrypto(msg="invalid AES data length")
  }
  let schedule = aes_schedule(key)
  let out : Array[Byte] = Array::new(capacity=data.length())
  let mut prev = iv.to_array()
  let mut offset = 0
  while offset < data.length() {
    let block = data[offset:offset + 16]
    let mixed : Array[Byte] = Array::make(16, (0).to_byte())
    for i in 0..<=15 {
      mixed[i] = byte_xor(block[i], prev[i])
    }
    aes_encrypt_state(schedule, mixed)
    out.append(mixed[:])
    prev = mixed
    offset = offset + 16
  }
  Bytes::from_array(out)
}
