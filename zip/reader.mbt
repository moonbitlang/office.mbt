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
let flag_encrypted : Int = 0x0001

///|
let flag_deflate_max : Int = 0x0002

///|
let flag_deflate_fast : Int = 0x0004

///|
let data_descriptor_sig : Int = 0x08074b50

///|
let zip64_eocd_sig : Int = 0x06064b50

///|
let zip64_locator_sig : Int = 0x07064b50

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
    raise OutOfBounds(offset=self.pos)
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
  let value = self.read_u32_raw()
  u32_to_int(value)
}

///|
fn Reader::read_u32_raw(self : Reader) -> UInt raise ZipError {
  let b0 = self.read_u8()
  let b1 = self.read_u8()
  let b2 = self.read_u8()
  let b3 = self.read_u8()
  let v0 = b0.reinterpret_as_uint()
  let v1 = b1.reinterpret_as_uint()
  let v2 = b2.reinterpret_as_uint()
  let v3 = b3.reinterpret_as_uint()
  v0 | (v1 << 8) | (v2 << 16) | (v3 << 24)
}

///|
fn Reader::read_u64_raw(self : Reader) -> UInt64 raise ZipError {
  let lo = self.read_u32_raw()
  let hi = self.read_u32_raw()
  (UInt64::extend_uint(hi) << 32) | UInt64::extend_uint(lo)
}

///|
fn Reader::read_bytes(self : Reader, len : Int) -> BytesView raise ZipError {
  if len < 0 {
    raise OutOfBounds(offset=self.pos)
  }
  let end = self.pos + len
  if end > self.bytes.length() {
    raise OutOfBounds(offset=self.pos)
  }
  let view = self.bytes[self.pos:end]
  self.pos = end
  view
}

///|
fn Reader::skip(self : Reader, len : Int) -> Unit raise ZipError {
  if len < 0 {
    raise OutOfBounds(offset=self.pos)
  }
  let end = self.pos + len
  if end > self.bytes.length() {
    raise OutOfBounds(offset=self.pos)
  }
  self.pos = end
}

///|
fn u32_to_int(value : UInt) -> Int raise ZipError {
  let max_u32_int : UInt = 0x7FFFFFFF
  if value > max_u32_int {
    raise UnsupportedFeature(msg="u32 exceeds Int range")
  }
  value.reinterpret_as_int()
}

///|
fn u64_to_int(value : UInt64) -> Int raise ZipError {
  let max_int : UInt64 = 0x7FFFFFFF
  if value > max_int {
    raise UnsupportedFeature(msg="u64 exceeds Int range")
  }
  value.to_int()
}

///|
fn read_u16_le_at(bytes : BytesView, offset : Int) -> Int raise ZipError {
  if offset < 0 || offset + 2 > bytes.length() {
    raise OutOfBounds(offset~)
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  b0 | (b1 << 8)
}

///|
fn read_u32_le_at_raw(bytes : BytesView, offset : Int) -> UInt raise ZipError {
  if offset < 0 || offset + 4 > bytes.length() {
    raise OutOfBounds(offset~)
  }
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  let b2 = bytes[offset + 2].to_uint()
  let b3 = bytes[offset + 3].to_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn read_u64_le_at(bytes : BytesView, offset : Int) -> UInt64 raise ZipError {
  if offset < 0 || offset + 8 > bytes.length() {
    raise OutOfBounds(offset~)
  }
  let mut result : UInt64 = 0
  for i in 0..<8 {
    let b = bytes[offset + i].to_uint()
    result = result | (UInt64::extend_uint(b) << (i * 8))
  }
  result
}

///|
fn find_end_of_central(bytes : BytesView) -> Int? raise ZipError {
  let len = bytes.length()
  if len < 22 {
    return None
  }
  let max_scan = 22 + 0xFFFF
  let min_offset = if len > max_scan { len - max_scan } else { 0 }
  for i in (len - 22)>=..min_offset {
    if read_u32_le_at_raw(bytes, i) == end_of_central_sig.reinterpret_as_uint() {
      return Some(i)
    }
  } nobreak {
    None
  }
}

///|
priv struct EntryMeta {
  name : String
  compression_method : Int
  local_header_offset : Int
  compressed_size : Int
  uncompressed_size : Int
  crc32 : UInt
}

///|
fn decode_name(bytes : BytesView, offset : Int) -> String raise ZipError {
  @encoding/utf8.decode(bytes) catch {
    _ => raise InvalidUtf8(offset~)
  }
}

///|
fn ensure_flags_supported(flags : Int) -> Unit raise ZipError {
  if (flags & flag_encrypted) != 0 {
    raise UnsupportedFeature(msg="encrypted zip entries not supported")
  }
  let supported = flag_data_descriptor |
    flag_utf8 |
    flag_deflate_max |
    flag_deflate_fast
  let unsupported = flags & supported.lnot()
  if unsupported != 0 {
    raise UnsupportedFeature(
      msg="unsupported zip flags: 0x\{unsupported.to_string(radix=16)}",
    )
  }
}

///|
fn parse_zip64_extra(
  extra : BytesView,
  need_uncomp : Bool,
  need_comp : Bool,
  need_offset : Bool,
) -> (UInt64?, UInt64?, UInt64?) raise ZipError {
  let mut pos = 0
  while pos + 4 <= extra.length() {
    let header_id = read_u16_le_at(extra, pos)
    let data_size = read_u16_le_at(extra, pos + 2)
    pos = pos + 4
    if pos + data_size > extra.length() {
      raise OutOfBounds(offset=pos)
    }
    if header_id == 0x0001 {
      let mut cursor = pos
      let mut uncomp : UInt64? = None
      let mut comp : UInt64? = None
      let mut offset : UInt64? = None
      if need_uncomp {
        uncomp = Some(read_u64_le_at(extra, cursor))
        cursor = cursor + 8
      }
      if need_comp {
        comp = Some(read_u64_le_at(extra, cursor))
        cursor = cursor + 8
      }
      if need_offset {
        offset = Some(read_u64_le_at(extra, cursor))
      }
      return (uncomp, comp, offset)
    }
    pos = pos + data_size
  }
  (None, None, None)
}

///|
fn read_zip64_eocd(
  bytes : BytesView,
  eocd_offset : Int,
) -> (Int, Int, Int) raise ZipError {
  let locator_offset = eocd_offset - 20
  if locator_offset < 0 {
    raise UnsupportedFeature(msg="zip64 locator missing")
  }
  let locator_sig = read_u32_le_at_raw(bytes, locator_offset)
  if locator_sig != zip64_locator_sig.reinterpret_as_uint() {
    raise UnsupportedFeature(msg="zip64 locator missing")
  }
  let zip64_offset_u64 = read_u64_le_at(bytes, locator_offset + 8)
  let zip64_offset = u64_to_int(zip64_offset_u64)
  let reader = Reader::new(bytes, zip64_offset)
  let sig = reader.read_u32_raw()
  if sig != zip64_eocd_sig.reinterpret_as_uint() {
    raise InvalidSignature(
      expected=zip64_eocd_sig,
      actual=sig.reinterpret_as_int(),
      offset=zip64_offset,
    )
  }
  let _size = reader.read_u64_raw()
  let _version_made = reader.read_u16()
  let _version_needed = reader.read_u16()
  let disk_no = reader.read_u32_raw()
  let disk_start = reader.read_u32_raw()
  let entries_on_disk = reader.read_u64_raw()
  let total_entries = reader.read_u64_raw()
  let central_size = reader.read_u64_raw()
  let central_offset = reader.read_u64_raw()
  if disk_no != 0 || disk_start != 0 || entries_on_disk != total_entries {
    raise UnsupportedFeature(msg="multi-disk zip not supported")
  }
  (
    u64_to_int(total_entries),
    u64_to_int(central_size),
    u64_to_int(central_offset),
  )
}

///|
fn compression_from_method(method_id : Int) -> Compression raise ZipError {
  match method_id {
    0 => Store
    8 => Deflate
    _ => raise UnsupportedCompression(method_id~)
  }
}

///|
fn resource_limit_actual(limit : Int) -> Int {
  if limit < 0x7FFFFFFF {
    limit + 1
  } else {
    limit
  }
}

///|
fn read_entry_data(
  bytes : BytesView,
  meta : EntryMeta,
  max_uncompressed_bytes? : Int,
) -> Bytes raise ZipError {
  let reader = Reader::new(bytes, meta.local_header_offset)
  let sig = reader.read_u32()
  if sig != local_header_sig {
    raise InvalidSignature(
      expected=local_header_sig,
      actual=sig,
      offset=meta.local_header_offset,
    )
  }
  let _version = reader.read_u16()
  let flags = reader.read_u16()
  ensure_flags_supported(flags)
  let has_descriptor = (flags & flag_data_descriptor) != 0
  let method_id = reader.read_u16()
  let compression = compression_from_method(method_id)
  let _mod_time = reader.read_u16()
  let _mod_date = reader.read_u16()
  let _crc32 = reader.read_u32_raw()
  let comp_size_raw = reader.read_u32_raw()
  let _uncomp_size_raw = reader.read_u32_raw()
  let name_len = reader.read_u16()
  let extra_len = reader.read_u16()
  reader.skip(name_len + extra_len)
  if !has_descriptor {
    let max_u32 : UInt = 0xFFFFFFFF
    let local_comp = if comp_size_raw == max_u32 {
      meta.compressed_size
    } else {
      u32_to_int(comp_size_raw)
    }
    if local_comp != meta.compressed_size {
      raise UnsupportedFeature(msg="mismatched compressed size")
    }
  }
  let compressed = reader.read_bytes(meta.compressed_size)
  match compression {
    Store => {
      match max_uncompressed_bytes {
        Some(limit) if compressed.length() > limit =>
          raise ResourceLimitExceeded(
            kind="entry_uncompressed_bytes",
            limit~,
            actual=compressed.length(),
          )
        _ => ()
      }
      compressed.to_owned()
    }
    Deflate => {
      // Allow legitimately large declared entries, but keep a hard ceiling so a
      // lying tiny archive cannot expand without bound (decompression bomb).
      let max_output = match max_uncompressed_bytes {
        Some(limit) => limit
        None =>
          if meta.uncompressed_size > deflate_max_output_default {
            meta.uncompressed_size
          } else {
            deflate_max_output_default
          }
      }
      deflate_decode(compressed, max_output~) catch {
        OutputLimitExceeded(..) =>
          raise ResourceLimitExceeded(
            kind="entry_uncompressed_bytes",
            limit=max_output,
            actual=resource_limit_actual(max_output),
          )
        error => raise error
      }
    }
  }
}

///|
fn read_impl(
  bytes : BytesView,
  max_entries : Int?,
  max_entry_uncompressed_bytes : Int?,
  max_total_uncompressed_bytes : Int?,
) -> Archive raise ZipError {
  let eocd_offset = match find_end_of_central(bytes) {
    Some(offset) => offset
    None => raise MissingEndOfCentral
  }
  let reader = Reader::new(bytes, eocd_offset)
  ignore(reader.read_u32())
  let disk_no = reader.read_u16()
  let disk_start = reader.read_u16()
  let disk_entries = reader.read_u16()
  let total_entries = reader.read_u16()
  let central_size_raw = reader.read_u32_raw()
  let central_offset_raw = reader.read_u32_raw()
  let comment_len = reader.read_u16()
  reader.skip(comment_len)
  if disk_no != 0 || disk_start != 0 || disk_entries != total_entries {
    raise UnsupportedFeature(msg="multi-disk zip not supported")
  }
  let max_u32 : UInt = 0xFFFFFFFF
  let needs_zip64 = disk_entries == 0xFFFF ||
    total_entries == 0xFFFF ||
    central_size_raw == max_u32 ||
    central_offset_raw == max_u32
  let (entry_count, central_size, central_offset) = if needs_zip64 {
    read_zip64_eocd(bytes, eocd_offset)
  } else {
    (
      total_entries,
      u32_to_int(central_size_raw),
      u32_to_int(central_offset_raw),
    )
  }
  match max_entries {
    Some(limit) if entry_count > limit =>
      raise ResourceLimitExceeded(
        kind="entry_count",
        limit~,
        actual=entry_count,
      )
    _ => ()
  }
  if central_offset + central_size > bytes.length() {
    raise OutOfBounds(offset=central_offset)
  }
  // The declared entry count is attacker-controlled (zip64 EOCD): clamp the
  // preallocation against what the central directory could actually hold
  // (its range was validated against the input just above). Each central
  // directory record needs at least 46 bytes, so a lying count still fails
  // during parsing without a huge up-front allocation.
  let max_plausible_entries = central_size / 46 + 1
  let metas : Array[EntryMeta] = Array::new(
    capacity=if entry_count < max_plausible_entries {
      entry_count
    } else {
      max_plausible_entries
    },
  )
  let central_reader = Reader::new(bytes, central_offset)
  let mut declared_total = 0
  for _ in 0..<entry_count {
    let header_offset = central_reader.pos
    let cd_sig = central_reader.read_u32()
    if cd_sig != central_header_sig {
      raise InvalidSignature(
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
    let crc32 = central_reader.read_u32_raw()
    let comp_size_raw = central_reader.read_u32_raw()
    let uncomp_size_raw = central_reader.read_u32_raw()
    let name_len = central_reader.read_u16()
    let extra_len = central_reader.read_u16()
    let comment_len = central_reader.read_u16()
    let _disk = central_reader.read_u16()
    let _internal_attrs = central_reader.read_u16()
    let _external_attrs = central_reader.read_u32_raw()
    let local_offset_raw = central_reader.read_u32_raw()
    let name_bytes = central_reader.read_bytes(name_len)
    let extra_bytes = central_reader.read_bytes(extra_len)
    let name = decode_name(name_bytes, central_reader.pos - name_len)
    central_reader.skip(comment_len)
    let need_uncomp = uncomp_size_raw == max_u32
    let need_comp = comp_size_raw == max_u32
    let need_offset = local_offset_raw == max_u32
    let (zip_uncomp, zip_comp, zip_offset) = if need_uncomp ||
      need_comp ||
      need_offset {
      parse_zip64_extra(extra_bytes, need_uncomp, need_comp, need_offset)
    } else {
      (None, None, None)
    }
    let uncomp_size = if need_uncomp {
      match zip_uncomp {
        Some(value) => u64_to_int(value)
        None => raise UnsupportedFeature(msg="zip64 size missing")
      }
    } else {
      u32_to_int(uncomp_size_raw)
    }
    let comp_size = if need_comp {
      match zip_comp {
        Some(value) => u64_to_int(value)
        None => raise UnsupportedFeature(msg="zip64 size missing")
      }
    } else {
      u32_to_int(comp_size_raw)
    }
    let local_offset = if need_offset {
      match zip_offset {
        Some(value) => u64_to_int(value)
        None => raise UnsupportedFeature(msg="zip64 offset missing")
      }
    } else {
      u32_to_int(local_offset_raw)
    }
    ignore(compression_from_method(method_id))
    match max_entry_uncompressed_bytes {
      Some(limit) if uncomp_size > limit =>
        raise ResourceLimitExceeded(
          kind="entry_uncompressed_bytes",
          limit~,
          actual=uncomp_size,
        )
      _ => ()
    }
    match max_total_uncompressed_bytes {
      Some(limit) if uncomp_size > limit - declared_total =>
        raise ResourceLimitExceeded(
          kind="total_uncompressed_bytes",
          limit~,
          actual=resource_limit_actual(limit),
        )
      _ => declared_total = declared_total + uncomp_size
    }
    metas.push({
      name,
      compression_method: method_id,
      local_header_offset: local_offset,
      compressed_size: comp_size,
      uncompressed_size: uncomp_size,
      crc32,
    })
  }
  let archive = Archive::new()
  let mut actual_total = 0
  for meta in metas {
    ignore(compression_from_method(meta.compression_method))
    let data = read_entry_data(
      bytes,
      meta,
      max_uncompressed_bytes?=max_entry_uncompressed_bytes,
    )
    match max_total_uncompressed_bytes {
      Some(limit) if data.length() > limit - actual_total =>
        raise ResourceLimitExceeded(
          kind="total_uncompressed_bytes",
          limit~,
          actual=resource_limit_actual(limit),
        )
      _ => actual_total = actual_total + data.length()
    }
    // Construct the entry directly so it carries the central directory's
    // STORED crc (Archive::add would recompute from the inflated data,
    // hiding any mismatch from validators).
    archive.entries.push({
      name: meta.name,
      data,
      compression: Store,
      data_descriptor: false,
      crc32: meta.crc32,
    })
  }
  archive
}

///|
/// Reads a ZIP archive using the library's compatibility defaults.
pub fn read(bytes : BytesView) -> Archive raise ZipError {
  read_impl(bytes, None, None, None)
}

///|
/// Reads a ZIP archive while enforcing caller-provided materialization limits
/// before and during decompression.
pub fn read_limited(
  bytes : BytesView,
  max_entries~ : Int,
  max_entry_uncompressed_bytes~ : Int,
  max_total_uncompressed_bytes~ : Int,
) -> Archive raise ZipError {
  if max_entries < 0 ||
    max_entry_uncompressed_bytes < 0 ||
    max_total_uncompressed_bytes < 0 {
    raise UnsupportedFeature(msg="ZIP resource limits must be non-negative")
  }
  read_impl(
    bytes,
    Some(max_entries),
    Some(max_entry_uncompressed_bytes),
    Some(max_total_uncompressed_bytes),
  )
}

///|
fn push_u16_le(buf : Array[Byte], value : Int) -> Unit {
  let v = value.reinterpret_as_uint()
  buf.push((v & 0xFF).to_byte())
  buf.push(((v >> 8) & 0xFF).to_byte())
}

///|
fn push_u32_le(buf : Array[Byte], value : UInt) -> Unit {
  buf.push((value & 0xFF).to_byte())
  buf.push(((value >> 8) & 0xFF).to_byte())
  buf.push(((value >> 16) & 0xFF).to_byte())
  buf.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn push_u64_le(buf : Array[Byte], value : UInt64) -> Unit {
  for shift in [0, 8, 16, 24, 32, 40, 48, 56] {
    buf.push(((value >> shift).to_uint() & 0xFF).to_byte())
  }
}

///|
fn push_bytes(buf : Array[Byte], bytes : BytesView) -> Unit {
  for b in bytes {
    buf.push(b)
  }
}

///|
test "zip read data descriptor" {
  let name : Bytes = b"a.txt"
  let data : Bytes = b"hi"
  let crc = crc32(data)
  let buf : Array[Byte] = []
  // local header
  push_u32_le(buf, 0x04034B50)
  push_u16_le(buf, 20)
  push_u16_le(buf, 0x0808)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, 0)
  push_u16_le(buf, name.length())
  push_u16_le(buf, 0)
  push_bytes(buf, name)
  push_bytes(buf, data)
  // data descriptor
  push_u32_le(buf, 0x08074B50)
  push_u32_le(buf, crc)
  push_u32_le(buf, data.length().reinterpret_as_uint())
  push_u32_le(buf, data.length().reinterpret_as_uint())
  // central directory
  let central_offset = buf.length()
  push_u32_le(buf, 0x02014B50)
  push_u16_le(buf, 20)
  push_u16_le(buf, 20)
  push_u16_le(buf, 0x0808)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, crc)
  push_u32_le(buf, data.length().reinterpret_as_uint())
  push_u32_le(buf, data.length().reinterpret_as_uint())
  push_u16_le(buf, name.length())
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, 0)
  push_bytes(buf, name)
  // end of central directory
  let central_size = buf.length() - central_offset
  push_u32_le(buf, 0x06054B50)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 1)
  push_u16_le(buf, 1)
  push_u32_le(buf, central_size.reinterpret_as_uint())
  push_u32_le(buf, central_offset.reinterpret_as_uint())
  push_u16_le(buf, 0)
  let archive = read(Bytes::from_array(buf))
  inspect(archive.get("a.txt") == Some(b"hi"), content="true")
}

///|
test "zip read zip64 extra sizes" {
  let name : Bytes = b"b.txt"
  let data : Bytes = b"zip64"
  let crc = crc32(data)
  let buf : Array[Byte] = []
  // local header with zip64 extra
  push_u32_le(buf, 0x04034B50)
  push_u16_le(buf, 45)
  push_u16_le(buf, 0x0800)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, crc)
  push_u32_le(buf, 0xFFFFFFFF)
  push_u32_le(buf, 0xFFFFFFFF)
  push_u16_le(buf, name.length())
  push_u16_le(buf, 20)
  push_bytes(buf, name)
  // zip64 extra (uncomp, comp)
  push_u16_le(buf, 0x0001)
  push_u16_le(buf, 16)
  push_u64_le(buf, UInt64::extend_uint(data.length().reinterpret_as_uint()))
  push_u64_le(buf, UInt64::extend_uint(data.length().reinterpret_as_uint()))
  push_bytes(buf, data)
  // central directory with zip64 extra (uncomp, comp, offset)
  let central_offset = buf.length()
  push_u32_le(buf, 0x02014B50)
  push_u16_le(buf, 45)
  push_u16_le(buf, 45)
  push_u16_le(buf, 0x0800)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, crc)
  push_u32_le(buf, 0xFFFFFFFF)
  push_u32_le(buf, 0xFFFFFFFF)
  push_u16_le(buf, name.length())
  push_u16_le(buf, 28)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, 0xFFFFFFFF)
  push_bytes(buf, name)
  push_u16_le(buf, 0x0001)
  push_u16_le(buf, 24)
  push_u64_le(buf, UInt64::extend_uint(data.length().reinterpret_as_uint()))
  push_u64_le(buf, UInt64::extend_uint(data.length().reinterpret_as_uint()))
  push_u64_le(buf, UInt64::extend_uint(0))
  // end of central directory
  let central_size = buf.length() - central_offset
  push_u32_le(buf, 0x06054B50)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 1)
  push_u16_le(buf, 1)
  push_u32_le(buf, central_size.reinterpret_as_uint())
  push_u32_le(buf, central_offset.reinterpret_as_uint())
  push_u16_le(buf, 0)
  let archive = read(Bytes::from_array(buf))
  inspect(archive.get("b.txt") == Some(b"zip64"), content="true")
}

///|
test "zip reader wb: direct guard error branches" {
  let reader = Reader::new(b"", 0)
  try reader.read_bytes(-1) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_bytes to raise")
  }
  try reader.skip(-1) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected skip to raise")
  }
  try u64_to_int(0x1_0000_0000) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected u64_to_int to raise")
  }
  try read_u16_le_at(b"\x00", 0) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_u16_le_at to raise")
  }
  try read_u32_le_at_raw(b"\x00\x01", 0) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_u32_le_at_raw to raise")
  }
  try read_u64_le_at(b"\x00\x01\x02", 0) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_u64_le_at to raise")
  }
}
