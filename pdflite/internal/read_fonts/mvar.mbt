// Port of read-fonts 0.39.2 `src/tables/mvar.rs`.

///|
/// The [MVAR](https://docs.microsoft.com/en-us/typography/opentype/spec/mvar)
/// table.
pub struct Mvar {
  data : FontData
}

///|
pub fn FontRef::mvar(self : FontRef) -> Mvar raise ReadError {
  let data = self.expect_data_for_tag("MVAR")
  // MIN_SIZE: version, reserved, valueRecordSize, valueRecordCount,
  // itemVariationStoreOffset
  if data.len() < 12 {
    raise OutOfBounds
  }
  { data, }
}

///|
/// Returns the metric delta for the specified tag (e.g. `cpht`) and
/// normalized variation coordinates.
pub fn Mvar::metric_delta(
  self : Mvar,
  tag : UInt,
  coords : ArrayView[F2Dot14],
) -> Fixed raise ReadError {
  let count = self.data.read_u16(8)
  // `read_array(range).ok().unwrap_or_default()` (8 byte records)
  let count = if 12 + 8 * count > self.data.len() { 0 } else { count }
  let mut lo = 0
  let mut hi = count
  while lo < hi {
    let i = (lo + hi) / 2
    let record_tag = self.data.read_u32(12 + 8 * i)
    if tag < record_tag {
      hi = i
    } else if tag > record_tag {
      lo = i + 1
    } else {
      let offset = self.data.read_u16(10)
      if offset == 0 {
        raise NullOffset
      }
      guard self.data.split_off(offset) is Some(ivs_data) else {
        raise OutOfBounds
      }
      let ivs = ItemVariationStore::read(ivs_data)
      return Fixed::from_i32(
        ivs.compute_delta(
          {
            outer: self.data.read_u16(12 + 8 * i + 4),
            inner: self.data.read_u16(12 + 8 * i + 6),
          },
          coords,
        ),
      )
    }
  }
  raise MetricIsMissing(@font_types.Tag::from_u32(tag))
}
