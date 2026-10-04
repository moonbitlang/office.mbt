// Port of subsetter 0.2.6 `src/remapper.rs`.

///|
/// A structure that allows to remap numeric types to new numbers so that
/// they form a contiguous sequence of numbers (upstream `Remapper<C, T>`;
/// `limit` is the number of values `C` can count).
priv struct Remapper {
  /// The counter that keeps track of the next number to be assigned.
  mut counter : Int
  /// The map that maps numbers from their old value to their new value,
  /// stored densely by old value (`-1` = not remapped). Old values are
  /// glyph IDs or font DICT indices, so the table stays small.
  mut forward : FixedArray[Int]
  /// The vector that stores the "reverse" mapping, i.e. given a new number,
  /// it allows to map back to the old one.
  backward : Array[Int]
  limit : Int
}

///|
fn Remapper::new(limit : Int) -> Remapper {
  { counter: 0, forward: [], backward: [], limit, }
}

///|
fn Remapper::copy(self : Remapper) -> Remapper {
  {
    counter: self.counter,
    forward: self.forward.copy(),
    backward: self.backward.copy(),
    limit: self.limit,
  }
}

///|
/// Get the new mapping of a value that has been remapped before.
fn Remapper::get(self : Remapper, old : Int) -> Int? {
  guard old >= 0 && old < self.forward.length() else { return None }
  let value = self.forward[old]
  if value < 0 {
    None
  } else {
    Some(value)
  }
}

///|
/// Remap a new value, either returning the previously assigned number if it
/// already has been remapped, and assigning a new number if it has not been
/// remapped.
fn Remapper::remap(self : Remapper, old : Int) -> Int {
  // Old values are glyph IDs (checked by `GlyphRemapper::remap`) or font
  // DICT indices, so they are never negative.
  guard old >= 0 else { abort("remapper value out of range") }
  if old < self.forward.length() && self.forward[old] >= 0 {
    return self.forward[old]
  }
  let value = self.counter
  self.backward.push(old)
  if self.counter + 1 >= self.limit {
    abort("remapper was overflowed")
  }
  self.counter += 1
  if old >= self.forward.length() {
    let grown = FixedArray::make(
      (old + 1).max(self.forward.length() * 2).max(64),
      -1,
    )
    self.forward.blit_to(grown, len=self.forward.length())
    self.forward = grown
  }
  self.forward[old] = value
  value
}

///|
/// Get the number of elements that have been remapped.
fn Remapper::len(self : Remapper) -> Int {
  self.counter
}

///|
/// The old values in the order defined by the remapping.
fn Remapper::sorted_iter(self : Remapper) -> Array[Int] {
  self.backward
}

///|
/// A remapper that allows to assign a new ordering to a subset of glyphs.
///
/// For example, let's say that we want to subset a font that only contains
/// the glyphs 4, 9 and 16. In this case, the remapper could yield a remapping
/// that assigns the following glyph IDs:
/// - 0 -> 0 (The .notdef glyph will always be included)
/// - 4 -> 1
/// - 9 -> 2
/// - 16 -> 3
///
/// This is necessary because a font needs to have a contiguous sequence of
/// glyph IDs that start from 0, so we cannot just reuse the old ones, but we
/// need to define a mapping.
pub struct GlyphRemapper {
  priv inner : Remapper
}

///|
/// Create a new instance of a glyph remapper. `.notdef` will always be a
/// member of the subset.
pub fn GlyphRemapper::new() -> GlyphRemapper {
  let remapper = Remapper::new(0x10000)
  // .notdef is always a part of a subset.
  remapper.remap(0) |> ignore
  { inner: remapper, }
}

///|
/// Create a remapper from an existing set of glyphs.
pub fn GlyphRemapper::new_from_glyphs(glyphs : ArrayView[Int]) -> GlyphRemapper {
  let map = GlyphRemapper::new()
  for glyph in glyphs {
    map.remap(glyph) |> ignore
  }
  map
}

///|
/// Create a remapper from an existing set of glyphs. The method will ensure
/// that the mapping is monotonically increasing.
pub fn GlyphRemapper::new_from_glyphs_sorted(
  glyphs : ArrayView[Int],
) -> GlyphRemapper {
  let sorted = glyphs.to_owned()
  sorted.sort()
  let dedup = []
  for g in sorted {
    if dedup.last() != Some(g) {
      dedup.push(g)
    }
  }
  GlyphRemapper::new_from_glyphs(dedup)
}

///|
/// A copy of the remapper.
pub fn GlyphRemapper::copy(self : GlyphRemapper) -> GlyphRemapper {
  { inner: self.inner.copy(), }
}

///|
/// Get the number of gids that have been remapped.
pub fn GlyphRemapper::num_gids(self : GlyphRemapper) -> Int {
  // (A `u16` counter: 65536 glyphs would have overflowed.)
  self.inner.len()
}

///|
/// Remap a glyph ID, or return the existing mapping if the glyph ID has
/// already been remapped before.
///
/// Glyph IDs are `u16`s: other values abort, like remapping more than 65535
/// glyphs (the Rust crate panics).
pub fn GlyphRemapper::remap(self : GlyphRemapper, old : Int) -> Int {
  if old < 0 || old > 0xFFFF {
    abort("glyph ID out of range")
  }
  self.inner.remap(old)
}

///|
/// Get the mapping of a glyph ID, if it has been remapped before.
pub fn GlyphRemapper::get(self : GlyphRemapper, old : Int) -> Int? {
  self.inner.get(old)
}

///|
/// The old glyphs, in ascending order that is defined by the remapping. For
/// example, if we perform the following remappings: 3, 39, 8, 3, 10, 2
///
/// Then the array holds the following items in the order below. The order
/// also implicitly defines the glyph IDs in the new mapping:
///
/// 0 (0), 3 (1), 39 (2), 8 (3), 10 (4), 2 (5)
pub fn GlyphRemapper::remapped_gids(self : GlyphRemapper) -> ArrayView[Int] {
  self.inner.backward
}
