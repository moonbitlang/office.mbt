// A differential sweep over real fonts, which can't be committed: run by
// `pdflite/subsetter/oracle/sweep.sh`, which subsets the fonts of a
// manifest with the Rust crate and points `SUBSETTER_SWEEP` at the results.
// Without the variable, the test does nothing.

///|
test "subsets of local fonts are byte-identical with the Rust crate" {
  guard @env.get_env_var("SUBSETTER_SWEEP") is Some(dir) else { return }
  let manifest = @fs.read_file_to_string("\{dir}/manifest.tsv")
  let expected = @fs.read_file_to_string("\{dir}/rust.txt")
    .split("\n")
    .map(s => s.to_owned())
    .collect()
  let mut cached_path = ""
  let mut cached = b""
  let mut ok = 0
  let failures = []
  let lines = manifest
    .split("\n")
    .map(s => s.to_owned())
    .filter(s => s != "")
    .collect()
  for i, line in lines {
    let fields = line.split("\t").map(s => s.to_owned()).collect()
    let path = fields[0]
    let index = @string.parse_int(fields[1])
    let glyphs = fields[2]
      .split(",")
      .filter(s => s != "")
      .map(s => @string.parse_int(s.to_owned()) catch { _ => 0 })
      .collect()
    let coords = if fields.length() > 3 {
      fields[3]
      .split(",")
      .filter(s => s != "")
      .map(s => {
        let kv = s.split("=").map(x => x.to_owned()).collect()
        let v = @string.parse_double(kv[1]) catch { _ => 0.0 }
        (@subsetter.Tag::from_str(kv[0]).unwrap(), Float::from_double(v))
      })
      .collect()
    } else {
      []
    }
    if path != cached_path {
      cached = @fs.read_file_to_bytes(path)
      cached_path = path
    }
    let remapper = @subsetter.GlyphRemapper::new()
    for g in glyphs {
      remapper.remap(g) |> ignore
    }
    let actual = try
      @subsetter.subset_with_variations(cached, index, coords, remapper)
    catch {
      e => "err \{e}"
    } noraise {
      sub =>
        if @fs.read_file_to_bytes("\{dir}/rust_out/\{i}.bin") == sub {
          "same"
        } else {
          "ok \{sub.length()}"
        }
    }
    let want = expected[i]
    let same = if want.has_prefix("ok ") {
      actual == "same"
    } else {
      actual == want
    }
    if same {
      ok += 1
    } else {
      failures.push("\{i}: \{line}: \{actual} (expected \{want})")
    }
  }
  println("\{ok}/\{lines.length()} subsets match")
  if !failures.is_empty() {
    fail(failures.join("\n"))
  }
}
