///|
test "random_bytes draws differ across calls and runs are seeded" {
  let a = random_bytes(16)
  let b = random_bytes(16)
  inspect(a.length(), content="16")
  inspect(b.length(), content="16")
  // consecutive draws from the stateful generator must differ
  inspect(a == b, content="false")
  // and must not reproduce ChaCha8's fixed default-seed stream
  let default_rng = @random.Rand::chacha8()
  let default_stream : Array[Byte] = Array::make(16, (0).to_byte())
  for i in 0..<16 {
    default_stream[i] = default_rng.int(limit=256).to_byte()
  }
  inspect(a == Bytes::from_array(default_stream), content="false")
}

///|
test "set_random_source overrides random_bytes" {
  set_random_source(count => {
    let out : Array[Byte] = Array::make(count, (0x5a).to_byte())
    Bytes::from_array(out)
  })
  let fixed = random_bytes(4)
  // restore the built-in generator before other tests observe the override
  random_bytes_override.val = None
  debug_inspect(
    fixed,
    content=(
      #|<Bytes: [0x5a, 0x5a, 0x5a, 0x5a]>
    ),
  )
  inspect(random_bytes(4) == fixed, content="false")
}
