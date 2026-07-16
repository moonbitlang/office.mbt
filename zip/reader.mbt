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
let unicode_path_extra_id : Int = 0x7075

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
  if len < 0 ||
    self.pos < 0 ||
    self.pos > self.bytes.length() ||
    len > self.bytes.length() - self.pos {
    raise OutOfBounds(offset=self.pos)
  }
  let end = self.pos + len
  let view = self.bytes[self.pos:end]
  self.pos = end
  view
}

///|
fn Reader::skip(self : Reader, len : Int) -> Unit raise ZipError {
  if len < 0 ||
    self.pos < 0 ||
    self.pos > self.bytes.length() ||
    len > self.bytes.length() - self.pos {
    raise OutOfBounds(offset=self.pos)
  }
  let end = self.pos + len
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
  if offset < 0 || offset > bytes.length() || 2 > bytes.length() - offset {
    raise OutOfBounds(offset~)
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  b0 | (b1 << 8)
}

///|
fn read_u32_le_at_raw(bytes : BytesView, offset : Int) -> UInt raise ZipError {
  if offset < 0 || offset > bytes.length() || 4 > bytes.length() - offset {
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
  if offset < 0 || offset > bytes.length() || 8 > bytes.length() - offset {
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
    if read_u32_le_at_raw(bytes, i) == end_of_central_sig.reinterpret_as_uint() &&
      read_u16_le_at(bytes, i + 20) == len - i - 22 {
      return Some(i)
    }
  } nobreak {
    None
  }
}

///|
priv struct EntryMeta {
  name : String
  name_bytes : BytesView
  flags : Int
  compression_method : Int
  local_header_offset : Int
  compressed_size : Int
  uncompressed_size : Int
  crc32 : UInt
  zip64_sizes : Bool
  central_record : Bytes
  central_zip64_uncompressed_position : Int?
  central_zip64_compressed_position : Int?
  zip64_offset_position : Int?
}

///|
priv struct LocalRecord {
  compressed : BytesView
  compression : Compression
  data_start : Int
  end : Int
  local_zip64_uncompressed_position : Int?
  local_zip64_compressed_position : Int?
  descriptor_signed : Bool
  descriptor_zip64 : Bool
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
  raw_name : BytesView,
  decoded_name : StringView,
  need_uncomp : Bool,
  need_comp : Bool,
  need_offset : Bool,
  descriptor_sizes : Bool,
) -> (Bool, UInt64?, UInt64?, UInt64?) raise ZipError {
  let mut pos = 0
  let mut found_zip64 = false
  let mut found_unicode_path = false
  let mut uncomp : UInt64? = None
  let mut comp : UInt64? = None
  let mut offset : UInt64? = None
  while pos < extra.length() {
    if pos > extra.length() || 4 > extra.length() - pos {
      raise UnsupportedFeature(msg="truncated zip extra field header")
    }
    let header_id = read_u16_le_at(extra, pos)
    let data_size = read_u16_le_at(extra, pos + 2)
    pos = pos + 4
    if pos > extra.length() || data_size > extra.length() - pos {
      raise OutOfBounds(offset=pos)
    }
    let field = extra[pos:pos + data_size]
    pos = pos + data_size
    if header_id == unicode_path_extra_id {
      if found_unicode_path {
        raise UnsupportedFeature(msg="duplicate unicode path extra field")
      }
      found_unicode_path = true
      if field.length() < 5 || field[0] != 1 {
        raise UnsupportedFeature(msg="invalid unicode path extra field")
      }
      if read_u32_le_at_raw(field, 1) != crc32(raw_name) {
        raise UnsupportedFeature(msg="unicode path extra field CRC mismatch")
      }
      let unicode_name = decode_name(field[5:], 0)
      if unicode_name[:] != decoded_name {
        raise UnsupportedFeature(msg="unicode path extra field name mismatch")
      }
    } else if header_id == 0x0001 {
      if found_zip64 {
        raise UnsupportedFeature(msg="duplicate zip64 extra field")
      }
      found_zip64 = true
      // A streamed ZIP64 local header carries both size slots even when its
      // classic size fields are zero rather than 0xffffffff. Their values may
      // remain zero until the authoritative data descriptor is written.
      let read_uncomp = need_uncomp || descriptor_sizes
      let read_comp = need_comp || descriptor_sizes
      let required_size = (if read_uncomp { 8 } else { 0 }) +
        (if read_comp { 8 } else { 0 }) +
        (if need_offset { 8 } else { 0 })
      if field.length() != required_size {
        raise UnsupportedFeature(msg="zip64 extra field size mismatch")
      }
      let reader = Reader::new(field, 0)
      if read_uncomp {
        uncomp = Some(reader.read_u64_raw())
      }
      if read_comp {
        comp = Some(reader.read_u64_raw())
      }
      if need_offset {
        offset = Some(reader.read_u64_raw())
      }
    }
  }
  (found_zip64, uncomp, comp, offset)
}

///|
fn zip64_value_positions(
  extra : BytesView,
  need_uncomp : Bool,
  need_comp : Bool,
  need_offset : Bool,
  descriptor_sizes : Bool,
) -> (Int?, Int?, Int?) raise ZipError {
  let mut position = 0
  while position < extra.length() {
    if position > extra.length() || 4 > extra.length() - position {
      raise UnsupportedFeature(msg="truncated zip extra field header")
    }
    let header_id = read_u16_le_at(extra, position)
    let data_size = read_u16_le_at(extra, position + 2)
    let data_offset = position + 4
    if data_offset > extra.length() || data_size > extra.length() - data_offset {
      raise OutOfBounds(offset=data_offset)
    }
    if header_id == 0x0001 {
      let read_uncomp = need_uncomp || descriptor_sizes
      let read_comp = need_comp || descriptor_sizes
      let required_size = (if read_uncomp { 8 } else { 0 }) +
        (if read_comp { 8 } else { 0 }) +
        (if need_offset { 8 } else { 0 })
      if data_size != required_size {
        raise UnsupportedFeature(msg="zip64 extra field size mismatch")
      }
      let uncomp_position = if read_uncomp { Some(data_offset) } else { None }
      let comp_position = if read_comp {
        Some(data_offset + (if read_uncomp { 8 } else { 0 }))
      } else {
        None
      }
      let offset_position = if need_offset {
        Some(
          data_offset +
          (if read_uncomp { 8 } else { 0 }) +
          (if read_comp { 8 } else { 0 }),
        )
      } else {
        None
      }
      return (uncomp_position, comp_position, offset_position)
    }
    position = data_offset + data_size
  }
  if need_uncomp || need_comp || need_offset || descriptor_sizes {
    raise UnsupportedFeature(msg="required zip64 extra field is missing")
  }
  (None, None, None)
}

///|
fn read_zip64_eocd(
  bytes : BytesView,
  eocd_offset : Int,
  preserved_source_budget : PreservedSourceBudget,
) -> (UInt64, UInt64, UInt64, Int, Zip64TrailerTemplate) raise ZipError {
  let locator_offset = eocd_offset - 20
  if locator_offset < 0 {
    raise UnsupportedFeature(msg="zip64 locator missing")
  }
  let locator_sig = read_u32_le_at_raw(bytes, locator_offset)
  if locator_sig != zip64_locator_sig.reinterpret_as_uint() {
    raise UnsupportedFeature(msg="zip64 locator missing")
  }
  let locator_disk = read_u32_le_at_raw(bytes, locator_offset + 4)
  let zip64_offset_u64 = read_u64_le_at(bytes, locator_offset + 8)
  let locator_disks = read_u32_le_at_raw(bytes, locator_offset + 16)
  if locator_disk != 0 || locator_disks != 1 {
    raise UnsupportedFeature(msg="multi-disk zip not supported")
  }
  let zip64_offset = u64_to_int(zip64_offset_u64)
  if zip64_offset > locator_offset || 12 > locator_offset - zip64_offset {
    raise OutOfBounds(offset=zip64_offset)
  }
  let reader = Reader::new(bytes, zip64_offset)
  let sig = reader.read_u32_raw()
  if sig != zip64_eocd_sig.reinterpret_as_uint() {
    raise InvalidSignature(
      expected=zip64_eocd_sig,
      actual=sig.reinterpret_as_int(),
      offset=zip64_offset,
    )
  }
  let record_size = reader.read_u64_raw()
  let expected_record_size = (locator_offset - zip64_offset - 12).to_uint64()
  if record_size < 44 || record_size != expected_record_size {
    raise UnsupportedFeature(msg="zip64 end record size mismatch")
  }
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
  let end_record_length = locator_offset - zip64_offset
  let locator_length = eocd_offset - locator_offset
  let classic_end_record_length = bytes.length() - eocd_offset
  preserved_source_budget.charge(end_record_length)
  preserved_source_budget.charge(locator_length)
  preserved_source_budget.charge(classic_end_record_length)
  (
    total_entries,
    central_size,
    central_offset,
    zip64_offset,
    {
      end_record: bytes[zip64_offset:locator_offset].to_owned(),
      locator: bytes[locator_offset:eocd_offset].to_owned(),
      classic_end_record: bytes[eocd_offset:].to_owned(),
    },
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
/// Bounds exact source-record copies retained for byte-preserving rewrites.
/// Charging happens before each allocation; the source input and inflated
/// payloads have independent limits.
priv struct PreservedSourceBudget {
  limit : Int?
  mut used : Int
}

///|
fn PreservedSourceBudget::new(limit : Int?) -> PreservedSourceBudget {
  { limit, used: 0 }
}

///|
fn PreservedSourceBudget::charge(
  self : PreservedSourceBudget,
  amount : Int,
) -> Unit raise ZipError {
  if amount < 0 {
    raise UnsupportedFeature(msg="invalid preserved ZIP source-record size")
  }
  match self.limit {
    Some(limit) if amount > limit - self.used =>
      raise ResourceLimitExceeded(
        kind="total_preserved_source_bytes",
        limit~,
        actual=resource_actual_with_base(self.used, amount),
      )
    Some(_) => self.used = self.used + amount
    None => ()
  }
}

///|
fn resource_actual_with_base(base : Int, actual : Int) -> Int {
  if base < 0 || actual < 0 || actual > 0x7FFFFFFF - base {
    0x7FFFFFFF
  } else {
    base + actual
  }
}

///|
fn u64_resource_actual(value : UInt64) -> Int {
  let max_int : UInt64 = 0x7FFFFFFF
  if value > max_int {
    0x7FFFFFFF
  } else {
    value.to_int()
  }
}

///|
fn local_size_matches(
  raw : UInt,
  zip64 : UInt64?,
  expected : Int,
  allow_placeholder : Bool,
) -> Bool {
  let expected64 = expected.to_uint64()
  let zip64_matches = match zip64 {
    Some(value) => value == expected64 || (allow_placeholder && value == 0)
    None => true
  }
  if allow_placeholder && raw == 0 {
    return zip64_matches
  }
  let max_u32 : UInt = 0xFFFFFFFF
  if raw == max_u32 {
    return match zip64 {
      Some(_) => zip64_matches
      None => false
    }
  }
  UInt64::extend_uint(raw) == expected64 && zip64_matches
}

///|
fn data_descriptor_record_matches(
  bytes : BytesView,
  offset : Int,
  meta : EntryMeta,
  zip64_sizes : Bool,
  signed : Bool,
) -> Bool {
  try {
    let reader = Reader::new(bytes, offset)
    if signed &&
      reader.read_u32_raw() != data_descriptor_sig.reinterpret_as_uint() {
      return false
    }
    if reader.read_u32_raw() != meta.crc32 {
      return false
    }
    if zip64_sizes {
      reader.read_u64_raw() == meta.compressed_size.to_uint64() &&
      reader.read_u64_raw() == meta.uncompressed_size.to_uint64()
    } else {
      reader.read_u32_raw() == meta.compressed_size.reinterpret_as_uint() &&
      reader.read_u32_raw() == meta.uncompressed_size.reinterpret_as_uint()
    }
  } catch {
    _ => false
  }
}

///|
fn data_descriptor_record_size(
  bytes : BytesView,
  offset : Int,
  meta : EntryMeta,
  zip64_sizes : Bool,
) -> Int raise ZipError {
  let signed_matches = data_descriptor_record_matches(
    bytes, offset, meta, zip64_sizes, true,
  )
  let unsigned_matches = data_descriptor_record_matches(
    bytes, offset, meta, zip64_sizes, false,
  )
  if signed_matches && unsigned_matches {
    raise UnsupportedFeature(msg="ambiguous data descriptor")
  }
  if !signed_matches && !unsigned_matches {
    raise UnsupportedFeature(msg="mismatched data descriptor")
  }
  (if signed_matches { 4 } else { 0 }) + 4 + (if zip64_sizes { 16 } else { 8 })
}

///|
fn read_entry_record(
  bytes : BytesView,
  meta : EntryMeta,
  central_offset : Int,
) -> LocalRecord raise ZipError {
  if meta.local_header_offset < 0 || meta.local_header_offset >= central_offset {
    raise OutOfBounds(offset=meta.local_header_offset)
  }
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
  if flags != meta.flags {
    raise UnsupportedFeature(msg="mismatched local and central flags")
  }
  let has_descriptor = (flags & flag_data_descriptor) != 0
  let method_id = reader.read_u16()
  if method_id != meta.compression_method {
    raise UnsupportedFeature(
      msg="mismatched local and central compression method",
    )
  }
  let compression = compression_from_method(method_id)
  let _mod_time = reader.read_u16()
  let _mod_date = reader.read_u16()
  let local_crc32 = reader.read_u32_raw()
  let comp_size_raw = reader.read_u32_raw()
  let uncomp_size_raw = reader.read_u32_raw()
  let name_len = reader.read_u16()
  let extra_len = reader.read_u16()
  let local_name = reader.read_bytes(name_len)
  let local_extra = reader.read_bytes(extra_len)
  if local_name != meta.name_bytes {
    raise UnsupportedFeature(msg="mismatched local and central entry name")
  }
  let max_u32 : UInt = 0xFFFFFFFF
  let need_local_uncomp = uncomp_size_raw == max_u32
  let need_local_comp = comp_size_raw == max_u32
  let (local_zip64, local_zip_uncomp, local_zip_comp, _) = parse_zip64_extra(
    local_extra,
    local_name,
    meta.name,
    need_local_uncomp,
    need_local_comp,
    false,
    has_descriptor,
  )
  let (local_zip64_uncompressed_position, local_zip64_compressed_position, _) = if local_zip64 {
    let (uncomp, comp, offset) = zip64_value_positions(
      local_extra, need_local_uncomp, need_local_comp, false, has_descriptor,
    )
    (
      uncomp.map(position => 30 + name_len + position),
      comp.map(position => 30 + name_len + position),
      offset,
    )
  } else {
    (None, None, None)
  }
  if has_descriptor {
    if local_crc32 != 0 && local_crc32 != meta.crc32 {
      raise UnsupportedFeature(msg="mismatched local and central CRC-32")
    }
  } else if local_crc32 != meta.crc32 {
    raise UnsupportedFeature(msg="mismatched local and central CRC-32")
  }
  if !local_size_matches(
      comp_size_raw,
      local_zip_comp,
      meta.compressed_size,
      has_descriptor,
    ) {
    raise UnsupportedFeature(msg="mismatched local and central compressed size")
  }
  if !local_size_matches(
      uncomp_size_raw,
      local_zip_uncomp,
      meta.uncompressed_size,
      has_descriptor,
    ) {
    raise UnsupportedFeature(
      msg="mismatched local and central uncompressed size",
    )
  }
  if reader.pos > central_offset ||
    meta.compressed_size > central_offset - reader.pos {
    raise OutOfBounds(offset=reader.pos)
  }
  let data_start = reader.pos
  let compressed = reader.read_bytes(meta.compressed_size)
  let descriptor_zip64 = meta.zip64_sizes || local_zip64
  let mut descriptor_signed = false
  if has_descriptor {
    let descriptor_bytes = bytes[:central_offset]
    descriptor_signed = data_descriptor_record_matches(
      descriptor_bytes,
      reader.pos,
      meta,
      descriptor_zip64,
      true,
    )
    let descriptor_size = data_descriptor_record_size(
      descriptor_bytes,
      reader.pos,
      meta,
      descriptor_zip64,
    )
    reader.skip(descriptor_size)
  }
  {
    compressed,
    compression,
    data_start,
    end: reader.pos,
    local_zip64_uncompressed_position,
    local_zip64_compressed_position,
    descriptor_signed,
    descriptor_zip64,
  }
}

///|
fn materialize_entry_data(
  record : LocalRecord,
  meta : EntryMeta,
  max_uncompressed_bytes : Int?,
  limit_kind : String,
  reported_limit : Int,
  actual_base : Int,
) -> Bytes raise ZipError {
  let data = match record.compression {
    Store => {
      match max_uncompressed_bytes {
        Some(limit) if record.compressed.length() > limit =>
          raise ResourceLimitExceeded(
            kind=limit_kind,
            limit=reported_limit,
            actual=resource_actual_with_base(
              actual_base,
              record.compressed.length(),
            ),
          )
        _ => ()
      }
      record.compressed.to_owned()
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
      deflate_decode(record.compressed, max_output~) catch {
        OutputLimitExceeded(limit~) =>
          match max_uncompressed_bytes {
            Some(_) =>
              raise ResourceLimitExceeded(
                kind=limit_kind,
                limit=reported_limit,
                actual=resource_actual_with_base(
                  actual_base,
                  resource_limit_actual(max_output),
                ),
              )
            None => raise OutputLimitExceeded(limit~)
          }
        error => raise error
      }
    }
  }
  if data.length() != meta.uncompressed_size {
    raise UnsupportedFeature(
      msg="decoded data length does not match central size",
    )
  }
  data
}

///|
fn read_impl(
  bytes : BytesView,
  max_package_bytes : Int?,
  max_entries : Int?,
  max_entry_uncompressed_bytes : Int?,
  max_total_uncompressed_bytes : Int?,
  max_total_preserved_source_bytes : Int?,
) -> Archive raise ZipError {
  match max_package_bytes {
    Some(limit) if bytes.length() > limit =>
      raise ResourceLimitExceeded(
        kind="package_bytes",
        limit~,
        actual=bytes.length(),
      )
    _ => ()
  }
  let preserved_source_budget = PreservedSourceBudget::new(
    max_total_preserved_source_bytes,
  )
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
  preserved_source_budget.charge(comment_len)
  let archive_comment = reader.read_bytes(comment_len).to_owned()
  if disk_no != 0 || disk_start != 0 {
    raise UnsupportedFeature(msg="multi-disk zip not supported")
  }
  let max_u32 : UInt = 0xFFFFFFFF
  let needs_zip64 = disk_entries == 0xFFFF ||
    total_entries == 0xFFFF ||
    central_size_raw == max_u32 ||
    central_offset_raw == max_u32
  let (
    entry_count_raw,
    central_size_raw64,
    central_offset_raw64,
    central_boundary,
    zip64_trailer,
  ) = if needs_zip64 {
    let (zip_entries, zip_size, zip_offset, zip64_offset, zip64_trailer) = read_zip64_eocd(
      bytes, eocd_offset, preserved_source_budget,
    )
    if disk_entries != 0xFFFF && disk_entries.to_uint64() != zip_entries {
      raise UnsupportedFeature(msg="classic and zip64 entry count mismatch")
    }
    if total_entries != 0xFFFF && total_entries.to_uint64() != zip_entries {
      raise UnsupportedFeature(msg="classic and zip64 entry count mismatch")
    }
    if central_size_raw != max_u32 &&
      UInt64::extend_uint(central_size_raw) != zip_size {
      raise UnsupportedFeature(msg="classic and zip64 central size mismatch")
    }
    if central_offset_raw != max_u32 &&
      UInt64::extend_uint(central_offset_raw) != zip_offset {
      raise UnsupportedFeature(msg="classic and zip64 central offset mismatch")
    }
    (
      if total_entries == 0xFFFF {
        zip_entries
      } else {
        total_entries.to_uint64()
      },
      if central_size_raw == max_u32 {
        zip_size
      } else {
        UInt64::extend_uint(central_size_raw)
      },
      if central_offset_raw == max_u32 {
        zip_offset
      } else {
        UInt64::extend_uint(central_offset_raw)
      },
      zip64_offset,
      Some(zip64_trailer),
    )
  } else {
    if disk_entries != total_entries {
      raise UnsupportedFeature(msg="multi-disk zip not supported")
    }
    (
      total_entries.to_uint64(),
      u32_to_int(central_size_raw).to_uint64(),
      u32_to_int(central_offset_raw).to_uint64(),
      eocd_offset,
      None,
    )
  }
  match max_entries {
    Some(limit) if entry_count_raw > limit.to_uint64() =>
      raise ResourceLimitExceeded(
        kind="entry_count",
        limit~,
        actual=u64_resource_actual(entry_count_raw),
      )
    _ => ()
  }
  let entry_count = u64_to_int(entry_count_raw)
  let central_size = u64_to_int(central_size_raw64)
  let central_offset = u64_to_int(central_offset_raw64)
  if central_offset > central_boundary ||
    central_boundary > bytes.length() ||
    central_size != central_boundary - central_offset {
    raise OutOfBounds(offset=central_offset)
  }
  // The declared entry count is attacker-controlled (zip64 EOCD): clamp the
  // preallocation against what the central directory could actually hold
  // (its range was validated against the input just above). Each central
  // directory record needs at least 46 bytes, so a lying count still fails
  // during parsing without a huge up-front allocation.
  let max_plausible_entries = central_size / 46
  let metas : Array[EntryMeta] = Array::new(
    capacity=if entry_count < max_plausible_entries {
      entry_count
    } else {
      max_plausible_entries
    },
  )
  let central_bytes = bytes[central_offset:central_boundary]
  let central_reader = Reader::new(central_bytes, 0)
  let mut declared_total = 0
  for _ in 0..<entry_count {
    let central_record_start = central_reader.pos
    let header_offset = central_offset + central_record_start
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
    let disk = central_reader.read_u16()
    let _internal_attrs = central_reader.read_u16()
    let _external_attrs = central_reader.read_u32_raw()
    let local_offset_raw = central_reader.read_u32_raw()
    let name_bytes = central_reader.read_bytes(name_len)
    let extra_bytes = central_reader.read_bytes(extra_len)
    let name = decode_name(
      name_bytes,
      central_offset + central_reader.pos - extra_len - name_len,
    )
    central_reader.skip(comment_len)
    preserved_source_budget.charge(central_reader.pos - central_record_start)
    let central_record = central_bytes[central_record_start:central_reader.pos].to_owned()
    if disk != 0 {
      raise UnsupportedFeature(msg="multi-disk zip not supported")
    }
    let need_uncomp = uncomp_size_raw == max_u32
    let need_comp = comp_size_raw == max_u32
    let need_offset = local_offset_raw == max_u32
    let (_, zip_uncomp, zip_comp, zip_offset) = parse_zip64_extra(
      extra_bytes, name_bytes, name, need_uncomp, need_comp, need_offset, false,
    )
    let uncomp_size = if need_uncomp {
      match zip_uncomp {
        Some(value) => {
          match max_entry_uncompressed_bytes {
            Some(limit) if value > limit.to_uint64() =>
              raise ResourceLimitExceeded(
                kind="entry_uncompressed_bytes",
                limit~,
                actual=u64_resource_actual(value),
              )
            _ => ()
          }
          match max_total_uncompressed_bytes {
            Some(limit) if value > limit.to_uint64() =>
              raise ResourceLimitExceeded(
                kind="total_uncompressed_bytes",
                limit~,
                actual=u64_resource_actual(value),
              )
            _ => ()
          }
          u64_to_int(value)
        }
        None => raise UnsupportedFeature(msg="zip64 size missing")
      }
    } else {
      let value = UInt64::extend_uint(uncomp_size_raw)
      match max_entry_uncompressed_bytes {
        Some(limit) if value > limit.to_uint64() =>
          raise ResourceLimitExceeded(
            kind="entry_uncompressed_bytes",
            limit~,
            actual=u64_resource_actual(value),
          )
        _ => ()
      }
      match max_total_uncompressed_bytes {
        Some(limit) if value > limit.to_uint64() =>
          raise ResourceLimitExceeded(
            kind="total_uncompressed_bytes",
            limit~,
            actual=u64_resource_actual(value),
          )
        _ => ()
      }
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
    let (
      central_zip64_uncompressed_position,
      central_zip64_compressed_position,
      central_zip64_offset_position,
    ) = zip64_value_positions(
      extra_bytes, need_uncomp, need_comp, need_offset, false,
    )
    let central_extra_start = 46 + name_len
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
      name_bytes,
      flags,
      compression_method: method_id,
      local_header_offset: local_offset,
      compressed_size: comp_size,
      uncompressed_size: uncomp_size,
      crc32,
      zip64_sizes: need_uncomp || need_comp,
      central_record,
      central_zip64_uncompressed_position: central_zip64_uncompressed_position.map(position => {
          central_extra_start + position
        },
      ),
      central_zip64_compressed_position: central_zip64_compressed_position.map(position => {
        central_extra_start + position
      }),
      zip64_offset_position: central_zip64_offset_position.map(position => {
        central_extra_start + position
      }),
    })
  }
  if central_reader.pos != central_size {
    raise UnsupportedFeature(msg="central directory size/count mismatch")
  }
  let records : Array[LocalRecord] = Array::new(capacity=metas.length())
  let local_intervals : Array[(Int, Int)] = Array::new(capacity=metas.length())
  for meta in metas {
    let record = read_entry_record(bytes, meta, central_offset)
    preserved_source_budget.charge(record.end - meta.local_header_offset)
    records.push(record)
    local_intervals.push((meta.local_header_offset, record.end))
  }
  local_intervals.sort_by((left, right) => {
    let by_start = left.0.compare(right.0)
    if by_start != 0 {
      by_start
    } else {
      left.1.compare(right.1)
    }
  })
  let mut covered_until = 0
  for interval in local_intervals {
    if interval.0 < covered_until {
      raise UnsupportedFeature(msg="overlapping zip local records")
    }
    if interval.0 != covered_until {
      raise UnsupportedFeature(
        msg="unreferenced data before zip central directory",
      )
    }
    covered_until = interval.1
  }
  if covered_until != central_offset {
    raise UnsupportedFeature(
      msg="unreferenced data before zip central directory",
    )
  }
  let bounded_source = match
    (
      max_package_bytes, max_entries, max_entry_uncompressed_bytes, max_total_uncompressed_bytes,
      max_total_preserved_source_bytes,
    ) {
    (
      Some(_),
      Some(max_entries),
      Some(max_entry),
      Some(max_total),
      Some(max_preserved),
    ) =>
      Some({
        package_bytes: bytes.length(),
        max_entries,
        max_entry_uncompressed_bytes: max_entry,
        max_total_uncompressed_bytes: max_total,
        max_total_preserved_source_bytes: max_preserved,
      })
    _ => None
  }
  let archive = archive_from_source(
    archive_comment, zip64_trailer, bounded_source,
  )
  let mut actual_total = 0
  for index in 0..<metas.length() {
    let meta = metas[index]
    let record = records[index]
    ignore(compression_from_method(meta.compression_method))
    let mut materialize_limit = max_entry_uncompressed_bytes
    let mut limit_kind = "entry_uncompressed_bytes"
    let mut reported_limit = match max_entry_uncompressed_bytes {
      Some(limit) => limit
      None => 0
    }
    let mut actual_base = 0
    match max_total_uncompressed_bytes {
      Some(total_limit) => {
        let remaining = total_limit - actual_total
        match materialize_limit {
          Some(entry_limit) if entry_limit <= remaining => ()
          _ => {
            materialize_limit = Some(remaining)
            limit_kind = "total_uncompressed_bytes"
            reported_limit = total_limit
            actual_base = actual_total
          }
        }
      }
      None => ()
    }
    let data = materialize_entry_data(
      record, meta, materialize_limit, limit_kind, reported_limit, actual_base,
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
      compression: record.compression,
      data_descriptor: (meta.flags & flag_data_descriptor) != 0,
      crc32: meta.crc32,
      source_local_offset: Some(meta.local_header_offset),
      source: Some({
        local_record: bytes[meta.local_header_offset:record.end].to_owned(),
        local_header_length: record.data_start - meta.local_header_offset,
        central_record: meta.central_record,
        local_zip64_uncompressed_position: record.local_zip64_uncompressed_position,
        local_zip64_compressed_position: record.local_zip64_compressed_position,
        central_zip64_uncompressed_position: meta.central_zip64_uncompressed_position,
        central_zip64_compressed_position: meta.central_zip64_compressed_position,
        central_zip64_offset_position: meta.zip64_offset_position,
        descriptor_signed: record.descriptor_signed,
        descriptor_zip64: record.descriptor_zip64,
      }),
      source_unchanged: true,
    })
  }
  archive
}

///|
/// Reads a ZIP archive using the library's compatibility defaults.
pub fn read(bytes : BytesView) -> Archive raise ZipError {
  read_impl(bytes, None, None, None, None, None)
}

///|
/// Reads a ZIP archive while enforcing caller-provided limits on source-package
/// bytes, entries, inflated payloads, and retained byte-preservation records.
/// Every bounded allocation is rejected before it is materialized.
pub fn read_limited(
  bytes : BytesView,
  max_package_bytes~ : Int,
  max_entries~ : Int,
  max_entry_uncompressed_bytes~ : Int,
  max_total_uncompressed_bytes~ : Int,
  max_total_preserved_source_bytes~ : Int,
) -> Archive raise ZipError {
  if max_package_bytes < 0 ||
    max_entries < 0 ||
    max_entry_uncompressed_bytes < 0 ||
    max_total_uncompressed_bytes < 0 ||
    max_total_preserved_source_bytes < 0 {
    raise UnsupportedFeature(msg="ZIP resource limits must be non-negative")
  }
  read_impl(
    bytes,
    Some(max_package_bytes),
    Some(max_entries),
    Some(max_entry_uncompressed_bytes),
    Some(max_total_uncompressed_bytes),
    Some(max_total_preserved_source_bytes),
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
fn make_streamed_zip64_descriptor_archive(
  local_size : UInt,
  zip64_placeholder : UInt64,
) -> Bytes {
  let name : Bytes = b"streamed.txt"
  let data : Bytes = b"zip64-stream"
  let crc = crc32(data)
  let buf : Array[Byte] = []
  // Streamed local header: ZIP64 is selected before the final sizes are
  // known, while the central directory can later use its 32-bit fields.
  push_u32_le(buf, 0x04034B50)
  push_u16_le(buf, 45)
  push_u16_le(buf, 0x0808)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, local_size)
  push_u32_le(buf, local_size)
  push_u16_le(buf, name.length())
  push_u16_le(buf, 20)
  push_bytes(buf, name)
  push_u16_le(buf, 0x0001)
  push_u16_le(buf, 16)
  push_u64_le(buf, zip64_placeholder)
  push_u64_le(buf, zip64_placeholder)
  push_bytes(buf, data)
  // ZIP64 data descriptor selected by the local ZIP64 extra field.
  push_u32_le(buf, 0x08074B50)
  push_u32_le(buf, crc)
  push_u64_le(buf, data.length().to_uint64())
  push_u64_le(buf, data.length().to_uint64())
  let central_offset = buf.length()
  push_u32_le(buf, 0x02014B50)
  push_u16_le(buf, 45)
  push_u16_le(buf, 45)
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
  let central_size = buf.length() - central_offset
  push_u32_le(buf, 0x06054B50)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 1)
  push_u16_le(buf, 1)
  push_u32_le(buf, central_size.reinterpret_as_uint())
  push_u32_le(buf, central_offset.reinterpret_as_uint())
  push_u16_le(buf, 0)
  Bytes::from_array(buf)
}

///|
test "zip read streamed ZIP64 descriptors with ZIP32 central sizes" {
  for local_size in [(0xFFFFFFFF : UInt), (0 : UInt)] {
    let archive = read(make_streamed_zip64_descriptor_archive(local_size, 0))
    inspect(
      archive.get("streamed.txt") == Some(b"zip64-stream"),
      content="true",
    )
  }
}

///|
test "zip read rejects mismatched streamed ZIP64 placeholders" {
  try read(make_streamed_zip64_descriptor_archive(0xFFFFFFFF, 1)) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="mismatched local and central compressed size")
    _ => fail("expected mismatched ZIP64 placeholder")
  } noraise {
    _ => fail("expected mismatched ZIP64 placeholder")
  }
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
  let central_uncompressed_offset = buf.length()
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
  let encoded = Bytes::from_array(buf)
  let archive = read(encoded)
  inspect(archive.get("b.txt") == Some(b"zip64"), content="true")
  let oversized = encoded.to_array()
  for index in 0..<8 {
    oversized[central_uncompressed_offset + index] = (0).to_byte()
  }
  oversized[central_uncompressed_offset + 4] = (1).to_byte()
  try
    read_limited(
      Bytes::from_array(oversized),
      max_package_bytes=oversized.length(),
      max_entries=1,
      max_entry_uncompressed_bytes=64,
      max_total_uncompressed_bytes=64,
      max_total_preserved_source_bytes=oversized.length(),
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="entry_uncompressed_bytes")
      inspect(limit, content="64")
      inspect(actual, content="2147483647")
    }
    _ => fail("expected ZIP64 resource limit")
  } noraise {
    _ => fail("expected oversized ZIP64 declaration to raise")
  }
}

///|
test "zip64 extra values cannot escape their declared field" {
  let followed_by_other_field : Bytes = [
    // Empty ZIP64 field.
    0x01, 0x00, 0x00, 0x00,
    // Unrelated eight-byte field that must not supply the ZIP64 value.
     0xFE, 0xCA, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]
  try
    parse_zip64_extra(
      followed_by_other_field, b"", "", true, false, false, false,
    )
  catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="zip64 extra field size mismatch")
    _ => fail("expected bounded ZIP64 field failure")
  } noraise {
    _ => fail("expected bounded ZIP64 field failure")
  }
  let trailing_partial_header : Bytes = [0xFE, 0xCA, 0x00, 0x00, 0x01]
  try
    parse_zip64_extra(
      trailing_partial_header, b"", "", false, false, false, false,
    )
  catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="truncated zip extra field header")
    _ => fail("expected truncated extra-field failure")
  } noraise {
    _ => fail("expected truncated extra-field failure")
  }
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
