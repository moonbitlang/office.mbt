///|
test "cmd/demos: build demo bytes (smoke)" {
  let a : Result[Bytes, Error] = try? demo_dashboard_bytes()
  inspect(a is Ok(_), content="true")
  let b : Result[Bytes, Error] = try? demo_invoice_bytes()
  inspect(b is Ok(_), content="true")
  let c : Result[Bytes, Error] = try? demo_pivot_slicer_bytes()
  inspect(c is Ok(_), content="true")
  let d : Result[Bytes, Error] = try? demo_sparklines_bytes()
  inspect(d is Ok(_), content="true")

  // keep this small for tests; stream demo is meant for large sheets at runtime
  let e : Result[Bytes, Error] = try? demo_stream_big_bytes(rows=100)
  inspect(e is Ok(_), content="true")
  let f : Result[Bytes, Error] = try? demo_secure_bytes()
  inspect(f is Ok(_), content="true")
}
