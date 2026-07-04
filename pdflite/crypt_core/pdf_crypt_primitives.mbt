///|
fn pdf_crypto_low_byte(value : Int, shift : Int) -> Byte {
  ((value >> shift) & 0xff).to_byte()
}

///|
fn pdf_arc4_swap(state : Array[Int], left : Int, right : Int) -> Unit {
  let value = state[left]
  state[left] = state[right]
  state[right] = value
}

///|
/// Apply ARC4 to `data` with `key`.
///
/// ARC4 is symmetric, so the same function encrypts and decrypts. Empty keys
/// raise `@core.PdfError::CryptoKeyExpected`.
pub fn pdf_arc4_crypt(
  key : BytesView,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  guard key.length() > 0 else { raise CryptoKeyExpected }
  let state = Array::make(256, 0)
  for value in 0..<256 {
    state[value] = value
  }
  let mut j = 0
  for i in 0..<256 {
    j = (j + state[i] + key[i % key.length()].to_int()) % 256
    pdf_arc4_swap(state, i, j)
  }
  let output = Array::make(data.length(), b'\x00')
  let mut i = 0
  j = 0
  let mut output_position = 0
  for byte in data {
    i = (i + 1) % 256
    j = (j + state[i]) % 256
    pdf_arc4_swap(state, i, j)
    let stream_byte = state[(state[i] + state[j]) % 256]
    output[output_position] = (byte.to_int() ^ stream_byte).to_byte()
    output_position += 1
  }
  Bytes::from_array(output)
}
