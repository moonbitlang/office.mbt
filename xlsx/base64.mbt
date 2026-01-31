///|
fn base64_encode(bytes : BytesView) -> String {
  @base64.encode(bytes)
}

///|
fn base64_decode(text : StringView) -> Bytes raise XlsxError {
  @base64.decode(text) catch {
    @base64.Base64Error::InvalidBase64(msg~) => raise InvalidBase64(msg~)
  }
}
