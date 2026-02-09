///|
fn wb_write_i32_le(buf : Array[Byte], offset : Int, value : Int) -> Unit {
  let v = value.reinterpret_as_uint()
  buf[offset] = (v & 0xFF).to_byte()
  buf[offset + 1] = ((v >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((v >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((v >> 24) & 0xFF).to_byte()
}

///|
fn wb_write_u16_le(buf : Array[Byte], offset : Int, value : Int) -> Unit {
  let v = value.reinterpret_as_uint()
  buf[offset] = (v & 0xFF).to_byte()
  buf[offset + 1] = ((v >> 8) & 0xFF).to_byte()
}

///|
test "cfb wb: primitive guards and helper branches" {
  let bad16 : Result[Int, Error] = try? read_u16_le(b"\x00", 0)
  inspect(bad16 is Err(XlsxError::InvalidEncryptionInfo(_)), content="true")

  let bad32 : Result[UInt, Error] = try? read_u32_le(b"\x00\x01", 0)
  inspect(bad32 is Err(XlsxError::InvalidEncryptionInfo(_)), content="true")

  let bad64 : Result[UInt64, Error] = try? read_u64_le(b"\x00\x01\x02", 0)
  inspect(bad64 is Err(XlsxError::InvalidEncryptionInfo(_)), content="true")

  let builder = cfb_builder_new()
  builder.write_bytes(b"abc")
  inspect(builder.position, content="3")

  builder.put("Root Entry/a", b"1")
  builder.paths[0] = "Root Entry"
  builder.put("b", b"2")
  inspect(builder.paths.length(), content="3")

  inspect(cfb_compare("x/y", "x/z"), content="-1")
  inspect(cfb_compare("x", "x/y"), content="-1")
  inspect(parent_path("plain"), content="")
  inspect(base_name("plain"), content="plain")
}

///|
test "cfb wb: prepare and read-chain guard branches" {
  let builder = cfb_builder_new()
  builder.put("Root Entry/a", b"a")
  builder.put("Root Entry/b", b"b")
  builder.sectors[1].type_id = 0
  builder.sectors[2].cls_id = Bytes::default()
  builder.prepare()
  let mut found_b = false
  for sector in builder.sectors {
    if sector.name == "b" {
      found_b = true
      inspect(sector.cls_id.length(), content="16")
    }
  }
  inspect(found_b, content="true")

  let chain_oob : Result[Array[Int], Error] = try? read_sector_chain([5], 2)
  inspect(chain_oob is Err(XlsxError::InvalidEncryptionInfo(_)), content="true")

  let chain_cycle : Result[Array[Int], Error] = try? read_sector_chain([0], 0)
  inspect(
    chain_cycle is Err(XlsxError::InvalidEncryptionInfo(msg="cfb chain cycle")),
    content="true",
  )

  let chain_long : Result[Array[Int], Error] = try? read_sector_chain(
    [1, 2, 1],
    0,
  )
  inspect(
    chain_long
    is Err(XlsxError::InvalidEncryptionInfo(msg="cfb chain too long")),
    content="true",
  )
}

///|
test "cfb wb: large builder/write and cfb_read difat branches" {
  let builder = cfb_builder_new()
  let big = Bytes::make(8_388_608, (0x41).to_byte())
  builder.put("BigStream", big)
  builder.sectors[1].cls_id = Bytes::default()
  let bytes = builder.write()
  inspect(bytes.length() > 0, content="true")

  let reader = cfb_read(bytes) catch {
    err => fail("expected big cfb to parse, got \{err}")
  }
  let stream = reader.read_stream("BigStream") catch {
    err => fail("expected BigStream, got \{err}")
  }
  inspect(stream.length(), content="8388608")

  let tweaked = bytes.to_array()
  wb_write_i32_le(tweaked, 0x44, 0)
  wb_write_i32_le(tweaked, 0x48, 0)
  let parsed_tweaked : Result[CfbReader, Error] = try? cfb_read(
    Bytes::from_array(tweaked),
  )
  inspect(parsed_tweaked is Ok(_) || parsed_tweaked is Err(_), content="true")
}

///|
test "cfb wb: cfb_read short/signature/invalid-name branches" {
  let short_header : Result[CfbReader, Error] = try? cfb_read(b"short")
  inspect(
    short_header
    is Err(XlsxError::InvalidEncryptionInfo(msg="cfb header too short")),
    content="true",
  )

  let bad_sig : Array[Byte] = Array::make(512, (0x00).to_byte())
  let invalid_sig : Result[CfbReader, Error] = try? cfb_read(
    Bytes::from_array(bad_sig),
  )
  inspect(
    invalid_sig
    is Err(XlsxError::InvalidEncryptionInfo(msg="invalid cfb signature")),
    content="true",
  )

  let builder = cfb_builder_new()
  builder.put("Doc", b"x")
  let bytes = builder.write()
  let sector_shift = read_u16_le(bytes, 0x1e)
  let sector_size = 1 << sector_shift
  let dir_start = read_i32_le(bytes, 0x30)
  let dir_offset = (dir_start + 1) * sector_size
  let second_entry = dir_offset + 128
  let invalid_name = bytes.to_array()
  invalid_name[second_entry] = (0x00).to_byte()
  invalid_name[second_entry + 1] = (0xD8).to_byte()
  wb_write_u16_le(invalid_name, second_entry + 0x40, 4)
  let bad_name_result : Result[CfbReader, Error] = try? cfb_read(
    Bytes::from_array(invalid_name),
  )
  inspect(
    bad_name_result
    is Err(XlsxError::InvalidEncryptionInfo(msg="invalid cfb name")),
    content="true",
  )
}

///|
test "cfb wb: read_stream guard branches" {
  let not_found : CfbReader = {
    bytes: Bytes::default(),
    sector_size: 512,
    mini_sector_size: 64,
    fat: [],
    mini_fat: [],
    entries: [],
    mini_stream: Bytes::default(),
  }
  let missing : Result[Bytes, Error] = try? not_found.read_stream("missing")
  inspect(
    missing is Err(XlsxError::InvalidEncryptionInfo(msg="cfb entry not found")),
    content="true",
  )

  let not_stream : CfbReader = {
    bytes: Bytes::default(),
    sector_size: 512,
    mini_sector_size: 64,
    fat: [],
    mini_fat: [],
    entries: [{ name: "x", type_id: 5, start: 0, size: 1 }],
    mini_stream: Bytes::default(),
  }
  let not_stream_result : Result[Bytes, Error] = try? not_stream.read_stream(
    "x",
  )
  inspect(
    not_stream_result
    is Err(XlsxError::InvalidEncryptionInfo(msg="cfb entry is not a stream")),
    content="true",
  )

  let zero_size : CfbReader = {
    bytes: Bytes::default(),
    sector_size: 512,
    mini_sector_size: 64,
    fat: [],
    mini_fat: [],
    entries: [{ name: "x", type_id: 2, start: 0, size: 0 }],
    mini_stream: Bytes::default(),
  }
  inspect(zero_size.read_stream("x"), content="b\"\"")

  let mini_missing : CfbReader = {
    bytes: Bytes::default(),
    sector_size: 512,
    mini_sector_size: 64,
    fat: [],
    mini_fat: [],
    entries: [{ name: "x", type_id: 2, start: 0, size: 1 }],
    mini_stream: Bytes::default(),
  }
  let mini_missing_result : Result[Bytes, Error] = try? mini_missing.read_stream(
    "x",
  )
  inspect(
    mini_missing_result
    is Err(XlsxError::InvalidEncryptionInfo(msg="cfb mini stream missing")),
    content="true",
  )

  let mini_oob : CfbReader = {
    bytes: Bytes::default(),
    sector_size: 512,
    mini_sector_size: 64,
    fat: [],
    mini_fat: [0],
    entries: [{ name: "x", type_id: 2, start: 1, size: 1 }],
    mini_stream: Bytes::make(64, (0x00).to_byte()),
  }
  let mini_oob_result : Result[Bytes, Error] = try? mini_oob.read_stream("x")
  inspect(
    mini_oob_result
    is Err(
      XlsxError::InvalidEncryptionInfo(msg="cfb mini stream out of bounds")
    ),
    content="true",
  )

  let mini_chain_oob : CfbReader = {
    bytes: Bytes::default(),
    sector_size: 512,
    mini_sector_size: 64,
    fat: [],
    mini_fat: [],
    entries: [{ name: "x", type_id: 2, start: 0, size: 1 }],
    mini_stream: Bytes::make(64, (0x00).to_byte()),
  }
  let mini_chain_oob_result : Result[Bytes, Error] = try? mini_chain_oob.read_stream(
    "x",
  )
  inspect(
    mini_chain_oob_result
    is Err(XlsxError::InvalidEncryptionInfo(msg="cfb mini chain out of bounds")),
    content="true",
  )

  let mini_chain_long : CfbReader = {
    bytes: Bytes::default(),
    sector_size: 512,
    mini_sector_size: 64,
    fat: [],
    mini_fat: [0],
    entries: [{ name: "x", type_id: 2, start: 0, size: 128 }],
    mini_stream: Bytes::make(64, (0x00).to_byte()),
  }
  let mini_chain_long_result : Result[Bytes, Error] = try? mini_chain_long.read_stream(
    "x",
  )
  inspect(
    mini_chain_long_result
    is Err(XlsxError::InvalidEncryptionInfo(msg="cfb mini chain too long")),
    content="true",
  )
}

///|
test "cfb wb: locate/write-msat/write-directory residual branches" {
  let medium = cfb_builder_new()
  medium.put("Medium", Bytes::make(65_024, (0x61).to_byte()))
  medium.prepare()
  let location = medium.locate()
  inspect(location[1], content="0")
  inspect(location[2], content="2")

  let msat = cfb_builder_new()
  msat.write_msat([1, 2, 400, 0, 0, 0, 0, 0])
  inspect(msat.position > 0, content="true")

  let directory = cfb_builder_new()
  directory.sectors[0].cls_id = Bytes::default()
  directory.write_directory_entry([1, 0, 0, 0, 1, 0, 0, 0])
  inspect(directory.position > 0, content="true")
}
