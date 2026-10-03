//! Synthetic fixture fonts for the oracle tests: hand-written tables that
//! exercise the subsetter (TrueType outlines with composites, `name` and
//! `post` subsetting, name- and CID-keyed CFF with subroutines and hints,
//! TrueType variations with `gvar`/`avar`/`HVAR`, and CFF2 with blends).

/// A big-endian byte writer.
#[derive(Default, Clone)]
pub struct W(pub Vec<u8>);

impl W {
    pub fn new() -> Self {
        Self(Vec::new())
    }
    pub fn u8(&mut self, v: u8) -> &mut Self {
        self.0.push(v);
        self
    }
    pub fn u16(&mut self, v: u16) -> &mut Self {
        self.0.extend(v.to_be_bytes());
        self
    }
    pub fn i16(&mut self, v: i16) -> &mut Self {
        self.0.extend(v.to_be_bytes());
        self
    }
    pub fn u24(&mut self, v: u32) -> &mut Self {
        self.0.extend(&v.to_be_bytes()[1..]);
        self
    }
    pub fn u32(&mut self, v: u32) -> &mut Self {
        self.0.extend(v.to_be_bytes());
        self
    }
    pub fn i32(&mut self, v: i32) -> &mut Self {
        self.0.extend(v.to_be_bytes());
        self
    }
    pub fn bytes(&mut self, v: &[u8]) -> &mut Self {
        self.0.extend(v);
        self
    }
    pub fn tag(&mut self, t: &str) -> &mut Self {
        self.0.extend(t.as_bytes());
        self
    }
    pub fn len(&self) -> usize {
        self.0.len()
    }
}

/// Assemble an sfnt from tables (written in the given order, with sorted
/// table records unless `unsorted`).
pub fn sfnt(magic: u32, tables: &[(&str, Vec<u8>)]) -> Vec<u8> {
    let mut tables = tables.to_vec();
    tables.sort_by(|a, b| a.0.cmp(b.0));
    sfnt_raw(magic, &tables, 0)
}

/// Assemble an sfnt whose table offsets are relative to `base` (for
/// collections).
pub fn sfnt_raw(magic: u32, tables: &[(&str, Vec<u8>)], base: usize) -> Vec<u8> {
    let n = tables.len() as u16;
    let mut w = W::new();
    w.u32(magic).u16(n).u16(0).u16(0).u16(0);
    let mut offset = base + 12 + 16 * tables.len();
    for (tag, data) in tables {
        let mut sum = 0u32;
        for chunk in data.chunks(4) {
            let mut b = [0u8; 4];
            b[..chunk.len()].copy_from_slice(chunk);
            sum = sum.wrapping_add(u32::from_be_bytes(b));
        }
        w.tag(tag).u32(sum).u32(offset as u32).u32(data.len() as u32);
        offset += (data.len() + 3) / 4 * 4;
    }
    for (_, data) in tables {
        w.bytes(data);
        while w.len() % 4 != 0 {
            w.u8(0);
        }
    }
    w.0
}

/// A font collection of the given fonts (each given as its tables).
pub fn ttc(fonts: &[(u32, Vec<(&str, Vec<u8>)>)]) -> Vec<u8> {
    let header_len = 12 + 4 * fonts.len();
    let mut out = W::new();
    out.tag("ttcf").u32(0x00010000).u32(fonts.len() as u32);
    // Compute the offsets of the font directories.
    let mut bodies = Vec::new();
    let mut offset = header_len;
    for (magic, tables) in fonts {
        let mut tables = tables.clone();
        tables.sort_by(|a, b| a.0.cmp(b.0));
        let body = sfnt_raw(*magic, &tables, offset);
        out.u32(offset as u32);
        offset += body.len();
        bodies.push(body);
    }
    for b in bodies {
        out.bytes(&b);
    }
    out.0
}

// --- TrueType ---

pub struct Point(pub i16, pub i16, pub bool);

/// Encode a simple glyph with the given contours (points are absolute),
/// instructions and the flags' optional bits (`OVERLAP_SIMPLE` on the first
/// flag). Repeats are used for runs of equal flags when `repeat` is set.
pub fn simple_glyph(contours: &[Vec<Point>], instructions: &[u8], overlap: bool, repeat: bool) -> Vec<u8> {
    let pts: Vec<&Point> = contours.iter().flatten().collect();
    let (mut x0, mut y0, mut x1, mut y1) = (i16::MAX, i16::MAX, i16::MIN, i16::MIN);
    for p in &pts {
        x0 = x0.min(p.0);
        y0 = y0.min(p.1);
        x1 = x1.max(p.0);
        y1 = y1.max(p.1);
    }
    if pts.is_empty() {
        (x0, y0, x1, y1) = (0, 0, 0, 0);
    }
    let mut w = W::new();
    w.i16(contours.len() as i16).i16(x0).i16(y0).i16(x1).i16(y1);
    let mut end = 0i32 - 1;
    for c in contours {
        end += c.len() as i32;
        w.u16(end as u16);
    }
    w.u16(instructions.len() as u16).bytes(instructions);
    let mut flags = Vec::new();
    let mut xs = W::new();
    let mut ys = W::new();
    let (mut lx, mut ly) = (0i16, 0i16);
    for (i, p) in pts.iter().enumerate() {
        let mut f = if p.2 { 1u8 } else { 0 };
        if i == 0 && overlap {
            f |= 0x40;
        }
        let dx = p.0 - lx;
        let dy = p.1 - ly;
        lx = p.0;
        ly = p.1;
        if dx == 0 {
            f |= 0x10;
        } else if dx.unsigned_abs() <= 255 {
            f |= 0x02;
            if dx > 0 {
                f |= 0x10;
            }
            xs.u8(dx.unsigned_abs() as u8);
        } else {
            xs.i16(dx);
        }
        if dy == 0 {
            f |= 0x20;
        } else if dy.unsigned_abs() <= 255 {
            f |= 0x04;
            if dy > 0 {
                f |= 0x20;
            }
            ys.u8(dy.unsigned_abs() as u8);
        } else {
            ys.i16(dy);
        }
        flags.push(f);
    }
    let mut i = 0;
    while i < flags.len() {
        let f = flags[i];
        let mut run = 1;
        while repeat && i + run < flags.len() && flags[i + run] == f && run < 256 {
            run += 1;
        }
        if run > 1 {
            w.u8(f | 0x08).u8((run - 1) as u8);
        } else {
            w.u8(f);
        }
        i += run;
    }
    w.bytes(&xs.0).bytes(&ys.0);
    w.0
}

pub struct Comp {
    pub flags: u16,
    pub glyph: u16,
    pub args: (i16, i16),
    pub xform: Vec<i16>,
}

/// Encode a composite glyph.
pub fn composite_glyph(bbox: (i16, i16, i16, i16), comps: &[Comp], instructions: Option<&[u8]>) -> Vec<u8> {
    let mut w = W::new();
    w.i16(-1).i16(bbox.0).i16(bbox.1).i16(bbox.2).i16(bbox.3);
    for (i, c) in comps.iter().enumerate() {
        let mut flags = c.flags;
        if i + 1 < comps.len() {
            flags |= 0x0020;
        }
        if i + 1 == comps.len() && instructions.is_some() {
            flags |= 0x0100;
        }
        w.u16(flags).u16(c.glyph);
        if flags & 1 != 0 {
            w.i16(c.args.0).i16(c.args.1);
        } else {
            w.u8(c.args.0 as u8).u8(c.args.1 as u8);
        }
        for v in &c.xform {
            w.i16(*v);
        }
    }
    if let Some(ins) = instructions {
        w.u16(ins.len() as u16).bytes(ins);
    }
    w.0
}

pub fn glyf_loca(glyphs: &[Vec<u8>], long: bool) -> (Vec<u8>, Vec<u8>) {
    let mut glyf = W::new();
    let mut loca = W::new();
    for g in glyphs {
        if long {
            loca.u32(glyf.len() as u32);
        } else {
            loca.u16((glyf.len() / 2) as u16);
        }
        glyf.bytes(g);
        while glyf.len() % 2 != 0 {
            glyf.u8(0);
        }
    }
    if long {
        loca.u32(glyf.len() as u32);
    } else {
        loca.u16((glyf.len() / 2) as u16);
    }
    (glyf.0, loca.0)
}

pub fn head(upem: u16, bbox: (i16, i16, i16, i16), long_loca: bool) -> Vec<u8> {
    let mut w = W::new();
    w.u32(0x00010000).u32(0x00018000).u32(0x12345678).u32(0x5F0F3CF5);
    w.u16(0x000B).u16(upem);
    w.bytes(&[0; 16]); // created, modified
    w.i16(bbox.0).i16(bbox.1).i16(bbox.2).i16(bbox.3);
    w.u16(0).u16(8).i16(2).i16(long_loca as i16).i16(0);
    w.0
}

pub fn hhea(num_h_metrics: u16) -> Vec<u8> {
    let mut w = W::new();
    w.u32(0x00010000).i16(900).i16(-250).i16(50).u16(1200);
    w.i16(-20).i16(10).i16(1100).i16(1).i16(0).i16(0);
    w.bytes(&[0; 8]).i16(0).u16(num_h_metrics);
    w.0
}

pub fn hmtx(metrics: &[(u16, i16)], num_h_metrics: usize) -> Vec<u8> {
    let mut w = W::new();
    for (i, m) in metrics.iter().enumerate() {
        if i < num_h_metrics {
            w.u16(m.0);
        }
        w.i16(m.1);
    }
    w.0
}

pub fn maxp_v1(num_glyphs: u16) -> Vec<u8> {
    let mut w = W::new();
    w.u32(0x00010000).u16(num_glyphs);
    for v in [40u16, 4, 60, 6, 2, 0, 8, 2, 0, 64, 32, 3, 2] {
        w.u16(v);
    }
    w.0
}

pub fn maxp_v05(num_glyphs: u16) -> Vec<u8> {
    let mut w = W::new();
    w.u32(0x00005000).u16(num_glyphs);
    w.0
}

/// A version 0 name table with the given records (platform, encoding,
/// language, name ID, string bytes).
pub fn name(records: &[(u16, u16, u16, u16, Vec<u8>)]) -> Vec<u8> {
    let mut w = W::new();
    let mut storage = W::new();
    w.u16(0).u16(records.len() as u16).u16((6 + 12 * records.len()) as u16);
    for r in records {
        w.u16(r.0).u16(r.1).u16(r.2).u16(r.3).u16(r.4.len() as u16).u16(storage.len() as u16);
        storage.bytes(&r.4);
    }
    w.bytes(&storage.0);
    w.0
}

pub fn utf16(s: &str) -> Vec<u8> {
    s.encode_utf16().flat_map(|c| c.to_be_bytes()).collect()
}

pub fn post_v2(indices: &[u16], names: &[&str]) -> Vec<u8> {
    let mut w = W::new();
    w.u32(0x00020000).i32(-12 << 16).i16(-100).i16(50).u32(0);
    w.bytes(&[0; 16]);
    w.u16(indices.len() as u16);
    for i in indices {
        w.u16(*i);
    }
    for n in names {
        w.u8(n.len() as u8).bytes(n.as_bytes());
    }
    w.0
}

pub fn post_v3() -> Vec<u8> {
    let mut w = W::new();
    w.u32(0x00030000).i32(0).i16(-100).i16(50).u32(1);
    w.bytes(&[0; 16]);
    w.0
}

pub fn os2() -> Vec<u8> {
    let mut w = W::new();
    w.u16(4).i16(500).u16(400).u16(5).u16(8);
    w.bytes(&[0; 52]);
    w.tag("TEST").u16(0x40).u16(0x20).u16(0x7E);
    w.i16(800).i16(-200).i16(100).u16(900).u16(250);
    w.u32(1).u32(0).i16(500).i16(700).u16(0).u16(0x20).u16(3);
    w.0
}

pub fn cmap() -> Vec<u8> {
    let mut w = W::new();
    w.u16(0).u16(1).u16(3).u16(1).u32(12);
    // format 4 with one segment mapping 0x41.. to glyphs 1..
    w.u16(4).u16(32).u16(0).u16(4).u16(4).u16(1).u16(0);
    w.u16(0x46).u16(0xFFFF).u16(0).u16(0x41).u16(0xFFFF);
    w.i16(-0x40).i16(1).u16(0).u16(0);
    w.0
}

/// The glyphs of the TrueType fixture font.
pub fn tt_glyphs() -> Vec<Vec<u8>> {
    use Point as P;
    let notdef = simple_glyph(
        &[vec![P(50, 0, true), P(450, 0, true), P(450, 700, true), P(50, 700, true)],
          vec![P(100, 50, true), P(100, 650, true), P(400, 650, true), P(400, 50, true)]],
        &[], false, false);
    // Mixed on/off curve points, short and long deltas, repeated flags
    // and instructions.
    let a = simple_glyph(
        &[vec![P(60, 0, true), P(300, -10, false), P(520, 0, true), P(520, 300, false),
               P(520, 480, true), P(300, 520, false), P(80, 480, true), P(80, 240, true),
               P(80, 230, true), P(80, 220, true)],
          vec![P(200, 200, true), P(400, 200, true), P(400, 300, true)]],
        &[0xB0, 0x01, 0x2C], false, true);
    // All points off curve.
    let o = simple_glyph(
        &[vec![P(100, 300, false), P(300, 600, false), P(500, 300, false), P(300, 0, false)]],
        &[], true, false);
    let comp1 = composite_glyph((60, -10, 520, 520), &[
        Comp { flags: 0x0001 | 0x0002 | 0x0200, glyph: 1, args: (0, 0), xform: vec![] },
    ], None);
    let comp2 = composite_glyph((0, -10, 1100, 900), &[
        Comp { flags: 0x0002 | 0x0008, glyph: 2, args: (20, -5), xform: vec![0x3000] },
        Comp { flags: 0x0001 | 0x0002 | 0x0040 | 0x0800, glyph: 3, args: (500, 100), xform: vec![0x4000, 0x2000] },
    ], Some(&[0x40, 0x01, 0x05]));
    let comp3 = composite_glyph((0, 0, 900, 900), &[
        Comp { flags: 0x0002 | 0x0004, glyph: 1, args: (0, 0), xform: vec![] },
        // A 2x2 transform and a point anchor (point 2 of glyph 1 onto point 0
        // of glyph 2).
        Comp { flags: 0x0080, glyph: 2, args: (2, 0), xform: vec![0x4000, 0x0800, -0x0800, 0x4000] },
    ], None);
    let empty = Vec::new();
    // A one point contour and a contour starting off curve.
    let odd = simple_glyph(
        &[vec![P(10, 10, true)],
          vec![P(100, 100, false), P(300, 100, true), P(300, 300, false), P(100, 300, true)]],
        &[], false, false);
    let big = simple_glyph(
        &[vec![P(-2000, -1500, true), P(3000, -1500, true), P(3000, 2500, false), P(-2000, 2500, true)]],
        &[0x00; 3], false, false);
    // References glyph 10 (a higher ID) and the empty glyph 6.
    let comp4 = composite_glyph((0, 0, 600, 600), &[
        Comp { flags: 0x0002, glyph: 10, args: (10, 10), xform: vec![] },
        Comp { flags: 0x0002, glyph: 6, args: (0, 0), xform: vec![] },
    ], None);
    let ten = simple_glyph(&[vec![P(0, 0, true), P(600, 0, true), P(300, 600, true)]], &[], false, false);
    let eleven = simple_glyph(&[vec![P(0, 0, true), P(100, 0, true), P(100, 100, true)]], &[], false, false);
    vec![notdef, a, o, comp1, comp2, comp3, empty, odd, big, comp4, ten, eleven]
}

pub fn tt_metrics() -> Vec<(u16, i16)> {
    vec![(500, 50), (580, 60), (600, 100), (580, 60), (1100, 0), (900, 0), (250, 0), (400, 10), (1000, -2000), (600, 0), (600, 0), (600, 0)]
}

pub fn tt_name() -> Vec<u8> {
    name(&[
        (0, 3, 0, 1, utf16("Test Sans")),
        (1, 0, 0, 1, b"Test Sans".to_vec()),
        (1, 0, 0, 6, b"TestSans-Regular".to_vec()),
        (3, 1, 0x409, 0, utf16("Copyright (c) Nobody")),
        (3, 1, 0x409, 1, utf16("Test Sans")),
        (3, 1, 0x409, 2, utf16("Regular")),
        (3, 1, 0x409, 4, utf16("Test Sans Regular")),
        (3, 1, 0x409, 6, utf16("TestSans-Regular")),
        (3, 1, 0x409, 10, utf16("A description that is dropped")),
        (3, 1, 0x407, 13, utf16("License")),
        (3, 1, 0x409, 16, utf16("Test")),
        (3, 10, 0x409, 14, utf16("https://example.com")),
        (3, 2, 0x409, 3, utf16("dropped")),
    ])
}

pub fn tt_tables(long_loca: bool, post: Vec<u8>) -> Vec<(&'static str, Vec<u8>)> {
    let glyphs = tt_glyphs();
    let (glyf, loca) = glyf_loca(&glyphs, long_loca);
    let metrics = tt_metrics();
    vec![
        ("head", head(1000, (-2000, -1500, 3000, 2500), long_loca)),
        ("hhea", hhea(9)),
        ("hmtx", hmtx(&metrics, 9)),
        ("maxp", maxp_v1(glyphs.len() as u16)),
        ("glyf", glyf),
        ("loca", loca),
        ("name", tt_name()),
        ("post", post),
        ("OS/2", os2()),
        ("cmap", cmap()),
        ("cvt ", vec![0, 10, 0, 20, 0xFF, 0xF0]),
        ("fpgm", vec![0xB0, 0x00, 0x2C, 0x2D]),
        ("prep", vec![0xB8, 0x01, 0xFF, 0x85]),
        ("gasp", vec![0, 1, 0, 1, 0xFF, 0xFF, 0, 15]),
    ]
}

pub fn tt_post() -> Vec<u8> {
    post_v2(&[0, 258, 259, 36, 260, 261, 3, 262, 300, 263, 68, 264],
            &["a.alt", "o.round", "comp.two", "comp.three", "odd", "comp.four", "ten"])
}

// --- CFF ---

/// A CFF DICT/charstring number.
pub fn num(v: i32) -> Vec<u8> {
    if (-107..=107).contains(&v) {
        vec![(v + 139) as u8]
    } else if (108..=1131).contains(&v) {
        let t = v - 108;
        vec![(t / 256 + 247) as u8, (t % 256) as u8]
    } else if (-1131..=-108).contains(&v) {
        let t = -v - 108;
        vec![(t / 256 + 251) as u8, (t % 256) as u8]
    } else if (-32768..=32767).contains(&v) {
        let b = (v as i16).to_be_bytes();
        vec![28, b[0], b[1]]
    } else {
        let b = v.to_be_bytes();
        vec![29, b[0], b[1], b[2], b[3]]
    }
}

pub fn num5(v: i32) -> Vec<u8> {
    let b = v.to_be_bytes();
    vec![29, b[0], b[1], b[2], b[3]]
}

/// A real number in a DICT (from its nibble string).
pub fn real(s: &str) -> Vec<u8> {
    let mut nibbles = Vec::new();
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '0'..='9' => nibbles.push(c as u8 - b'0'),
            '.' => nibbles.push(0xA),
            'E' => {
                if chars.peek() == Some(&'-') {
                    chars.next();
                    nibbles.push(0xC);
                } else {
                    nibbles.push(0xB);
                }
            }
            '-' => nibbles.push(0xE),
            _ => panic!(),
        }
    }
    nibbles.push(0xF);
    if nibbles.len() % 2 != 0 {
        nibbles.push(0xF);
    }
    let mut out = vec![30];
    for p in nibbles.chunks(2) {
        out.push((p[0] << 4) | p[1]);
    }
    out
}

/// A charstring 16.16 fixed number.
pub fn fixed(v: f64) -> Vec<u8> {
    let b = ((v * 65536.0) as i32).to_be_bytes();
    vec![255, b[0], b[1], b[2], b[3]]
}

pub fn op(o: u8) -> Vec<u8> {
    vec![o]
}

pub fn op2(o: u8) -> Vec<u8> {
    vec![12, o]
}

/// A CFF (count u16) or CFF2 (count u32) INDEX with the smallest offset
/// size, or a forced one.
pub fn index(items: &[Vec<u8>], cff2: bool, off_size: Option<u8>) -> Vec<u8> {
    let mut w = W::new();
    if cff2 {
        w.u32(items.len() as u32);
    } else {
        w.u16(items.len() as u16);
    }
    if items.is_empty() {
        return w.0;
    }
    let total: usize = items.iter().map(|i| i.len()).sum::<usize>() + 1;
    let size = off_size.unwrap_or(if total <= 0xFF { 1 } else if total <= 0xFFFF { 2 } else if total <= 0xFFFFFF { 3 } else { 4 });
    w.u8(size);
    let mut off = 1u32;
    let put = |w: &mut W, v: u32| match size {
        1 => { w.u8(v as u8); }
        2 => { w.u16(v as u16); }
        3 => { w.u24(v); }
        _ => { w.u32(v); }
    };
    put(&mut w, off);
    for i in items {
        off += i.len() as u32;
        put(&mut w, off);
    }
    for i in items {
        w.bytes(i);
    }
    w.0
}

pub fn cat(parts: &[Vec<u8>]) -> Vec<u8> {
    parts.concat()
}

/// Lay out a CFF table: header, names, top dict (built by `top` given the
/// offsets of the trailing data), strings, gsubrs and a list of trailing
/// blocks. `top` returns the Top DICT for the offsets of the blocks; its
/// size must not depend on them (use `num5`).
pub fn cff_table(
    names: &[&str],
    strings: &[&str],
    gsubrs: &[Vec<u8>],
    blocks: &[Vec<u8>],
    top: impl Fn(&[usize]) -> Vec<u8>,
) -> Vec<u8> {
    let names = index(&names.iter().map(|n| n.as_bytes().to_vec()).collect::<Vec<_>>(), false, None);
    let strings = index(&strings.iter().map(|n| n.as_bytes().to_vec()).collect::<Vec<_>>(), false, None);
    let gsubrs = index(gsubrs, false, None);
    let dummy = top(&vec![0; blocks.len()]);
    let top_index_len = index(&[dummy], false, None).len();
    let mut offsets = Vec::new();
    let mut at = 4 + names.len() + top_index_len + strings.len() + gsubrs.len();
    for b in blocks {
        offsets.push(at);
        at += b.len();
    }
    let top_index = index(&[top(&offsets)], false, None);
    assert_eq!(top_index.len(), top_index_len);
    let mut w = W::new();
    w.bytes(&[1, 0, 4, 1]).bytes(&names).bytes(&top_index).bytes(&strings).bytes(&gsubrs);
    for b in blocks {
        w.bytes(b);
    }
    w.0
}

/// The name-keyed CFF fixture: 8 glyphs exercising hints, masks, flex,
/// subroutines and number encodings; glyph 6 uses `seac` (unsupported) and
/// glyph 7 an invalid operator.
pub fn cff_name_keyed(with_matrix: bool) -> Vec<u8> {
    let rect = |w: i32, x: i32, y: i32, dx: i32, dy: i32| {
        cat(&[num(w), num(x), num(y), op(21), num(dx), op(6), num(dy), op(7), num(-dx), op(6), op(14)])
    };
    let charstrings = vec![
        rect(500, 50, 0, 400, 700),
        // hstemhm vstemhm, hintmask (2 bytes for 9 stems), curves, local
        // subr call, cntrmask.
        cat(&[num(580), num(0), num(20), num(300), num(30), num(150), num(20), op(18),
              num(60), num(40), num(200), num(40), num(100), num(20), num(50), num(10), num(30), num(5), op(23),
              op(19), vec![0xF0], num(60), num(0), op(21),
              num(100), num(-10), num(120), num(10), num(100), num(100), op(8),
              op(20), vec![0xC0],
              num(0 - 107), op(10),
              num(200), num(100), num(-50), num(80), num(0), num(120), op(31),
              op(14)]),
        // hstem vstem, a hintmask with implicit vstems, flex, global subr.
        cat(&[num(20), num(30), op(1), num(10), num(15), op(3),
              num(100), num(20), op(19), vec![0xE0],
              num(0), num(0), op(21),
              num(10), num(20), num(30), num(40), num(50), num(60), num(70), num(80), num(90), num(100), num(110), num(120), num(50), op2(35),
              num(1 - 107), op(29),
              op(14)]),
        // Fixed and long numbers, hflex, hflex1, flex1.
        cat(&[fixed(600.5), fixed(12.25), fixed(-3.5), op(21),
              num(1000), num(-1000), num(30000), num(-30000), num(200), num(300), num(400), op2(34),
              num(5), num(6), num(7), num(8), num(9), num(10), num(11), num(12), num(13), op2(36),
              num(1), num(2), num(3), num(4), num(5), num(6), num(7), num(8), num(9), num(10), num(11), op2(37),
              fixed(-20000.75), num(30), op(5),
              op(14)]),
        // Nested subroutines ending the glyph.
        cat(&[num(400), num(10), num(10), op(21), num(2 - 107), op(10)]),
        // A width-only glyph and vv/hh/vh curves.
        cat(&[num(250), num(0), num(0), op(21), num(10), num(20), num(30), num(40), op(26),
              num(5), num(10), num(20), num(30), num(40), op(27), num(1), num(2), num(3), num(4), op(30),
              num(1), num(2), num(3), num(4), num(5), num(6), num(7), num(8), op(24),
              num(1), num(2), num(3), num(4), num(5), num(6), num(7), num(8), op(25),
              op(14)]),
        // seac: base glyph 65, accent 66.
        cat(&[num(400), num(0), num(0), num(65), num(66), op(14)]),
        // An invalid operator (13).
        cat(&[num(400), num(0), op(13), op(14)]),
    ];
    let local_subrs = vec![
        // 0: a curve and return.
        cat(&[num(10), num(20), num(30), num(40), num(50), num(60), op(8), op(11)]),
        // 1: lines.
        cat(&[num(10), num(20), op(5), op(11)]),
        // 2: calls subr 1 and ends the glyph.
        cat(&[num(1 - 107), op(10), num(30), op(6), op(14)]),
    ];
    let gsubrs = vec![
        cat(&[op(11)]),
        cat(&[num(100), num(0), op(5), num(0), num(100), op(5), op(11)]),
    ];
    let subrs_index = index(&local_subrs, false, None);
    let private_body = |subrs_offset: i32| {
        cat(&[num(-20), num(20), num(480), num(20), num(200), num(15), op(6), // BlueValues
              num(-250), num(10), op(7), // OtherBlues
              real(".039625"), op2(9), // BlueScale
              num(7), op2(10), // BlueShift
              num(1), op2(11), // BlueFuzz
              num(68), op(10), // StdHW
              num(88), op(11), // StdVW
              num(68), num(10), op2(12), // StemSnapH
              num(1), op2(14), // ForceBold
              real("2.5E-1"), op2(15), // (deprecated) ForceBoldThreshold
              num(500), op(20), // defaultWidthX
              num(400), op(21), // nominalWidthX
              num5(subrs_offset), op(19)])
    };
    let private_len = private_body(0).len();
    let private = private_body(private_len as i32);
    let charset = {
        let mut w = W::new();
        w.u8(0);
        for sid in [391u16, 392, 393, 394, 395, 396, 397] {
            w.u16(sid);
        }
        w.0
    };
    let charstrings = index(&charstrings, false, Some(2));
    let blocks = vec![charset, private.clone(), subrs_index, charstrings];
    let strings = ["a", "b", "c", "d", "e", "f", "g", "Version 1.0", "Copyright Nobody", "Notice Nobody", "Test Serif"];
    cff_table(&["TestSerif-Regular"], &strings, &gsubrs, &blocks, |o| {
        let mut d = cat(&[num(398), op(0), // version
                          num(400), op(1), // Notice
                          num(399), op2(0), // Copyright
                          num(401), op(2), // FullName
                          num(401), op(3), // FamilyName
                          num(388), op(4), // Weight (standard)
                          num(-50), num(-200), num(1100), num(900), op(5)]);
        if with_matrix {
            d.extend(cat(&[real("0.0005"), num(0), real("0.0001"), real("0.0005"), num(0), num(0), op2(7)]));
        }
        d.extend(cat(&[num5(o[0] as i32), op(15), num5(o[3] as i32), op(17),
                       num5(private.len() as i32), num5(o[1] as i32), op(18)]));
        d
    })
}

/// The CID-keyed CFF fixture: 10 glyphs in three font DICTs selected with
/// FDSelect format 3 (or 0), 1300 global subroutines (bias 1131) and local
/// subroutines.
pub fn cff_cid_keyed(fd_select_format0: bool, top_matrix: bool) -> Vec<u8> {
    let n = 10;
    let fd_of = |g: usize| if fd_select_format0 { [0usize, 1, 2, 1, 0, 2, 2, 1, 0, 1][g] } else { [0usize, 0, 0, 1, 1, 1, 2, 2, 1, 1][g] };
    let mut charstrings = Vec::new();
    for g in 0..n {
        let w = 500 + 10 * g as i32;
        // (FD 2 has no local subroutines.)
        let kind = if g % 4 == 2 && fd_of(g) == 2 { 3 } else { g % 4 };
        let cs = match kind {
            0 => cat(&[num(w), num(10), num(10), op(21), num(100 + g as i32), op(6), num(200), op(7), op(14)]),
            1 => cat(&[num(w), num(0), num(0), op(21), num(1200 - 1131), op(29), op(14)]),
            2 => cat(&[num(w), num(5), num(5), op(21), num(0 - 107), op(10), op(14)]),
            _ => cat(&[num(w), op(14)]),
        };
        charstrings.push(cs);
    }
    let mut gsubrs = vec![vec![11u8]; 1300];
    gsubrs[1200] = cat(&[num(10), num(20), op(5), num(30), op(6), op(11)]);
    let fd_subrs = index(&[cat(&[num(1), num(2), num(3), num(4), num(5), num(6), op(8), op(11)])], false, None);
    // Font DICTs: FD 0 and FD 1 have local subroutines.
    let private = |subrs: bool| {
        let body = |off: i32| {
            let mut v = cat(&[num(-15), num(15), num(500), num(15), op(6), num(70), op(10), num(0), op(20), num(0), op(21)]);
            if subrs {
                v.extend(cat(&[num5(off), op(19)]));
            }
            v
        };
        let len = body(0).len();
        body(len as i32)
    };
    let privates = [private(true), private(true), private(false)];
    let fd_select = if fd_select_format0 {
        let mut w = W::new();
        w.u8(0);
        for g in 0..n {
            w.u8([0u8, 1, 2, 1, 0, 2, 2, 1, 0, 1][g]);
        }
        w.0
    } else {
        let mut w = W::new();
        w.u8(3).u16(4).u16(0).u8(0).u16(3).u8(1).u16(6).u8(2).u16(8).u8(1).u16(n as u16);
        w.0
    };
    let charset = {
        let mut w = W::new();
        w.u8(2).u16(1000).u16((n - 2) as u16);
        w.0
    };
    let charstrings_index = index(&charstrings, false, None);
    // Blocks: charset, fdselect, charstrings, privates+subrs (each private
    // followed by its subrs), fdarray (built from the offsets).
    let mut private_blocks = Vec::new();
    for (i, p) in privates.iter().enumerate() {
        let mut b = p.clone();
        if i < 2 {
            b.extend(&fd_subrs);
        }
        private_blocks.push(b);
    }
    let fd_array = |offsets: &[usize]| {
        let mut dicts = Vec::new();
        for i in 0..3 {
            let mut d = cat(&[num(392 + i as i32 + 1), op2(38)]); // FontName
            if !top_matrix || i == 1 {
                d.extend(cat(&[real("0.001"), num(0), num(0), real("0.001"), num(0), num(0), op2(7)]));
            }
            d.extend(cat(&[num5(privates[i].len() as i32), num5(offsets[i] as i32), op(18)]));
            dicts.push(d);
        }
        index(&dicts, false, None)
    };
    let fd_array_len = fd_array(&[0, 0, 0]).len();
    let blocks_fixed = vec![charset, fd_select, charstrings_index];
    let strings = ["Adobe", "Identity", "TestCID-FD0", "TestCID-FD1", "TestCID-FD2", "Copyright CID"];
    // The FDArray is the last block; its content depends on the private
    // offsets, so it is laid out in two passes.
    let names = ["TestCID-Regular"];
    let build = |priv_offsets: &[usize]| {
        let mut blocks = blocks_fixed.clone();
        for b in &private_blocks {
            blocks.push(b.clone());
        }
        blocks.push(fd_array(priv_offsets));
        cff_table(&names, &strings, &gsubrs, &blocks, |o| {
            let mut d = cat(&[num(391), num(392), num(0), op2(30), // ROS
                              num(396), op2(0), // Copyright
                              num(0), num(-200), num(1000), num(900), op(5)]);
            if top_matrix {
                d.extend(cat(&[real("0.002"), num(0), num(0), real("0.002"), num(0), num(0), op2(7)]));
            }
            d.extend(cat(&[num(1100), op2(34), // CIDCount
                           num5(o[0] as i32), op(15), num5(o[1] as i32), op2(37),
                           num5(o[2] as i32), op(17), num5(o[6] as i32), op2(36)]));
            d
        })
    };
    let _ = fd_array_len;
    // First pass to learn the private offsets.
    let first = build(&[0, 0, 0]);
    let at = |data: &[u8], needle: &[u8]| data.windows(needle.len()).position(|w| w == needle).unwrap();
    let offs: Vec<usize> = private_blocks.iter().map(|b| at(&first, b)).collect();
    build(&offs)
}

// --- variations ---

pub fn fvar(axes: &[(&str, f64, f64, f64)]) -> Vec<u8> {
    let mut w = W::new();
    w.u32(0x00010000).u16(16).u16(2).u16(axes.len() as u16).u16(20).u16(1).u16((axes.len() * 4 + 4) as u16);
    for a in axes {
        w.tag(a.0).i32((a.1 * 65536.0) as i32).i32((a.2 * 65536.0) as i32).i32((a.3 * 65536.0) as i32).u16(0).u16(256);
    }
    // One named instance.
    w.u16(257).u16(0);
    for a in axes {
        w.i32((a.2 * 65536.0) as i32);
    }
    w.0
}

pub fn avar(maps: &[Vec<(f32, f32)>]) -> Vec<u8> {
    let mut w = W::new();
    w.u32(0x00010000).u16(0).u16(maps.len() as u16);
    for m in maps {
        w.u16(m.len() as u16);
        for (a, b) in m {
            w.i16((a * 16384.0).round() as i16).i16((b * 16384.0).round() as i16);
        }
    }
    w.0
}

/// Packed point numbers.
pub fn packed_points(points: Option<&[u16]>) -> Vec<u8> {
    let mut w = W::new();
    match points {
        None => {
            w.u8(0);
        }
        Some(p) => {
            if p.len() < 128 {
                w.u8(p.len() as u8);
            } else {
                w.u16(0x8000 | p.len() as u16);
            }
            // runs of up to 128, words if any value > 255
            let mut last = 0u16;
            let deltas: Vec<u16> = p.iter().map(|v| { let d = v - last; last = *v; d }).collect();
            for chunk in deltas.chunks(100) {
                let words = chunk.iter().any(|d| *d > 255);
                w.u8((chunk.len() as u8 - 1) | if words { 0x80 } else { 0 });
                for d in chunk {
                    if words { w.u16(*d); } else { w.u8(*d as u8); }
                }
            }
        }
    }
    w.0
}

/// Packed deltas (zero runs, bytes, words or 32-bit values).
pub fn packed_deltas(deltas: &[i32]) -> Vec<u8> {
    let mut w = W::new();
    let mut i = 0;
    while i < deltas.len() {
        let d = deltas[i];
        let kind = if d == 0 { 0 } else if (-128..=127).contains(&d) { 1 } else if (-32768..=32767).contains(&d) { 2 } else { 4 };
        let mut j = i + 1;
        while j < deltas.len() && j - i < 64 {
            let e = deltas[j];
            let k = if e == 0 { 0 } else if (-128..=127).contains(&e) { 1 } else if (-32768..=32767).contains(&e) { 2 } else { 4 };
            if k != kind {
                break;
            }
            j += 1;
        }
        let n = (j - i) as u8 - 1;
        match kind {
            0 => { w.u8(0x80 | n); }
            1 => { w.u8(n); for v in &deltas[i..j] { w.u8(*v as i8 as u8); } }
            2 => { w.u8(0x40 | n); for v in &deltas[i..j] { w.i16(*v as i16); } }
            _ => { w.u8(0xC0 | n); for v in &deltas[i..j] { w.i32(*v); } }
        }
        i = j;
    }
    w.0
}

pub struct Tuple {
    /// Shared tuple index or an embedded peak.
    pub peak: Result<u16, Vec<f32>>,
    pub intermediate: Option<(Vec<f32>, Vec<f32>)>,
    /// Private point numbers (`Some(None)` for all points).
    pub points: Option<Option<Vec<u16>>>,
    pub xs: Vec<i32>,
    pub ys: Vec<i32>,
}

fn f2(v: f32) -> i16 {
    (v * 16384.0).round() as i16
}

/// The glyph variation data of one glyph.
pub fn glyph_variation_data(shared_points: Option<Option<Vec<u16>>>, tuples: &[Tuple]) -> Vec<u8> {
    let mut headers = W::new();
    let mut data = W::new();
    if let Some(p) = &shared_points {
        data.bytes(&packed_points(p.as_deref()));
    }
    for t in tuples {
        let mut body = W::new();
        if let Some(p) = &t.points {
            body.bytes(&packed_points(p.as_deref()));
        }
        body.bytes(&packed_deltas(&t.xs)).bytes(&packed_deltas(&t.ys));
        let mut index: u16 = match &t.peak { Ok(i) => *i, Err(_) => 0x8000 };
        if t.intermediate.is_some() {
            index |= 0x4000;
        }
        if t.points.is_some() {
            index |= 0x2000;
        }
        headers.u16(body.len() as u16).u16(index);
        if let Err(peak) = &t.peak {
            for v in peak {
                headers.i16(f2(*v));
            }
        }
        if let Some((s, e)) = &t.intermediate {
            for v in s {
                headers.i16(f2(*v));
            }
            for v in e {
                headers.i16(f2(*v));
            }
        }
        data.bytes(&body.0);
    }
    let mut w = W::new();
    let count = tuples.len() as u16 | if shared_points.is_some() { 0x8000 } else { 0 };
    w.u16(count).u16((4 + headers.len()) as u16).bytes(&headers.0).bytes(&data.0);
    if w.len() % 2 != 0 {
        w.u8(0);
    }
    w.0
}

pub fn gvar(axis_count: u16, shared: &[Vec<f32>], glyphs: &[Vec<u8>], long: bool) -> Vec<u8> {
    let mut w = W::new();
    let n = glyphs.len();
    let offsets_len = (n + 1) * if long { 4 } else { 2 };
    let shared_at = 20 + offsets_len;
    let data_at = shared_at + shared.len() * 2 * axis_count as usize;
    w.u32(0x00010000).u16(axis_count).u16(shared.len() as u16).u32(shared_at as u32);
    w.u16(n as u16).u16(long as u16).u32(data_at as u32);
    let mut off = 0usize;
    let put = |w: &mut W, off: usize| if long { w.u32(off as u32); } else { w.u16((off / 2) as u16); };
    for g in glyphs {
        put(&mut w, off);
        off += g.len();
    }
    put(&mut w, off);
    for t in shared {
        for v in t {
            w.i16(f2(*v));
        }
    }
    for g in glyphs {
        w.bytes(g);
    }
    w.0
}

/// An item variation store with the given regions (per axis: start, peak,
/// end) and item variation data (region indices, delta rows).
pub fn item_variation_store(axis_count: u16, regions: &[Vec<(f32, f32, f32)>], datas: &[(Vec<u16>, Vec<Vec<i32>>)]) -> Vec<u8> {
    let mut region_list = W::new();
    region_list.u16(axis_count).u16(regions.len() as u16);
    for r in regions {
        for (s, p, e) in r {
            region_list.i16(f2(*s)).i16(f2(*p)).i16(f2(*e));
        }
    }
    let mut data_tables = Vec::new();
    for (indices, rows) in datas {
        let mut d = W::new();
        let words = rows.iter().flatten().any(|v| !(-128..=127).contains(v));
        let word_count = if words { indices.len() as u16 } else { 0 };
        d.u16(rows.len() as u16).u16(word_count).u16(indices.len() as u16);
        for i in indices {
            d.u16(*i);
        }
        for row in rows {
            for v in row {
                if words { d.i16(*v as i16); } else { d.u8(*v as i8 as u8); }
            }
        }
        data_tables.push(d.0);
    }
    let mut w = W::new();
    let header = 8 + 4 * datas.len();
    w.u16(1).u32(header as u32).u16(datas.len() as u16);
    let mut off = header + region_list.len();
    for d in &data_tables {
        w.u32(off as u32);
        off += d.len();
    }
    w.bytes(&region_list.0);
    for d in &data_tables {
        w.bytes(d);
    }
    w.0
}

pub fn hvar(ivs: &[u8], advance_map: Option<&[u16]>) -> Vec<u8> {
    let mut w = W::new();
    let map = advance_map.map(|m| {
        let mut d = W::new();
        d.u8(0).u8(0x00).u16(m.len() as u16);
        for v in m {
            d.u8(*v as u8);
        }
        d.0
    });
    w.u32(0x00010000).u32(20);
    w.u32(if map.is_some() { (20 + ivs.len()) as u32 } else { 0 }).u32(0).u32(0);
    w.bytes(ivs);
    if let Some(m) = map {
        w.bytes(&m);
    }
    w.0
}

/// The variable TrueType fixture: glyphs 0-5 of the static font with
/// `fvar` (wght, wdth), `avar` and `gvar` (dense, sparse, intermediate
/// and composite tuples) and optionally `HVAR`.
pub fn tt_var(with_hvar: bool) -> Vec<u8> {
    let glyphs: Vec<Vec<u8>> = tt_glyphs().into_iter().take(6).collect();
    let (glyf, loca) = glyf_loca(&glyphs, false);
    let metrics: Vec<(u16, i16)> = tt_metrics().into_iter().take(6).collect();
    let axes = [("wght", 100.0, 400.0, 900.0), ("wdth", 50.0, 100.0, 200.0)];
    // Point counts: 0: 8, 1: 13, 2: 4; composites 3: 1 comp, 4: 2, 5: 2.
    let notdef = glyph_variation_data(None, &[Tuple {
        peak: Ok(0), intermediate: None, points: Some(None),
        xs: vec![10, 0, 0, 10, 5, 5, 5, 5, 0, 20, 0, 0], ys: vec![0, 0, 30, 30, 0, 0, 0, 0, 0, 0, 0, 0],
    }]);
    let a = glyph_variation_data(Some(Some(vec![0, 2, 4, 6, 13, 14])), &[
        // Shared points (IUP), shared peak wght=1.
        Tuple { peak: Ok(0), intermediate: None, points: None,
                xs: vec![-20, 40, 30, -20, 0, 60], ys: vec![0, 10, 300, 10, 0, 0] },
        // Embedded peak (wdth=-1) with private points and words.
        Tuple { peak: Err(vec![0.0, -1.0]), intermediate: None, points: Some(Some(vec![1, 3, 5, 10, 12])),
                xs: vec![-300, 200, -1000, 1, 0], ys: vec![0, 0, 50, -50, 5] },
        // An intermediate region (wght 0.5 within 0..1).
        Tuple { peak: Err(vec![0.5, 0.0]), intermediate: Some((vec![0.0, 0.0], vec![1.0, 0.0])), points: Some(None),
                xs: (0..17).map(|i| i * 3 - 20).collect(), ys: (0..17).map(|i| 40000 * (i % 2) - 20000).collect() },
    ]);
    let o = glyph_variation_data(None, &[
        Tuple { peak: Ok(1), intermediate: None, points: Some(Some(vec![2])), xs: vec![100], ys: vec![-50] },
        Tuple { peak: Ok(0), intermediate: None, points: Some(Some(vec![0, 1, 2, 3, 5])), xs: vec![0, 0, 0, 0, 80], ys: vec![10, 20, 30, 40, 0] },
    ]);
    let comp1 = glyph_variation_data(None, &[
        Tuple { peak: Ok(0), intermediate: None, points: Some(None), xs: vec![15, 0, 40, 0, 0], ys: vec![-7, 0, 0, 0, 0] },
    ]);
    let comp2 = glyph_variation_data(None, &[
        Tuple { peak: Ok(1), intermediate: None, points: Some(Some(vec![1, 3])), xs: vec![-33, 99], ys: vec![12, 0] },
    ]);
    let gvar_glyphs = vec![notdef, a, o, comp1, comp2, Vec::new()];
    let gvar = gvar(2, &[vec![1.0, 0.0], vec![-1.0, 1.0]], &gvar_glyphs, false);
    let mut tables = vec![
        ("head", head(1000, (-50, -200, 1100, 900), false)),
        ("hhea", hhea(6)),
        ("hmtx", hmtx(&metrics, 6)),
        ("maxp", maxp_v1(6)),
        ("glyf", glyf),
        ("loca", loca),
        ("name", tt_name()),
        ("post", post_v3()),
        ("OS/2", os2()),
        ("fvar", fvar(&axes)),
        ("avar", avar(&[vec![(-1.0, -1.0), (-0.5, -0.7), (0.0, 0.0), (0.5, 0.3), (1.0, 1.0)], vec![]])),
        ("gvar", gvar),
    ];
    if with_hvar {
        let ivs = item_variation_store(2, &[vec![(0.0, 1.0, 1.0), (0.0, 0.0, 0.0)], vec![(0.0, 0.0, 0.0), (-1.0, -1.0, 0.0)]],
            &[(vec![0, 1], vec![vec![100, -20], vec![0, 0], vec![-300, 150], vec![7, 7]])]);
        tables.push(("HVAR", hvar(&ivs, Some(&[2, 0, 1, 3, 3, 0]))));
    }
    sfnt(0x00010000, &tables)
}

/// The CFF2 fixture: blends in charstrings, subroutines and the Private
/// DICT, two item variation data (`vsindex`), `HVAR` metrics.
pub fn cff2_var() -> Vec<u8> {
    let blend = |vals: &[(i32, i32, i32)]| {
        // value, delta region 0, delta region 1 (for store index 0 with 2
        // regions); emitted as v... d0... then count blend.
        let mut out = Vec::new();
        for v in vals {
            out.extend(num(v.0));
        }
        for v in vals {
            out.extend(num(v.1));
            out.extend(num(v.2));
        }
        out.extend(num(vals.len() as i32));
        out.extend(op(16));
        out
    };
    let charstrings = vec![
        cat(&[num(50), num(0), op(21), num(400), op(6), num(700), op(7), num(-400), op(6)]),
        cat(&[blend(&[(60, 10, -5), (0, 0, 0)]), op(21),
              blend(&[(100, 20, 0), (-10, 0, 0), (120, 0, 30), (10, 0, 0), (100, 5, 5), (100, -5, -5)]), op(8),
              num(0 - 107), op(10)]),
        cat(&[num(1), op(15), // vsindex 1 (three regions)
              num(10), num(10), op(21),
              num(300), num(30), num(-20), num(40), num(1), op(16), op(6),
              num(20), num(30), num(40), num(50), op(27),
              num(5), num(6), num(7), num(8), op(26),
              num(0 - 107), op(29)]),
        // hints and a hintmask.
        cat(&[num(0), num(20), num(300), num(20), op(18), num(50), num(20), op(23), op(19), vec![0xF0],
              num(100), num(100), op(21), num(50), num(50), op(5)]),
        // No outline.
        vec![],
        cat(&[num(0), num(0), op(21), num(10), num(20), num(30), num(40), num(50), num(60), num(70), num(80), num(90), num(100), num(110), num(120), num(50), op2(35),
              num(1 - 107), op(29)]),
    ];
    let local_subrs = vec![cat(&[blend(&[(30, 5, 5)]), op(6), num(20), op(7)])];
    let gsubrs = vec![
        cat(&[num(10), num(-10), op(5)]),
        cat(&[blend(&[(40, -10, 10), (0, 0, 0)]), op(5)]),
    ];
    let ivs = item_variation_store(1,
        &[vec![(0.0, 1.0, 1.0)], vec![(-1.0, -1.0, 0.0)], vec![(0.0, 0.5, 1.0)]],
        &[(vec![0, 1], vec![]), (vec![0, 1, 2], vec![])]);
    let private = |subrs_off: i32| {
        cat(&[num(0), op(22), // vsindex 0
              num(-10), num(10), num(500), num(10), num(5), num(-5), num(0), num(0), num(10), num(5), num(-5), num(0), num(0), num(10), num(4), op(16), op(6), // blended BlueValues
              num(80), op(10), num5(subrs_off), op(19)])
    };
    let private_len = private(0).len();
    let private = private(private_len as i32);
    let subrs = index(&local_subrs, true, None);
    let gsubrs_index = index(&gsubrs, true, None);
    let charstrings_index = index(&charstrings, true, None);
    let mut vstore = W::new();
    vstore.u16(ivs.len() as u16).bytes(&ivs);
    // Layout: header(5) top gsubrs charstrings vstore fdarray private subrs
    let top = |cs: usize, vs: usize, fd: usize| cat(&[num5(cs as i32), op(17), num5(vs as i32), op(24), num5(fd as i32), op2(36)]);
    let top_len = top(0, 0, 0).len();
    let cs_at = 5 + top_len + gsubrs_index.len();
    let vs_at = cs_at + charstrings_index.len();
    let fd_at = vs_at + vstore.len();
    let fd_dict = |p: usize| cat(&[num5(private.len() as i32), num5(p as i32), op(18)]);
    let fd_array_len = index(&[fd_dict(0)], true, None).len();
    let private_at = fd_at + fd_array_len;
    let fd_array = index(&[fd_dict(private_at)], true, None);
    let mut w = W::new();
    w.u8(2).u8(0).u8(5).u16(top_len as u16);
    w.bytes(&top(cs_at, vs_at, fd_at)).bytes(&gsubrs_index).bytes(&charstrings_index).bytes(&vstore.0).bytes(&fd_array).bytes(&private).bytes(&subrs);
    let cff2 = w.0;
    let metrics: Vec<(u16, i16)> = vec![(500, 50), (600, 60), (550, 10), (600, 0), (250, 0), (700, 0)];
    let hvar_ivs = item_variation_store(1, &[vec![(0.0, 1.0, 1.0)], vec![(-1.0, -1.0, 0.0)]],
        &[(vec![0, 1], vec![vec![0, 0], vec![50, -25], vec![-30, 10], vec![100, 100], vec![0, 0], vec![1, -1]])]);
    sfnt(0x4F54544F, &[
        ("head", head(1000, (-50, -200, 1100, 900), false)),
        ("hhea", hhea(6)),
        ("hmtx", hmtx(&metrics, 6)),
        ("maxp", maxp_v05(6)),
        ("name", tt_name()),
        ("post", post_v3()),
        ("OS/2", os2()),
        ("fvar", fvar(&[("wght", 200.0, 400.0, 900.0)])),
        ("HVAR", hvar(&hvar_ivs, None)),
        ("CFF2", cff2),
    ])
}

/// All fixture fonts by name.
/// Sets the byte at `offset` in table `tag` of an sfnt (table checksums are
/// left as they are).
pub fn patch_table(mut font: Vec<u8>, tag: &str, offset: usize, value: u8) -> Vec<u8> {
    let count = u16::from_be_bytes([font[4], font[5]]) as usize;
    for i in 0..count {
        let rec = 12 + 16 * i;
        if &font[rec..rec + 4] == tag.as_bytes() {
            let start = u32::from_be_bytes(font[rec + 8..rec + 12].try_into().unwrap()) as usize;
            font[start + offset] = value;
            return font;
        }
    }
    panic!("no table {tag}")
}

pub fn all() -> Vec<(&'static str, Vec<u8>)> {
    let tt_short = sfnt(0x00010000, &tt_tables(false, tt_post()));
    let tt_long_v3 = sfnt(0x74727565, &tt_tables(true, post_v3()));
    let cff_tables = |cff: Vec<u8>| {
        let metrics: Vec<(u16, i16)> = (0..8).map(|g| (500 + 10 * g as u16, 0)).collect();
        vec![
            ("head", head(1000, (-50, -200, 1100, 900), false)),
            ("hhea", hhea(4)),
            ("hmtx", hmtx(&metrics, 4)),
            ("maxp", maxp_v05(8)),
            ("name", tt_name()),
            ("post", post_v3()),
            ("OS/2", os2()),
            ("CFF ", cff),
        ]
    };
    let cid_tables = |cff: Vec<u8>| {
        let metrics: Vec<(u16, i16)> = (0..10).map(|g| (500 + 10 * g as u16, 0)).collect();
        vec![
            ("head", head(1000, (0, -200, 1000, 900), false)),
            ("hhea", hhea(10)),
            ("hmtx", hmtx(&metrics, 10)),
            ("maxp", maxp_v05(10)),
            ("name", tt_name()),
            ("post", post_v3()),
            ("CFF ", cff),
        ]
    };
    let cff = sfnt(0x4F54544F, &cff_tables(cff_name_keyed(false)));
    let cff_matrix = sfnt(0x4F54544F, &cff_tables(cff_name_keyed(true)));
    let cid = sfnt(0x4F54544F, &cid_tables(cff_cid_keyed(false, false)));
    let cid_fd0 = sfnt(0x4F54544F, &cid_tables(cff_cid_keyed(true, true)));
    let collection = ttc(&[(0x00010000, tt_tables(false, tt_post())), (0x4F54544F, cid_tables(cff_cid_keyed(false, false)))]);
    // The malformed CFF table of the subsetter's own test.
    let malformed_cff = {
        let mut f = Vec::new();
        f.extend(0x4F54544Fu32.to_be_bytes());
        f.extend(1u16.to_be_bytes());
        f.extend(0u16.to_be_bytes());
        f.extend(0u16.to_be_bytes());
        f.extend(0u16.to_be_bytes());
        f.extend(*b"CFF ");
        f.extend(0u32.to_be_bytes());
        f.extend(28u32.to_be_bytes());
        f.extend(4u32.to_be_bytes());
        f.extend([2, 0, 4, 4]);
        f
    };
    vec![
        ("tt", tt_short),
        ("tt_long", tt_long_v3),
        ("cff", cff),
        ("cff_matrix", cff_matrix),
        ("cid", cid),
        ("cid_fd0", cid_fd0),
        ("ttc", collection),
        ("tt_var", tt_var(false)),
        ("tt_var_hvar", tt_var(true)),
        ("cff2", cff2_var()),
        // A CFF2 header size below 5: the Top DICT still starts at 5.
        ("cff2_header4", patch_table(cff2_var(), "CFF2", 2, 4)),
        // A region count past the end of the HVAR region list: the region
        // array reads as empty and every region as one without axes.
        ("tt_var_hvar_regions", patch_table(tt_var(true), "HVAR", 35, 57)),
        // An avar axis count of 0: the segment maps are still read.
        ("tt_var_avar_count0", patch_table(tt_var(false), "avar", 7, 0)),
        // A null gvar shared tuples offset: no glyph has variation data.
        ("tt_var_gvar_null", patch_table(tt_var(false), "gvar", 11, 0)),
        ("malformed_cff", malformed_cff),
        ("unknown", b"\x00\x02\x00\x00\x00\x00\x00\x00".to_vec()),
    ]
}
