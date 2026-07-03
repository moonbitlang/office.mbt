///|
test "builtin charset decode: Windows-1252 / Latin-1 / ASCII fold together" {
  // Windows-1252: 0x80 -> €, 0x92 -> ' (right single quote), 0x99 -> ™
  debug_inspect(
    builtin_charset_decode("windows-1252", b"\x80\x92\x99"),
    content=(
      #|Some("€’™")
    ),
  )
  // ISO-8859-1 and US-ASCII labels resolve to the same Windows-1252
  // decoder (WHATWG/Go behavior): 0xE9 -> é for all of them
  debug_inspect(
    builtin_charset_decode("ISO-8859-1", b"caf\xe9"),
    content=(
      #|Some("café")
    ),
  )
  debug_inspect(
    builtin_charset_decode("latin1", b"caf\xe9"),
    content=(
      #|Some("café")
    ),
  )
  // ASCII text is unchanged; a high byte decodes as CP1252, not rejected
  debug_inspect(
    builtin_charset_decode("us-ascii", b"hello"),
    content=(
      #|Some("hello")
    ),
  )
  debug_inspect(
    builtin_charset_decode("ascii", b"caf\xe9"),
    content=(
      #|Some("café")
    ),
  )
  // an undefined Windows-1252 slot (0x81) passes through as its C1 control
  guard builtin_charset_decode("cp1252", b"\x81") is Some(s)
  inspect(s.get_char(0).unwrap().to_int(), content="129")
}

///|
test "builtin charset decode: UTF-16 label endianness and BOM" {
  // plain utf-16 defaults to little-endian (WHATWG)
  debug_inspect(
    builtin_charset_decode("utf-16", b"h\x00i\x00"),
    content=(
      #|Some("hi")
    ),
  )
  // explicit big-endian, no BOM
  debug_inspect(
    builtin_charset_decode("utf-16be", b"\x00h\x00i"),
    content=(
      #|Some("hi")
    ),
  )
  // a BOM overrides the label default and is stripped
  debug_inspect(
    builtin_charset_decode("utf-16le", b"\xfe\xff\x00h\x00i"),
    content=(
      #|Some("hi")
    ),
  )
  // unicodefffe is UTF-16BE despite the FFFE-looking name (WHATWG)
  debug_inspect(
    builtin_charset_decode("unicodeFFFE", b"\x00h\x00i"),
    content=(
      #|Some("hi")
    ),
  )
}

///|
test "builtin charset decode returns None for unsupported encodings" {
  inspect(builtin_charset_decode("Shift_JIS", b"abc") is None, content="true")
  inspect(builtin_charset_decode("gbk", b"abc") is None, content="true")
  inspect(builtin_charset_decode("euc-kr", b"abc") is None, content="true")
  inspect(builtin_charset_decode("big5", b"abc") is None, content="true")
}

///|
test "decode_utf8 applies builtin charset without a transcoder" {
  // Latin-1 declaration, é as 0xE9, no transcoder supplied
  let xml = b"<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a>caf\xe9</a>"
  debug_inspect(
    decode_utf8(xml, None),
    content=(
      #|"<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a>café</a>"
    ),
  )
}

///|
test "decode_utf8 recognizes a UTF-16 document by its BOM" {
  // UTF-16LE bytes for "<a>hi</a>" with a leading FFFE BOM; no ASCII
  // <?xml declaration is present, so only the BOM identifies it
  let doc = b"\xff\xfe<\x00a\x00>\x00h\x00i\x00<\x00/\x00a\x00>\x00"
  debug_inspect(
    decode_utf8(doc, None),
    content=(
      #|"<a>hi</a>"
    ),
  )
}
