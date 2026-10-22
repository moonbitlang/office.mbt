///|
// Deliberately scalar reference for the packed field operations.
#cfg(not(target="js"))
fn aes_reference_multiply(left : Int32, right : Int32) -> Int32 {
  for bit = 0, product = 0, left = left, right = right; bit < 8; {
    let product = if (right & 1) != 0 { product ^ left } else { product }
    let left = ((left << 1) ^ (if (left & 0x80) != 0 { 0x11b } else { 0 })) &
      0xff
    continue bit + 1, product, left, right >> 1
  } nobreak {
    product
  }
}

///|
#cfg(not(target="js"))
test "packed AES S-box matches scalar field inversion in every byte lane" {
  for value in 0..<256 {
    let bytes = Bytes::makei(8, lane => ((value + lane * 37) % 256).to_byte())
    let mut packed = 0UL
    for lane in 0..<8 {
      packed = packed |
        (UInt64::extend_uint(bytes[lane].to_uint()) << (lane * 8))
    }
    let actual = aes_packed_sub_bytes(packed)
    for lane in 0..<8 {
      let byte = bytes[lane].to_int()
      let inverse = for exponent = 0, power = 1; exponent < 254; {
        continue exponent + 1, aes_reference_multiply(power, byte)
      } nobreak {
        power
      }
      let expected = (
          inverse ^
          ((inverse << 1) | (inverse >> 7)) ^
          ((inverse << 2) | (inverse >> 6)) ^
          ((inverse << 3) | (inverse >> 5)) ^
          ((inverse << 4) | (inverse >> 4)) ^
          0x63
        ) &
        0xff
      @test.assert_eq(((actual >> (lane * 8)) & 0xffUL).to_int(), expected)
    }
  }
}

///|
test "packed CBC agrees with x crypto for every AES key size and block chaining" {
  for key_length in [16, 24, 32] {
    for seed in 0..<4 {
      let key = Bytes::makei(key_length, index => {
        (index * 37 + seed * 53).to_byte()
      })
      let iv = Bytes::makei(16, index => (index * 19 + seed * 71).to_byte())
      for length in [0, 16, 48, 256] {
        let data = Bytes::makei(length, index => {
          (index * 131 + seed * 97).to_byte()
        })
        @test.assert_eq(
          pdf_aes_cbc_encrypt_no_padding_with_iv(key, iv, data),
          @crypto.aes_cbc_encrypt(key, iv, data),
        )
      }
    }
  }
}
