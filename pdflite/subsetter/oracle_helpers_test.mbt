// Helpers of the generated `oracle_test.mbt`.

///|
fn from_hex(s : String) -> Bytes {
  let digit = (c : Char) => {
    if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else {
      c.to_int() - 87
    }
  }
  // (Multi-line literals have newlines between the lines.)
  let chars = s.to_array().filter(c => c != '\n')
  Bytes::makei(chars.length() / 2, i => {
    ((digit(chars[2 * i]) << 4) | digit(chars[2 * i + 1])).to_byte()
  })
}

///|
fn to_hex(b : Bytes) -> String {
  let digits = "0123456789abcdef"
  let sb = StringBuilder()
  for x in b {
    sb.write_char(digits.get_char(x.to_int() >> 4).unwrap())
    sb.write_char(digits.get_char(x.to_int() & 0xF).unwrap())
  }
  sb.to_string()
}

///|
/// Subset `font` with the glyphs (remapped in order) like the Rust crate
/// did: with `subset` if `coords` is `None`, else with
/// `subset_with_variations`; compare with the expected bytes or error
/// message.
fn check_subset(
  font : Bytes,
  index : Int,
  glyphs : Array[Int],
  coords : Array[(String, Double)]?,
  expected? : Bytes,
  error? : String,
) -> Unit raise {
  let remapper = @subsetter.GlyphRemapper::new()
  for g in glyphs {
    remapper.remap(g) |> ignore
  }
  let run = () => {
    match coords {
      None => @subsetter.subset(font, index, remapper)
      Some(coords) =>
        @subsetter.subset_with_variations(
          font,
          index,
          coords.map(c => {
            (@subsetter.Tag::from_str(c.0).unwrap(), Float::from_double(c.1))
          }),
          remapper,
        )
    }
  }
  try run() catch {
    e =>
      match error {
        Some(error) => assert_eq(e.to_string(), error)
        None => fail("unexpected error \{e}")
      }
  } noraise {
    sub =>
      match (expected, error) {
        (Some(expected), _) =>
          if sub != expected {
            fail(
              "subset differs:\n\{to_hex(sub)}\nexpected:\n\{to_hex(expected)}",
            )
          }
        (_, Some(error)) => fail("expected the error \{error}")
        _ => fail("nothing to check")
      }
  }
}
