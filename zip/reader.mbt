///|
let local_header_sig : Int = 0x04034b50

///|
let central_header_sig : Int = 0x02014b50

///|
let end_of_central_sig : Int = 0x06054b50

///|
let flag_data_descriptor : Int = 0x0008

///|
let flag_utf8 : Int = 0x0800

///|
priv struct Reader {
  bytes : BytesView
  mut pos : Int
}

///|
fn Reader::new(bytes : BytesView, pos : Int) -> Reader {
  { bytes, pos }
}

///|
fn Reader::read_u8(self : Reader) -> Int raise ZipError {
  if self.pos >= self.bytes.length() || self.pos < 0 {
    raise ZipError::OutOfBounds(offset=self.pos)
  }
  let value = self.bytes[self.pos].to_int()
  self.pos = self.pos + 1
  value
}

///|
fn Reader::read_u16(self : Reader) -> Int raise ZipError {
  let b0 = self.read_u8()
  let b1 = self.read_u8()
  b0 | (b1 << 8)
}

///|
fn Reader::read_u32(self : Reader) -> Int raise ZipError {
  let b0 = self.read_u8()
  let b1 = self.read_u8()
  let b2 = self.read_u8()
  let b3 = self.read_u8()
  let value = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  if value < 0 {
    raise ZipError::UnsupportedFeature(msg="u32 exceeds Int range")
  }
  value
}

///|
fn Reader::read_bytes(self : Reader, len : Int) -> BytesView raise ZipError {
  if len < 0 {
    raise ZipError::OutOfBounds(offset=self.pos)
  }
  let end = self.pos + len
  if end > self.bytes.length() {
    raise ZipError::OutOfBounds(offset=self.pos)
  }
  let view = self.bytes[self.pos:end]
  self.pos = end
  view
}

///|
fn Reader::skip(self : Reader, len : Int) -> Unit raise ZipError {
  if len < 0 {
    raise ZipError::OutOfBounds(offset=self.pos)
  }
  let end = self.pos + len
  if end > self.bytes.length() {
    raise ZipError::OutOfBounds(offset=self.pos)
  }
  self.pos = end
}

///|
fn read_u32_le_at(bytes : BytesView, offset : Int) -> Int raise ZipError {
  if offset < 0 || offset + 4 > bytes.length() {
    raise ZipError::OutOfBounds(offset~)
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  let b2 = bytes[offset + 2].to_int()
  let b3 = bytes[offset + 3].to_int()
  let value = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  if value < 0 {
    raise ZipError::UnsupportedFeature(msg="u32 exceeds Int range")
  }
  value
}

///|
fn find_end_of_central(bytes : BytesView) -> Int? raise ZipError {
  let len = bytes.length()
  if len < 22 {
    return None
  }
  let max_scan = 22 + 0xFFFF
  let min_offset = if len > max_scan { len - max_scan } else { 0 }
  for i = len - 22; i >= min_offset; i = i - 1 {
    if read_u32_le_at(bytes, i) == end_of_central_sig {
      return Some(i)
    }
  } else {
    None
  }
}

///|
priv struct EntryMeta {
  name : String
  compression_method : Int
  local_header_offset : Int
  compressed_size : Int
}

///|
fn decode_name(bytes : BytesView, offset : Int) -> String raise ZipError {
  @encoding/utf8.decode(bytes) catch {
    _ => raise ZipError::InvalidUtf8(offset~)
  }
}

///|
fn ensure_flags_supported(flags : Int) -> Unit raise ZipError {
  if (flags & flag_data_descriptor) != 0 {
    raise ZipError::UnsupportedFeature(msg="data descriptor not supported")
  }
}

///|
fn compression_from_method(method_id : Int) -> Compression raise ZipError {
  match method_id {
    0 => Compression::Store
    _ => raise ZipError::UnsupportedCompression(method_id~)
  }
}

///|
fn read_entry_data(bytes : BytesView, meta : EntryMeta) -> Bytes raise ZipError {
  let reader = Reader::new(bytes, meta.local_header_offset)
  let sig = reader.read_u32()
  if sig != local_header_sig {
    raise ZipError::InvalidSignature(
      expected=local_header_sig,
      actual=sig,
      offset=meta.local_header_offset,
    )
  }
  let _version = reader.read_u16()
  let flags = reader.read_u16()
  ensure_flags_supported(flags)
  let method_id = reader.read_u16()
  ignore(compression_from_method(method_id))
  let _mod_time = reader.read_u16()
  let _mod_date = reader.read_u16()
  let _crc32 = reader.read_u32()
  let comp_size = reader.read_u32()
  let _uncomp_size = reader.read_u32()
  let name_len = reader.read_u16()
  let extra_len = reader.read_u16()
  reader.skip(name_len + extra_len)
  if comp_size != meta.compressed_size {
    raise ZipError::UnsupportedFeature(msg="mismatched compressed size")
  }
  reader.read_bytes(comp_size).to_bytes()
}

///|
pub fn read(bytes : BytesView) -> Archive raise ZipError {
  let eocd_offset = match find_end_of_central(bytes) {
    Some(offset) => offset
    None => raise ZipError::MissingEndOfCentral
  }
  let reader = Reader::new(bytes, eocd_offset)
  let sig = reader.read_u32()
  if sig != end_of_central_sig {
    raise ZipError::InvalidSignature(
      expected=end_of_central_sig,
      actual=sig,
      offset=eocd_offset,
    )
  }
  let disk_no = reader.read_u16()
  let disk_start = reader.read_u16()
  let disk_entries = reader.read_u16()
  let total_entries = reader.read_u16()
  let central_size = reader.read_u32()
  let central_offset = reader.read_u32()
  let comment_len = reader.read_u16()
  reader.skip(comment_len)
  if disk_no != 0 || disk_start != 0 || disk_entries != total_entries {
    raise ZipError::UnsupportedFeature(msg="multi-disk zip not supported")
  }
  if central_offset + central_size > bytes.length() {
    raise ZipError::OutOfBounds(offset=central_offset)
  }
  let metas : Array[EntryMeta] = []
  let central_reader = Reader::new(bytes, central_offset)
  for _ in 0..<total_entries {
    let header_offset = central_reader.pos
    let cd_sig = central_reader.read_u32()
    if cd_sig != central_header_sig {
      raise ZipError::InvalidSignature(
        expected=central_header_sig,
        actual=cd_sig,
        offset=header_offset,
      )
    }
    let _version_made = central_reader.read_u16()
    let _version_needed = central_reader.read_u16()
    let flags = central_reader.read_u16()
    ensure_flags_supported(flags)
    let method_id = central_reader.read_u16()
    let _mod_time = central_reader.read_u16()
    let _mod_date = central_reader.read_u16()
    let _crc32 = central_reader.read_u32()
    let comp_size = central_reader.read_u32()
    let _uncomp_size = central_reader.read_u32()
    let name_len = central_reader.read_u16()
    let extra_len = central_reader.read_u16()
    let comment_len = central_reader.read_u16()
    let _disk = central_reader.read_u16()
    let _internal_attrs = central_reader.read_u16()
    let _external_attrs = central_reader.read_u32()
    let local_offset = central_reader.read_u32()
    let name_bytes = central_reader.read_bytes(name_len)
    let name = decode_name(name_bytes, central_reader.pos - name_len)
    central_reader.skip(extra_len + comment_len)
    ignore(compression_from_method(method_id))
    metas.push({
      name,
      compression_method: method_id,
      local_header_offset: local_offset,
      compressed_size: comp_size,
    })
  }
  let archive = Archive::new()
  for meta in metas {
    ignore(compression_from_method(meta.compression_method))
    let data = read_entry_data(bytes, meta)
    archive.add(meta.name, data)
  }
  archive
}
