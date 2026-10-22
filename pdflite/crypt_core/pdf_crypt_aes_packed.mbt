///|
// Forward AES for bulk CBC. FIPS 197, sections 4 and 5:
// https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf
// Eight byte lanes share each UInt64 operation. Field arithmetic has fixed
// iteration counts and uses neither secret-indexed tables nor secret branches.
priv struct AesEncryptKey {
  words : FixedArray[UInt32]
  rounds : Int32
}

///|
fn aes_packed_xtime(bytes : UInt64) -> UInt64 {
  ((bytes & 0x7f7f7f7f7f7f7f7fUL) << 1) ^
  (((bytes >> 7) & 0x0101010101010101UL) * 0x1bUL)
}

///|
fn aes_packed_multiply(left : UInt64, right : UInt64) -> UInt64 {
  for bit = 0, product = 0UL, left = left, right = right; bit < 8; {
    let mask = (right & 0x0101010101010101UL) * 0xffUL
    continue bit + 1,
      product ^ (left & mask),
      aes_packed_xtime(left),
      (right >> 1) & 0x7f7f7f7f7f7f7f7fUL
  } nobreak {
    product
  }
}

///|
// Squaring is linear over GF(2). These are the squares of the eight basis
// bits, reduced modulo x^8 + x^4 + x^3 + x + 1.
fn aes_packed_square(bytes : UInt64) -> UInt64 {
  (bytes & 0x0101010101010101UL) ^
  ((bytes & 0x0202020202020202UL) << 1) ^
  ((bytes & 0x0404040404040404UL) << 2) ^
  ((bytes & 0x0808080808080808UL) << 3) ^
  (((bytes >> 4) & 0x0101010101010101UL) * 0x1bUL) ^
  (((bytes >> 5) & 0x0101010101010101UL) * 0x6cUL) ^
  (((bytes >> 6) & 0x0101010101010101UL) * 0xabUL) ^
  (((bytes >> 7) & 0x0101010101010101UL) * 0x9aUL)
}

///|
fn aes_packed_sub_bytes(bytes : UInt64) -> UInt64 {
  // x^254 is the multiplicative inverse (and maps zero to zero). This
  // addition chain uses four general products and seven linear squares.
  let x2 = aes_packed_square(bytes)
  let x3 = aes_packed_multiply(x2, bytes)
  let x6 = aes_packed_square(x3)
  let x12 = aes_packed_square(x6)
  let x15 = aes_packed_multiply(x12, x3)
  let x30 = aes_packed_square(x15)
  let x60 = aes_packed_square(x30)
  let x120 = aes_packed_square(x60)
  let x240 = aes_packed_square(x120)
  let x252 = aes_packed_multiply(x240, x12)
  let inverse = aes_packed_multiply(x252, x2)
  // The affine transform rotates within each byte, never across lanes.
  inverse ^
  (
    ((inverse << 1) & 0xfefefefefefefefeUL) |
    ((inverse >> 7) & 0x0101010101010101UL)
  ) ^
  (
    ((inverse << 2) & 0xfcfcfcfcfcfcfcfcUL) |
    ((inverse >> 6) & 0x0303030303030303UL)
  ) ^
  (
    ((inverse << 3) & 0xf8f8f8f8f8f8f8f8UL) |
    ((inverse >> 5) & 0x0707070707070707UL)
  ) ^
  (
    ((inverse << 4) & 0xf0f0f0f0f0f0f0f0UL) |
    ((inverse >> 4) & 0x0f0f0f0f0f0f0f0fUL)
  ) ^
  0x6363636363636363UL
}

///|
fn aes_read_word(bytes : BytesView, offset : Int32) -> UInt32 {
  (bytes[offset].to_uint() << 24) |
  (bytes[offset + 1].to_uint() << 16) |
  (bytes[offset + 2].to_uint() << 8) |
  bytes[offset + 3].to_uint()
}

///|
fn AesEncryptKey::new(key : BytesView) -> AesEncryptKey {
  let key_words = key.length() / 4
  let rounds = key_words + 6
  let words = FixedArray::make(4 * (rounds + 1), 0U)
  for index in 0..<key_words {
    words[index] = aes_read_word(key, index * 4)
  }
  let mut rcon = 1U
  for index in key_words..<words.length() {
    let mut word = words[index - 1]
    if index % key_words == 0 {
      word = (word << 8) | (word >> 24)
      word = aes_packed_sub_bytes(UInt64::extend_uint(word)).to_uint() ^
        (rcon << 24)
      rcon = ((rcon << 1) ^ ((0U - (rcon >> 7)) & 0x1bU)) & 0xffU
    } else if key_words == 8 && index % key_words == 4 {
      word = aes_packed_sub_bytes(UInt64::extend_uint(word)).to_uint()
    }
    words[index] = words[index - key_words] ^ word
  }
  { words, rounds, }
}

///|
fn aes_mix_word(word : UInt32) -> UInt32 {
  let pairs = word ^ ((word << 16) | (word >> 16))
  let total = pairs ^ ((pairs << 8) | (pairs >> 24))
  let adjacent = word ^ ((word << 8) | (word >> 24))
  let doubled = ((adjacent & 0x7f7f7f7fU) << 1) ^
    (((adjacent >> 7) & 0x01010101U) * 0x1bU)
  word ^ total ^ doubled
}

///|
fn AesEncryptKey::encrypt(
  schedule : AesEncryptKey,
  state : FixedArray[UInt32],
) -> Unit {
  for column in 0..<4 {
    state[column] = state[column] ^ schedule.words[column]
  }
  for round = 1; round <= schedule.rounds; round = round + 1 {
    let first_pair = aes_packed_sub_bytes(
      (UInt64::extend_uint(state[0]) << 32) | UInt64::extend_uint(state[1]),
    )
    let second_pair = aes_packed_sub_bytes(
      (UInt64::extend_uint(state[2]) << 32) | UInt64::extend_uint(state[3]),
    )
    let column_0 = (first_pair >> 32).to_uint()
    let column_1 = first_pair.to_uint()
    let column_2 = (second_pair >> 32).to_uint()
    let column_3 = second_pair.to_uint()
    // ShiftRows in the column-major state layout specified by FIPS 197.
    state[0] = (column_0 & 0xff000000U) |
      (column_1 & 0x00ff0000U) |
      (column_2 & 0x0000ff00U) |
      (column_3 & 0x000000ffU)
    state[1] = (column_1 & 0xff000000U) |
      (column_2 & 0x00ff0000U) |
      (column_3 & 0x0000ff00U) |
      (column_0 & 0x000000ffU)
    state[2] = (column_2 & 0xff000000U) |
      (column_3 & 0x00ff0000U) |
      (column_0 & 0x0000ff00U) |
      (column_1 & 0x000000ffU)
    state[3] = (column_3 & 0xff000000U) |
      (column_0 & 0x00ff0000U) |
      (column_1 & 0x0000ff00U) |
      (column_2 & 0x000000ffU)
    for column in 0..<4 {
      let word = if round < schedule.rounds {
        aes_mix_word(state[column])
      } else {
        state[column]
      }
      state[column] = word ^ schedule.words[round * 4 + column]
    }
  }
}

///|
// The public adapter checks key/IV lengths and block alignment before entry.
fn aes_cbc_encrypt_blocks(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> Bytes {
  let schedule = AesEncryptKey::new(key)
  let state = FixedArray::makei(4, column => aes_read_word(iv, column * 4))
  let output = Array::make(data.length(), b'\x00')
  for offset = 0; offset < data.length(); offset = offset + 16 {
    for column in 0..<4 {
      state[column] = state[column] ^ aes_read_word(data, offset + column * 4)
    }
    schedule.encrypt(state)
    for column in 0..<4 {
      let word = state[column]
      let start = offset + column * 4
      output[start] = (word >> 24).to_byte()
      output[start + 1] = (word >> 16).to_byte()
      output[start + 2] = (word >> 8).to_byte()
      output[start + 3] = word.to_byte()
    }
  }
  Bytes::from_array(output)
}
