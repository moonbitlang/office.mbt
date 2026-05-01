///|
fn pdf_arc4_swap(state : Array[Int], left : Int, right : Int) -> Unit {
  let value = state[left]
  state[left] = state[right]
  state[right] = value
}

///|
pub fn pdf_arc4_crypt(
  key : BytesView,
  data : BytesView,
) -> PdfBytes raise PdfError {
  guard key.length() > 0 else { raise CryptoKeyExpected }
  let state : Array[Int] = []
  for value in 0..<256 {
    state.push(value)
  }
  let mut j = 0
  for i in 0..<256 {
    j = (j + state[i] + key[i % key.length()].to_int()) % 256
    pdf_arc4_swap(state, i, j)
  }
  let output : Array[Byte] = []
  let mut i = 0
  j = 0
  for byte in data {
    i = (i + 1) % 256
    j = (j + state[i]) % 256
    pdf_arc4_swap(state, i, j)
    let stream_byte = state[(state[i] + state[j]) % 256]
    output.push((byte.to_int() ^ stream_byte).to_byte())
  }
  Bytes::from_array(output)
}
