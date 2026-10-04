//! A differential mutation sweep: every single-byte mutation (to 0x00,
//! 0xFF, `b ^ 0x01`, `b ^ 0x80`, `b + 1` and `b - 1`) of the synthetic
//! fixtures of `fonts.rs`, subset with the `subsetter` crate. Writes the
//! mutated fonts and a manifest in the format of `sweep` plus a label column
//! (`<dir>/fonts/*.bin`, `<dir>/manifest.tsv`), the results
//! (`<dir>/rust.txt`: `ok <len> <sha256>`, `err <message>` or `panic`) and
//! the subsets (`<dir>/rust_out/<line>.bin`).
//!
//! Usage: `cargo run --release --offline --bin mutations -- <dir> [font...]`

use sha2::{Digest, Sha256};
use std::io::Write;
use subsetter::{subset_with_variations, GlyphRemapper, Tag};
use subsetter_oracle::fonts;

fn parse_coords(coords: &str) -> Vec<(Tag, f32)> {
    coords
        .split(',')
        .filter(|s| !s.is_empty())
        .map(|s| {
            let (t, v) = s.split_once('=').unwrap();
            (t.parse::<Tag>().unwrap(), v.parse::<f32>().unwrap())
        })
        .collect()
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let dir = std::path::PathBuf::from(&args[1]);
    let only: Vec<String> = args[2..].to_vec();
    std::fs::create_dir_all(dir.join("fonts")).unwrap();
    std::fs::create_dir_all(dir.join("rust_out")).unwrap();
    let mut manifest = std::fs::File::create(dir.join("manifest.tsv")).unwrap();
    let mut results = std::fs::File::create(dir.join("rust.txt")).unwrap();
    std::panic::set_hook(Box::new(|_| {}));
    let mut line = 0usize;
    for (name, data) in fonts::all() {
        if !only.is_empty() && !only.iter().any(|o| o == name) {
            continue;
        }
        let cases: &[(&[u16], &str)] = match name {
            "tt_var" | "tt_var_hvar" | "tt_var_hvar_regions" | "tt_var_avar_count0" | "tt_var_gvar_null" | "tt_var_varc_empty" | "tt_var_varc_nocov" | "tt_var_varc" => &[
                (&[1, 2, 3, 4, 5], "wght=650,wdth=150"),
                (&[0, 1, 2, 3, 4, 5], "wght=100"),
                (&[1, 3], ""),
            ],
            "cff2" | "cff2_header4" => &[(&[1, 2, 3], "wght=900"), (&[0, 1, 2, 3, 4, 5], "wght=200")],
            _ => &[(&[0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "")],
        };
        for pos in 0..data.len() {
            let b = data[pos];
            let mut values = vec![0x00, 0xFF, b ^ 0x01, b ^ 0x80, b.wrapping_add(1), b.wrapping_sub(1)];
            values.sort();
            values.dedup();
            for v in values {
                if v == b {
                    continue;
                }
                let mut font = data.clone();
                font[pos] = v;
                let path = dir.join("fonts").join(format!("{name}_{pos}_{v}.bin"));
                std::fs::write(&path, &font).unwrap();
                for (glyphs, coords) in cases {
                    let parsed = parse_coords(coords);
                    let glyph_list = glyphs.iter().map(|g| g.to_string()).collect::<Vec<_>>().join(",");
                    writeln!(manifest, "{}\t0\t{glyph_list}\t{coords}\t{name}@{pos}={v}", path.display()).unwrap();
                    let result = std::panic::catch_unwind(|| {
                        let mut remapper = GlyphRemapper::new();
                        for g in glyphs.iter() {
                            remapper.remap(*g);
                        }
                        subset_with_variations(&font, 0, &parsed, &remapper)
                    });
                    match result {
                        Ok(Ok(sub)) => {
                            writeln!(results, "ok {} {:x}", sub.len(), Sha256::digest(&sub)).unwrap();
                            std::fs::write(dir.join("rust_out").join(format!("{line}.bin")), &sub).unwrap();
                        }
                        Ok(Err(e)) => writeln!(results, "err {e}").unwrap(),
                        Err(_) => writeln!(results, "panic").unwrap(),
                    }
                    line += 1;
                }
            }
        }
    }
    eprintln!("{line} cases");
}
