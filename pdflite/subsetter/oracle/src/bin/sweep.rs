//! Subsets real fonts listed in a manifest with the `subsetter` crate and
//! prints the length and SHA-256 of each subset (or the error), so that the
//! MoonBit port can be compared on fonts that can't be committed.
//!
//! Manifest lines: `<path>\t<index>\t<glyphs, comma separated>\t<coords>`
//! where coords are `tag=value` pairs separated by commas (may be empty).
//! Output lines: `ok <len> <sha256>` or `err <message>`, one per manifest
//! line. With `--dump <dir>`, subsets are also written to `<dir>/<line>.bin`.

use sha2::{Digest, Sha256};
use std::io::{BufRead, Write};
use subsetter::{subset_with_variations, GlyphRemapper, Tag};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let manifest = &args[1];
    let dump = if args.len() > 3 && args[2] == "--dump" { Some(args[3].clone()) } else { None };
    let file = std::fs::File::open(manifest).unwrap();
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    let mut cache: Option<(String, Vec<u8>)> = None;
    for (i, line) in std::io::BufReader::new(file).lines().enumerate() {
        let line = line.unwrap();
        let fields: Vec<&str> = line.split('\t').collect();
        let path = fields[0];
        let index: u32 = fields[1].parse().unwrap();
        let glyphs: Vec<u16> = fields[2].split(',').filter(|s| !s.is_empty()).map(|s| s.parse().unwrap()).collect();
        let coords: Vec<(Tag, f32)> = fields.get(3).copied().unwrap_or("").split(',').filter(|s| !s.is_empty()).map(|s| {
            let (t, v) = s.split_once('=').unwrap();
            (t.parse::<Tag>().unwrap(), v.parse::<f32>().unwrap())
        }).collect();
        if cache.as_ref().map(|c| c.0 != path).unwrap_or(true) {
            cache = Some((path.to_string(), std::fs::read(path).unwrap()));
        }
        let data = &cache.as_ref().unwrap().1;
        let mut remapper = GlyphRemapper::new();
        for g in &glyphs {
            remapper.remap(*g);
        }
        match subset_with_variations(data, index, &coords, &remapper) {
            Ok(sub) => {
                let hash = Sha256::digest(&sub);
                writeln!(out, "ok {} {:x}", sub.len(), hash).unwrap();
                if let Some(dir) = &dump {
                    std::fs::write(format!("{dir}/{i}.bin"), &sub).unwrap();
                }
            }
            Err(e) => writeln!(out, "err {e}").unwrap(),
        }
    }
}
