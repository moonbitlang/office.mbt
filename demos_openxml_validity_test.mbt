///|
#cfg(target="native")
async test "complex demos generate OpenXML-valid packages" {
  let stamp = @env.now()
    .to_string()
    .replace(old=":", new="_")
    .replace(old=" ", new="_")
  let out_dir = "_build/xlsx_validate_demos/\{stamp}"
  @async/fs.mkdir(out_dir, permission=0o755, recursive=true) catch {
    err => fail("mkdir failed: \{err}")
  }

  let combo_path = "\{out_dir}/combo_chart.xlsx"
  @async/fs.write_file(
    combo_path,
    @demos.demo_combo_chart_bytes(),
    create=0o644,
  ) catch {
    err => fail("write combo_chart.xlsx failed: \{err}")
  }
  let (combo_code, combo_stdout, combo_stderr) = @process.collect_output(
    "bash",
    ["-lc", "scripts/validate_xlsx.sh \"\{combo_path}\""],
  )
  if combo_code != 0 {
    let out = combo_stdout.text() catch { _ => "<non-utf8 stdout>" }
    let err = combo_stderr.text() catch { _ => "<non-utf8 stderr>" }
    fail(
      "OpenXML validation failed (exit=\{combo_code}) for \{combo_path}\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
  @async/fs.remove(combo_path) catch {
    _ => ()
  }

  let controls_path = "\{out_dir}/interactive_controls.xlsx"
  @async/fs.write_file(
    controls_path,
    @demos.demo_interactive_controls_bytes(),
    create=0o644,
  ) catch {
    err => fail("write interactive_controls.xlsx failed: \{err}")
  }
  let (controls_code, controls_stdout, controls_stderr) = @process.collect_output(
    "bash",
    ["-lc", "scripts/validate_xlsx.sh \"\{controls_path}\""],
  )
  if controls_code != 0 {
    let out = controls_stdout.text() catch { _ => "<non-utf8 stdout>" }
    let err = controls_stderr.text() catch { _ => "<non-utf8 stderr>" }
    fail(
      "OpenXML validation failed (exit=\{controls_code}) for \{controls_path}\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
  @async/fs.remove(controls_path) catch {
    _ => ()
  }

  let pivot_path = "\{out_dir}/pivot_slicer.xlsx"
  @async/fs.write_file(
    pivot_path,
    @demos.demo_pivot_slicer_bytes(),
    create=0o644,
  ) catch {
    err => fail("write pivot_slicer.xlsx failed: \{err}")
  }
  let (pivot_code, pivot_stdout, pivot_stderr) = @process.collect_output(
    "bash",
    ["-lc", "scripts/validate_xlsx.sh \"\{pivot_path}\""],
  )
  if pivot_code != 0 {
    let out = pivot_stdout.text() catch { _ => "<non-utf8 stdout>" }
    let err = pivot_stderr.text() catch { _ => "<non-utf8 stderr>" }
    fail(
      "OpenXML validation failed (exit=\{pivot_code}) for \{pivot_path}\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
  @async/fs.remove(pivot_path) catch {
    _ => ()
  }

  let stream_path = "\{out_dir}/stream_big_3000.xlsx"
  @async/fs.write_file(
    stream_path,
    @demos.demo_stream_big_bytes(rows=3000),
    create=0o644,
  ) catch {
    err => fail("write stream_big_3000.xlsx failed: \{err}")
  }
  let (stream_code, stream_stdout, stream_stderr) = @process.collect_output(
    "bash",
    ["-lc", "scripts/validate_xlsx.sh \"\{stream_path}\""],
  )
  if stream_code != 0 {
    let out = stream_stdout.text() catch { _ => "<non-utf8 stdout>" }
    let err = stream_stderr.text() catch { _ => "<non-utf8 stderr>" }
    fail(
      "OpenXML validation failed (exit=\{stream_code}) for \{stream_path}\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
  @async/fs.remove(stream_path) catch {
    _ => ()
  }
}
