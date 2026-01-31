///|
fn usage() -> Unit {
  println("mbtexcel demos")
  println("")
  println("Usage:")
  println("  moon run cmd/demos")
  println("  moon run cmd/demos -- --list")
  println("  moon run cmd/demos -- <demo|all> [out_dir] [demo_args...]")
  println("")
  println("Demos:")
  println(
    "  dashboard           Sales data + table + conditional format + chart + image + shape",
  )
  println(
    "  invoice             Invoice template + validation + protection + header/footer",
  )
  println("  pivot_slicer         Pivot table + slicer")
  println("  sparklines           KPI sparklines")
  println(
    "  stream_big           Streaming writer for large sheets (arg: rows, default 20000)",
  )
  println(
    "  secure               Password-protected workbook (arg: password, default moonbit)",
  )
  println("")
  println("Example:")
  println("  moon run cmd/demos -- dashboard demos_out")
  println("  moon run cmd/demos -- stream_big demos_out 50000")
}

///|
async fn ensure_dir(path : String) -> Unit {
  @async/fs.mkdir(path, permission=0o755, recursive=true) catch {
    _ => ()
  }
}

///|
async fn write_out(out_dir : String, name : String, bytes : Bytes) -> Unit {
  ensure_dir(out_dir)
  let path = "\{out_dir}/\{name}"
  @async/fs.write_file(path, bytes, create=0o644) catch {
    err => {
      println("write failed: \{path}: \{err}")
      return
    }
  }
  println("wrote \{path} (\{bytes.length()} bytes)")
}

///|
fn run_demo_bytes(
  demo : StringView,
  args : ArrayView[String],
) -> (String, Bytes)? raise @xlsx.XlsxError {
  match demo {
    "dashboard" => Some(("dashboard.xlsx", demo_dashboard_bytes()))
    "invoice" => Some(("invoice.xlsx", demo_invoice_bytes()))
    "pivot_slicer" => Some(("pivot_slicer.xlsx", demo_pivot_slicer_bytes()))
    "sparklines" => Some(("sparklines.xlsx", demo_sparklines_bytes()))
    "stream_big" => {
      let rows = demo_stream_big_rows_from_args(args)
      Some(("stream_big_\{rows}.xlsx", demo_stream_big_bytes(rows~)))
    }
    "secure" => {
      let password = match args {
        [] => "moonbit"
        [p, ..] => p
      }
      Some(("secure_password.xlsx", demo_secure_bytes(password~)))
    }
    _ => None
  }
}

///|
async fn run_one(
  demo : StringView,
  out_dir : String,
  args : ArrayView[String],
) -> Unit {
  let result : Result[(String, Bytes)?, Error] = try? run_demo_bytes(demo, args)
  match result {
    Ok(Some((name, bytes))) => write_out(out_dir, name, bytes)
    Ok(None) => {
      println("unknown demo: \{demo.to_string()}")
      usage()
    }
    Err(err) => println("\{demo.to_string()}: failed: \{err}")
  }
}

///|
async fn run_all(out_dir : String) -> Unit {
  run_one("dashboard", out_dir, [])
  run_one("invoice", out_dir, [])
  run_one("pivot_slicer", out_dir, [])
  run_one("sparklines", out_dir, [])
  run_one("stream_big", out_dir, [])
  run_one("secure", out_dir, [])
}

///|
async fn main {
  let args = @env.args()
  match args {
    [] | [_] => run_all("demos_out")
    [_, "--help"] | [_, "-h"] => usage()
    [_, "--list"] => {
      println("dashboard")
      println("invoice")
      println("pivot_slicer")
      println("sparklines")
      println("stream_big")
      println("secure")
    }
    [_, demo] => run_one(demo, "demos_out", [])
    [_, demo, out_dir] => run_one(demo, out_dir, [])
    [_, demo, out_dir, .. rest] => run_one(demo, out_dir, rest)
  }
}
