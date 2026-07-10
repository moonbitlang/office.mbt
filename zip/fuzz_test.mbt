// Property and fuzz tests for the ZIP + DEFLATE stack.
//
// These use a deterministic, seeded RNG so failures are reproducible. Two
// kinds of check:
//   * PROPERTY — a round-trip invariant that must hold for every input
//     (write -> read, gzip -> gunzip, and thereby deflate -> inflate).
//   * FUZZ — feed arbitrary / corrupted bytes to the readers and require they
//     only ever return a `ZipError` or a valid result: never panic, abort,
//     hang, or exhaust memory (the last is guarded by the inflate/entry-count
//     caps this suite exercises).

///|
/// Build a reproducible RNG from a label of any length. chacha8 needs a
/// 32-byte seed, so the label's length and every byte are folded into a
/// 32-byte buffer (a rolling multiply-add per position). This guarantees that
/// distinct labels yield distinct seeds, unlike a plain pad/truncate which
/// would collide e.g. `""` with a filler-matching label.
fn fuzz_rng(label : Bytes) -> @random.Rand {
  let seed = Array::make(32, (0x5A).to_byte())
  seed[0] = label.length().to_byte()
  seed[1] = (label.length() >> 8).to_byte()
  for i in 0..<label.length() {
    let j = 2 + i % 30
    seed[j] = (seed[j].to_int() * 31 + label[i].to_int()).to_byte()
  }
  @random.Rand::chacha8(seed=Bytes::from_array(seed))
}

///|
fn fuzz_random_bytes(rng : @random.Rand, len : Int) -> Bytes {
  Bytes::from_array(Array::makei(len, fn(_) { rng.int(limit=256).to_byte() }))
}

///|
fn fuzz_payload(rng : @random.Rand, max : Int) -> Bytes {
  // Mix incompressible (random) and highly compressible (single-byte runs)
  // payloads so both the literal and back-reference paths are exercised.
  if rng.boolean() {
    fuzz_random_bytes(rng, rng.int(limit=max))
  } else {
    Bytes::from_array(
      Array::make(rng.int(limit=max), rng.int(limit=256).to_byte()),
    )
  }
}

// ---- Properties ------------------------------------------------------------

///|
test "property: zip write then read preserves every entry" {
  let rng = fuzz_rng(b"zip-write-read-roundtrip")
  for _round in 0..<400 {
    let archive = @zip.Archive::new()
    let expected : Array[(String, Bytes)] = []
    let count = rng.int(limit=8) + 1
    for i in 0..<count {
      // Distinct names (avoid last-write-wins ambiguity within one archive).
      let name = "e\{i}_\{rng.int(limit=100000)}.dat"
      let data = fuzz_payload(rng, 1500)
      let compression = if rng.boolean() {
        @zip.Compression::Deflate
      } else {
        Store
      }
      archive.add(name, data, compression~)
      expected.push((name, data))
    }
    let decoded = @zip.read(@zip.write(archive))
    for pair in expected {
      let (name, data) = pair
      guard decoded.get(name) is Some(got) && got == data else {
        fail("write/read mismatch for entry \{name}")
      }
    }
  }
}

///|
test "property: gzip then gunzip round-trips" {
  let rng = fuzz_rng(b"gzip-roundtrip")
  for _round in 0..<300 {
    let data = fuzz_payload(rng, 3000)
    guard @zip.gunzip(@zip.gzip(data)) == data else {
      fail("gzip round-trip mismatch")
    }
  }
  // Explicit small-size edges.
  guard @zip.gunzip(@zip.gzip(b"")) == b"" else { fail("gzip empty") }
  guard @zip.gunzip(@zip.gzip(b"a")) == b"a" else { fail("gzip single byte") }
}

// ---- Fuzz: readers tolerate arbitrary input --------------------------------

///|
/// Run `f` and swallow any `ZipError`. A malformed input must resolve to a
/// typed error (or a value); if `f` instead aborts/panics the test process
/// dies, which is exactly the failure we want surfaced.
fn expect_no_crash(f : () -> Unit raise @zip.ZipError) -> Unit {
  f() catch {
    _ => ()
  }
}

///|
test "fuzz: read tolerates arbitrary bytes" {
  let rng = fuzz_rng(b"read-arbitrary")
  for _iter in 0..<15000 {
    let bytes = fuzz_random_bytes(rng, rng.int(limit=300))
    expect_no_crash(() => @zip.read(bytes) |> ignore)
  }
}

///|
test "fuzz: read tolerates corrupted valid archives" {
  let rng = fuzz_rng(b"read-corrupted")
  // Mutate several valid archives of different shapes so corruption reaches
  // distinct parsing paths: stored vs deflate entries, a streaming
  // data-descriptor archive (sizes/CRC trail the data), and a many-entry
  // archive with a larger central directory.
  // (A Zip64 base is not built here: the writer only emits Zip64 records for
  // >4GB inputs, which is impractical to materialize in a unit test.)
  let bases = [
    {
      let a = @zip.Archive::new()
      a.add("hello.txt", @encoding/utf8.encode("hello, world"))
      a.add(
        "data/blob.bin",
        Bytes::from_array(Array::makei(400, fn(i) { (i % 251).to_byte() })),
        compression=Deflate,
      )
      @zip.write(a)
    },
    {
      let a = @zip.Archive::new()
      a.add(
        "stream.txt",
        @encoding/utf8.encode("data descriptor payload, streamed"),
        compression=Deflate,
        data_descriptor=true,
      )
      @zip.write(a)
    },
    {
      let a = @zip.Archive::new()
      for i in 0..<12 {
        a.add("dir/f\{i}.txt", @encoding/utf8.encode("entry number \{i}"))
      }
      @zip.write(a)
    },
  ]
  let base_arrays = bases.map(fn(b) { b.to_array() })
  for _iter in 0..<15000 {
    let arr = base_arrays[rng.int(limit=base_arrays.length())].copy()
    let flips = rng.int(limit=4) + 1
    for _f in 0..<flips {
      arr[rng.int(limit=arr.length())] = rng.int(limit=256).to_byte()
    }
    let corrupted = Bytes::from_array(arr)
    expect_no_crash(() => @zip.read(corrupted) |> ignore)
  }
}

///|
test "fuzz: gunzip tolerates arbitrary bytes" {
  let rng = fuzz_rng(b"gunzip-arbitrary")
  for _iter in 0..<10000 {
    let bytes = fuzz_random_bytes(rng, rng.int(limit=300))
    expect_no_crash(() => @zip.gunzip(bytes) |> ignore)
  }
}
