// SPDX-License-Identifier: MPL-2.0
// Adapted from mtx-decompressor 1.8.0, ChristopherVR; see NOTICE.

///|
fn push_instructions(
  input : Stream,
  output : Stream,
  count : Int32,
) -> Unit raise {
  let values : Array[Int32] = []
  let mut remaining = count
  while remaining > 0 {
    let saved = input.pos
    let code = input.u8()
    if code == 251 || code == 252 {
      let needed = if code == 251 { 3 } else { 5 }
      guard remaining >= needed && values.length() >= 2 else {
        bad("corrupt MTX push hopcode")
        return
      }
      let previous = values[values.length() - 2]
      values.push(previous)
      values.push(input.short255())
      values.push(previous)
      if code == 252 {
        values.push(input.short255())
        values.push(previous)
      }
      remaining -= needed
    } else {
      input.seek(saved)
      values.push(input.short255())
      remaining -= 1
    }
  }
  let mut begin = 0
  while begin < values.length() {
    let short = values[begin] < 0 || values[begin] > 255
    let mut end = begin + 1
    while end < values.length() &&
          end - begin < 255 &&
          (values[end] < 0 || values[end] > 255) == short {
      end += 1
    }
    let size = end - begin
    if size < 8 {
      output.put((if short { 184 } else { 176 }) + size - 1)
    } else {
      output.put(if short { 65 } else { 64 })
      output.put(size)
    }
    for index in begin..<end {
      output.put(values[index], count=if short { 2 } else { 1 })
    }
    begin = end
  }
}

///|
fn instructions(streams : Array[Stream], output : Stream) -> Unit raise {
  let size_at = output.pos
  output.put(0, count=2)
  push_instructions(streams[1], output, streams[0].ushort255())
  streams[2].copy(output, streams[0].ushort255())
  let end = output.pos
  guard end - size_at - 2 <= 65535 else {
    bad("MTX glyph instructions exceed 16 bits")
    return
  }
  output.seek(size_at)
  output.put(end - size_at - 2, count=2)
  output.seek(end)
}

///|
fn triplet(input : Stream, index : Int32) -> (Int32, Int32) raise {
  let (x_bits, y_bits, dx, dy, signs) = if index < 10 {
    (0, 8, 0, index / 2 * 256, if index % 2 == 0 { 0 } else { 2 })
  } else if index < 20 {
    (8, 0, (index - 10) / 2 * 256, 0, (index - 10) % 2)
  } else if index < 84 {
    let n = index - 20
    (4, 4, 1 + n / 16 * 16, 1 + n / 4 % 4 * 16, n % 4)
  } else if index < 120 {
    let n = index - 84
    (8, 8, 1 + n / 12 * 256, 1 + n / 4 % 3 * 256, n % 4)
  } else {
    (
      if index < 124 {
        12
      } else {
        16
      },
      if index < 124 {
        12
      } else {
        16
      },
      0,
      0,
      index % 4,
    )
  }
  let x = input.bits(x_bits) + dx
  let y = input.bits(y_bits) + dy
  (
    signed16(if (signs & 1) == 0 { -x } else { x }),
    signed16(if (signs & 2) == 0 { -y } else { y }),
  )
}

///|
fn coordinate_flags(
  x : Int32,
  y : Int32,
  on_curve : Bool,
  first : Bool,
) -> Int32 {
  let flags = if on_curve { 1 } else { 0 }
  fn flags_for(value : Int32, short : Int32, same : Int32) -> Int32 {
    if !first && value == 0 {
      same
    } else if value > -256 && value < 0 {
      short
    } else if value >= 0 && value < 256 {
      short | same
    } else {
      0
    }
  }
  flags | flags_for(x, 2, 16) | flags_for(y, 4, 32)
}

///|
fn simple_glyph(
  contours : Int32,
  streams : Array[Stream],
  out : Stream,
  bbox : Array[Int32]?,
) -> Unit raise {
  if contours == 0 {
    return
  }
  guard contours > 0 && contours < 32767 else {
    bad("invalid MTX contour count")
    return
  }
  let input = streams[0]
  out.put(contours, count=2)
  let bbox_at = out.pos
  for value in bbox.unwrap_or([0, 0, 0, 0]) {
    out.put(value, count=2)
  }
  let mut points = 1
  for _ in 0..<contours {
    points += input.ushort255()
    guard points <= 65536 else {
      bad("MTX glyph has too many points")
      return
    }
    out.put(points - 1, count=2)
  }
  let encoded = Array::makei(points, _ => input.u8())
  let xs : Array[Int32] = []
  let ys : Array[Int32] = []
  let mut x = 0
  let mut y = 0
  let mut min_x = 32767
  let mut min_y = 32767
  let mut max_x = -32768
  let mut max_y = -32768
  for flag in encoded {
    let (dx, dy) = triplet(input, flag & 127)
    xs.push(dx)
    ys.push(dy)
    x += dx
    y += dy
    min_x = @cmp.minimum(min_x, x)
    min_y = @cmp.minimum(min_y, y)
    max_x = @cmp.maximum(max_x, x)
    max_y = @cmp.maximum(max_y, y)
  }
  instructions(streams, out)
  for i in 0..<points {
    out.put(coordinate_flags(xs[i], ys[i], (encoded[i] & 128) == 0, i == 0))
  }
  for deltas in [xs, ys] {
    for i, delta in deltas {
      if i == 0 || delta != 0 {
        let absolute = if delta < 0 { -delta } else { delta }
        out.put(
          if absolute < 256 {
            absolute
          } else {
            delta
          },
          count=if absolute < 256 { 1 } else { 2 },
        )
      }
    }
  }
  if bbox is None {
    let end = out.pos
    out.seek(bbox_at)
    for value in [min_x, min_y, max_x, max_y] {
      guard value >= -32768 && value <= 32767 else {
        bad("MTX glyph bounds overflow")
        return
      }
      out.put(value, count=2)
    }
    out.seek(end)
  }
}

///|
fn glyph(streams : Array[Stream], out : Stream) -> Unit raise {
  let input = streams[0]
  let contours = input.s16()
  if contours < 0 {
    out.put(-1, count=2)
    for _ in 0..<4 {
      out.put(input.s16(), count=2)
    }
    let mut flags = 32
    let mut components = 0
    while (flags & 32) != 0 {
      components += 1
      guard components <= 65535 else {
        bad("too many MTX glyph components")
        return
      }
      flags = input.uint(2)
      out.put(flags, count=2)
      out.put(input.uint(2), count=2)
      input.copy(out, if (flags & 1) != 0 { 4 } else { 2 })
      input.copy(
        out,
        if (flags & 128) != 0 {
          8
        } else if (flags & 64) != 0 {
          4
        } else if (flags & 8) != 0 {
          2
        } else {
          0
        },
      )
    }
    if (flags & 256) != 0 {
      instructions(streams, out)
    }
  } else if contours == 32767 {
    let count = input.s16()
    let bbox = Array::makei(4, _ => input.s16())
    simple_glyph(count, streams, out, Some(bbox))
  } else {
    simple_glyph(contours, streams, out, None)
  }
}
