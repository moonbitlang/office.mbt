///|
test "MoonBit String length is UTF-16 code units" {
  let music_symbol = "𝄞"
  @test.assert_eq(music_symbol.length(), 2)
  @test.assert_eq(music_symbol.char_length(), 1)
}

///|
test "Bytes preserve raw PDF byte values" {
  let raw : Array[Byte] = [0xF0, 0x9D, 0x84, 0x9E, 0xFF]
  let bytes = Bytes::from_array(raw)
  @test.assert_eq(bytes.length(), 5)
  @test.assert_eq(bytes[0].to_int(), 0xF0)
  @test.assert_eq(bytes[3].to_int(), 0x9E)
  @test.assert_eq(bytes[4].to_int(), 0xFF)
}

///|
test "Scalar literals narrow by type context" {
  let (byte, uint16, int64, uint64) : (Byte, UInt16, Int64, UInt64) = (
    255, 65535, 42, 42,
  )
  @test.assert_eq(byte.to_int(), 255)
  @test.assert_eq(uint16.to_int(), 65535)
  @test.assert_eq(int64.to_string(), "42")
  @test.assert_eq(uint64.to_string(), "42")
}

///|
test "Primitive refs and growable arrays are explicit mutable containers" {
  let counter : Ref[Int] = { val: 0 }
  counter.val += 1
  let bytes : Array[Byte] = [1, 2, 3]
  bytes[1] = 255
  @test.assert_eq(counter.val, 1)
  @test.assert_eq(bytes[1].to_int(), 255)
}

///|
test "FixedArray is the closest MoonBit container to OCaml array" {
  let fixed : FixedArray[Int] = [1, 2, 3]
  fixed[1] = 9
  @test.assert_eq(fixed.length(), 3)
  @test.assert_eq(fixed[1], 9)
  let doubled = [ for x in fixed => x * 2 ]
  @test.assert_eq(doubled, [2, 18, 6])
}

///|
fn array_view_length_for_test(values : ArrayView[Int]) -> Int {
  values.length()
}

///|
test "ArrayView accepts fixed and growable arrays for read-only APIs" {
  let fixed : FixedArray[Int] = [1, 2, 3]
  let growable : Array[Int] = [1, 2, 3]
  @test.assert_eq(array_view_length_for_test(fixed), 3)
  @test.assert_eq(array_view_length_for_test(growable), 3)
}

///|
test "Imported packages are used through package aliases" {
  let objects : @hashmap.HashMap[Int, String] = @hashmap.HashMap::new()
  objects[7] = "seven"
  @test.assert_eq(objects.get(7), Some("seven"))
}
