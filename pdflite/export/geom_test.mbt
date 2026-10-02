///|
test "Size and Rect constructors reject invalid geometry" {
  debug_inspect(
    @export.Size::from_wh(1.0, 2.0),
    content=(
      #|Some({ width: 1, height: 2 })
    ),
  )
  debug_inspect(
    @export.Size::from_wh(0.0, 2.0),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @export.Size::from_wh(1.0, 1.0 / 0.0),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @export.Rect::from_xywh(1.0, 2.0, 3.0, 4.0),
    content=(
      #|Some({ left: 1, top: 2, right: 4, bottom: 6 })
    ),
  )
  debug_inspect(
    @export.Rect::from_ltrb(5.0, 0.0, 1.0, 1.0),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @export.Rect::from_ltrb(0.0 / 0.0, 0.0, 1.0, 1.0),
    content=(
      #|None
    ),
  )
  let r = @export.Rect::from_xywh(10.0, 20.0, 30.0, 5.0).unwrap()
  debug_inspect(
    (r.width(), r.height()),
    content=(
      #|(30, 5)
    ),
  )
}

///|
test "Rect union and transform" {
  let a = @export.Rect::from_ltrb(0.0, 0.0, 10.0, 10.0).unwrap()
  let b = @export.Rect::from_ltrb(5.0, -5.0, 20.0, 8.0).unwrap()
  debug_inspect(
    a.union(b),
    content=(
      #|{ left: 0, top: -5, right: 20, bottom: 10 }
    ),
  )
  // Rotating by 90 degrees and translating.
  let rot = @export.Transform::from_row(0.0, 1.0, -1.0, 0.0, 100.0, 0.0)
  debug_inspect(
    b.transform(rot),
    content=(
      #|{ left: 92, top: 5, right: 105, bottom: 20 }
    ),
  )
}

///|
test "Transform concatenation order, application and inversion" {
  let t = @export.Transform::from_translate(10.0, 20.0)
  let s = @export.Transform::from_scale(2.0, 3.0)
  // pre_concat applies the argument first.
  debug_inspect(
    t.pre_concat(s).apply(1.0, 1.0),
    content=(
      #|{ x: 12, y: 23 }
    ),
  )
  // post_concat applies the receiver first.
  debug_inspect(
    t.post_concat(s).apply(1.0, 1.0),
    content=(
      #|{ x: 22, y: 63 }
    ),
  )
  let m = @export.Transform::from_row(2.0, 1.0, -1.0, 3.0, 5.0, 7.0)
  let inv = m.invert().unwrap()
  let p = m.pre_concat(inv).apply(4.0, -6.0)
  debug_inspect(
    p,
    content=(
      #|{ x: 4, y: -6 }
    ),
  )
  inspect(
    m.pre_concat(inv).is_identity(),
    content=(
      #|true
    ),
  )
  debug_inspect(
    @export.Transform::from_scale(0.0, 1.0).invert(),
    content=(
      #|None
    ),
  )
  inspect(
    @export.Transform::identity().is_identity(),
    content=(
      #|true
    ),
  )
}

///|
test "PathBuilder segments" {
  let pb = @export.PathBuilder::new()
  // A path without drawing segments is empty.
  debug_inspect(
    pb.finish(),
    content=(
      #|None
    ),
  )
  pb.move_to(0.0, 0.0)
  debug_inspect(
    pb.finish(),
    content=(
      #|None
    ),
  )
  // Consecutive move-tos replace each other.
  pb.move_to(1.0, 1.0)
  pb.line_to(5.0, 1.0)
  pb.quad_to(6.0, 2.0, 5.0, 3.0)
  pb.close()
  pb.close()
  // A segment after a close starts at the start of the closed subpath.
  pb.cubic_to(1.0, 4.0, 2.0, 5.0, 3.0, 6.0)
  pb.move_to(9.0, 9.0)
  let path = pb.finish().unwrap()
  debug_inspect(
    path.segments,
    content=(
      #|[
      #|  MoveTo({ x: 1, y: 1 }),
      #|  LineTo({ x: 5, y: 1 }),
      #|  QuadTo({ x: 6, y: 2 }, { x: 5, y: 3 }),
      #|  Close,
      #|  MoveTo({ x: 1, y: 1 }),
      #|  CubicTo({ x: 1, y: 4 }, { x: 2, y: 5 }, { x: 3, y: 6 }),
      #|]
    ),
  )
  debug_inspect(
    path.bounds(),
    content=(
      #|Some({ left: 1, top: 1, right: 6, bottom: 6 })
    ),
  )
  debug_inspect(
    path.transform(@export.Transform::from_translate(1.0, 0.0)).bounds(),
    content=(
      #|Some({ left: 2, top: 1, right: 7, bottom: 6 })
    ),
  )
}

///|
test "PathBuilder line_to injects a move-to at the origin" {
  let pb = @export.PathBuilder::new()
  pb.line_to(4.0, 2.0)
  debug_inspect(
    pb.finish().unwrap().segments,
    content=(
      #|[MoveTo({ x: 0, y: 0 }), LineTo({ x: 4, y: 2 })]
    ),
  )
}
