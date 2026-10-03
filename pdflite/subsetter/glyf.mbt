// Port of subsetter 0.2.6 `src/glyf.rs`.
//
// The `glyf` table contains the main description of the glyphs. In order to
// subset it, there are 5 things we need to do:
// 1. We need to form the glyph closure. Glyphs can reference other glyphs,
//    meaning that if a user for example requests the glyph 1, and this glyph
//    references the glyph 2, then we need to include both of them in our
//    subset.
// 2. We need to remove glyph descriptions that are not needed for the
//    subset, and reorder the existing glyph descriptions to match the order
//    defined by the remapper.
// 3. For component glyphs, we need to rewrite their description so that they
//    reference the new glyph ID of the glyphs they reference.
// 4. We need to calculate which format to use in the `loca` table.
// 5. We need to update the `loca` table itself with the new offsets.

///|
/// Form the glyph closure of all glyphs in `gid_set`.
fn glyf_closure(
  face : Face,
  glyph_remapper : GlyphRemapper,
) -> Unit raise SubsetError {
  guard GlyfTable::new(face) is Some(table) else { raise MalformedFont }
  let process_glyphs = glyph_remapper.remapped_gids().to_array()
  while process_glyphs.pop() is Some(glyph) {
    glyph_remapper.remap(glyph) |> ignore
    guard table.glyph_data(glyph) is Some(glyph_data) else { continue }
    if glyph_data.length() == 0 {
      continue
    }
    let r = Reader::new(glyph_data)
    guard r.read_i16() is Some(num_contours) else { raise MalformedFont }

    // If we have a composite glyph, add its components to the closure.
    if num_contours < 0 {
      guard component_glyphs(glyph_data) is Some(components) else {
        raise MalformedFont
      }
      for component in components {
        if glyph_remapper.get(component) is None {
          process_glyphs.push(component)
        }
      }
    }
  }
}

///|
fn glyf_subset(ctx : Context) -> Unit raise SubsetError {
  guard GlyfTable::new(ctx.face) is Some(table) else { raise MalformedFont }
  let maxp_data = MaxpData::default()
  let hmtx_data = []
  glyf_subset_with(ctx, old_gid => {
    match ctx.interjector {
      Dummy => {
        guard table.glyph_data(old_gid) is Some(data) else {
          raise MalformedFont
        }
        data
      }
      Skrifa(s) => {
        guard s.interject(maxp_data, old_gid) is Some((advance, lsb, data)) else {
          raise MalformedFont
        }
        hmtx_data.push((advance, lsb))
        data[:]
      }
    }
  })
  if ctx.interjector.is_skrifa() {
    ctx.custom_maxp_data = Some(maxp_data)
    ctx.custom_hmtx_data = Some(hmtx_data)
  }
}

///|
fn glyf_subset_with(
  ctx : Context,
  glyph_data_fn : (Int) -> BytesView raise SubsetError,
) -> Unit raise SubsetError {
  let subsetted_entries = subset_glyf_entries(ctx, glyph_data_fn)
  let sub_glyf = Writer::new()
  let sub_loca = Writer::new()
  let write_offset = (offset : Int) => {
    if ctx.long_loca {
      sub_loca.write_u32(offset.reinterpret_as_uint())
    } else {
      sub_loca.write_u16(offset / 2)
    }
  }
  for entry in subsetted_entries {
    write_offset(sub_glyf.len())
    sub_glyf.extend(entry)
    if !ctx.long_loca {
      sub_glyf.align(2)
    }
  }

  // Write the final offset.
  write_offset(sub_glyf.len())
  ctx.push(Tag::loca(), sub_loca.finish()[:])
  ctx.push(Tag::glyf(), sub_glyf.finish()[:])
}

///|
/// A glyf + loca table.
priv struct GlyfTable {
  loca : BytesView
  glyf : BytesView
  long : Bool
}

///|
fn GlyfTable::new(face : Face) -> GlyfTable? {
  guard face.table(Tag::loca()) is Some(loca) else { return None }
  guard face.table(Tag::glyf()) is Some(glyf) else { return None }
  guard face.table(Tag::head()) is Some(head) else { return None }
  let r = Reader::new_at(head, 50)
  guard r.read_i16() is Some(long) else { return None }
  Some({ loca, glyf, long: long != 0, })
}

///|
fn GlyfTable::glyph_data(self : GlyfTable, id : Int) -> BytesView? {
  let read_offset = (n : Int) => {
    if self.long {
      let r = Reader::new_at(self.loca, 4 * n)
      match r.read_u32() {
        Some(v) => Some(v.to_uint64())
        None => None
      }
    } else {
      let r = Reader::new_at(self.loca, 2 * n)
      match r.read_u16() {
        Some(v) => Some(2UL * v.to_uint64())
        None => None
      }
    }
  }
  guard read_offset(id) is Some(from) else { return None }
  guard read_offset(id + 1) is Some(to) else { return None }
  if from <= to && to <= self.glyf.length().to_uint64() {
    Some(self.glyf[from.to_int():to.to_int()])
  } else {
    None
  }
}

///|
fn subset_glyf_entries(
  ctx : Context,
  glyph_data_fn : (Int) -> BytesView raise SubsetError,
) -> Array[BytesView] raise SubsetError {
  let mut size = 0L
  let glyf_entries = []
  for old_gid in ctx.mapper.remapped_gids() {
    let glyph_data = glyph_data_fn(old_gid)

    // Empty glyph.
    if glyph_data.length() == 0 {
      glyf_entries.push(glyph_data)
      continue
    }
    let r = Reader::new(glyph_data)
    guard r.read_i16() is Some(num_contours) else { raise MalformedFont }
    let glyph_data = if num_contours < 0 {
      remap_component_glyph(ctx.mapper, glyph_data)[:]
    } else {
      // Simple glyphs don't need any subsetting.
      glyph_data
    }
    let mut len = glyph_data.length()
    len += len % 2
    size += len.to_int64()
    glyf_entries.push(glyph_data)
  }

  // Decide on the loca format.
  ctx.long_loca = size > 2L * 65535L
  glyf_entries
}

///|
let arg_1_and_2_are_words : Int = 0x0001

///|
let we_have_a_scale : Int = 0x0008

///|
let more_components : Int = 0x0020

///|
let we_have_an_x_and_y_scale : Int = 0x0040

///|
let we_have_a_two_by_two : Int = 0x0080

///|
let we_have_instructions : Int = 0x0100

///|
fn remap_component_glyph(
  mapper : GlyphRemapper,
  data : BytesView,
) -> Bytes raise SubsetError {
  let r = Reader::new(data)
  let w = Writer::new()
  let copy16 = () => {
    guard r.read_u16() is Some(v) else { raise MalformedFont }
    w.write_u16(v)
  }

  // number of contours
  copy16()

  // xMin, yMin, xMax, yMax
  copy16()
  copy16()
  copy16()
  copy16()
  for ;; {
    guard r.read_u16() is Some(flags) else { raise MalformedFont }
    w.write_u16(flags)
    guard r.read_u16() is Some(old_component) else { raise MalformedFont }
    guard mapper.get(old_component) is Some(new_component) else {
      raise MalformedFont
    }
    w.write_u16(new_component)
    if (flags & arg_1_and_2_are_words) != 0 {
      copy16()
      copy16()
    } else {
      copy16()
    }
    if (flags & we_have_a_scale) != 0 {
      copy16()
    } else if (flags & we_have_an_x_and_y_scale) != 0 {
      copy16()
      copy16()
    } else if (flags & we_have_a_two_by_two) != 0 {
      copy16()
      copy16()
      copy16()
      copy16()
    }
    let done = (flags & more_components) == 0
    if done {
      if (flags & we_have_instructions) != 0 {
        guard r.tail() is Some(tail) else { raise MalformedFont }
        w.extend(tail)
      }
      break
    }
  }
  w.finish()
}

///|
/// The component glyphs of a glyph (upstream yields them lazily and stops at
/// the first truncated component).
fn component_glyphs(glyph_data : BytesView) -> Array[Int]? {
  let r = Reader::new(glyph_data)

  // Number of contours
  guard r.read_i16() is Some(_) else { return None }

  // xMin, yMin, xMax, yMax
  guard r.read_i16() is Some(_) else { return None }
  guard r.read_i16() is Some(_) else { return None }
  guard r.read_i16() is Some(_) else { return None }
  guard r.read_i16() is Some(_) else { return None }
  let out = []
  for ;; {
    guard r.read_u16() is Some(flags) else { break }
    guard r.read_u16() is Some(component) else { break }
    if (flags & arg_1_and_2_are_words) != 0 {
      r.read_i16() |> ignore
      r.read_i16() |> ignore
    } else {
      r.read_u16() |> ignore
    }
    if (flags & we_have_a_scale) != 0 {
      r.read_u16() |> ignore
    } else if (flags & we_have_an_x_and_y_scale) != 0 {
      r.read_u16() |> ignore
      r.read_u16() |> ignore
    } else if (flags & we_have_a_two_by_two) != 0 {
      r.read_u16() |> ignore
      r.read_u16() |> ignore
      r.read_u16() |> ignore
      r.read_u16() |> ignore
    }
    out.push(component)
    if (flags & more_components) == 0 {
      break
    }
  }
  Some(out)
}
