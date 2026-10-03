///|
test "variation region lists with huge counts are out of bounds" {
  // An item variation store whose region list claims 65535 axes and
  // regions (the size of the region array overflows 32 bits).
  let data = Bytes::from_array(
    [
      // format, region list offset (12), item variation data count (1)
      0, 1, 0, 0, 0, 12, 0, 1,
      // item variation data offset (16)
       0, 0, 0, 16,
      // region list: axis count, region count
       0xFF, 0xFF, 0xFF, 0xFF,
      // item variation data: item count 1, word delta count 0, region
      // index count 1, region index 0, delta row
       0, 1, 0, 0, 0, 1, 0, 0, 5,
    ].map(b => b.to_byte()),
  )
  let ivs = ItemVariationStore::read(FontData::new(data))
  let coords = [F2Dot14::from_bits(0x2000)]
  let result = try ivs.compute_delta({ outer: 0, inner: 0, }, coords) catch {
    e => e.to_string()
  } noraise {
    v => v.to_string()
  }
  inspect(result, content="An offset was out of bounds")
}
