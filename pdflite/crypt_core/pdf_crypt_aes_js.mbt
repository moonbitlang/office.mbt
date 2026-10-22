///|
// The shared adapter has already checked the key, IV and block lengths.
// x/crypto's AES uses 32-bit arithmetic, avoiding JS BigInt for secret state.
fn aes_cbc_encrypt_blocks(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> Bytes raise @core.PdfError {
  pdf_aes_map_crypto_error(
    () => @crypto.aes_cbc_encrypt(key, iv, data),
    data.length(),
  )
}
