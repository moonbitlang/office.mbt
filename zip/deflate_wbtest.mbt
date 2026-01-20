///|
test "deflate stored block" {
  let stream : Bytes = [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x68, 0x69]
  inspect(
    deflate_decode(stream),
    content=(
      #|b"hi"
    ),
  )
}
