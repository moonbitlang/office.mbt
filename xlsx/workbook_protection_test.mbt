///|
test "workbook protection roundtrip" {
  let workbook = Workbook::new()
  let opts = WorkbookProtectionOptions::with_values(
    password="secret",
    lock_structure=true,
    lock_windows=true,
  )
  workbook.protect_workbook(options=opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("workbook.xml utf8 decode failed")
      }
    None => fail("missing workbook.xml")
  }
  inspect(workbook_xml.contains("<workbookProtection"), content="true")
  inspect(workbook_xml.contains("lockStructure=\"1\""), content="true")
  inspect(workbook_xml.contains("lockWindows=\"1\""), content="true")
  inspect(
    workbook_xml.contains("workbookAlgorithmName=\"SHA-512\""),
    content="true",
  )
  let parsed = read(bytes)
  let bad = try? parsed.unprotect_workbook(password="bad")
  inspect(
    bad,
    content="Err(InvalidWorkbookProtection(msg=\"workbook protection password mismatch\"))",
  )
  let ok = try? parsed.unprotect_workbook(password="secret")
  inspect(ok, content="Ok(())")
}

///|
test "workbook protection mismatched password on no-hash protection" {
  let workbook = Workbook::new()
  workbook.protect_workbook()
  let bad : Result[Unit, Error] = try? workbook.unprotect_workbook(
    password="secret",
  )
  inspect(bad is Err(XlsxError::InvalidWorkbookProtection(_)), content="true")
}

///|
test "workbook protection with explicit algorithm option" {
  let workbook = Workbook::new()
  let opts = WorkbookProtectionOptions::with_values(
    password="secret",
    algorithm_name="SHA-512",
    lock_structure=true,
  )
  workbook.protect_workbook(options=opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("workbook.xml utf8 decode failed")
      }
    None => fail("missing workbook.xml")
  }
  inspect(
    workbook_xml.contains("workbookAlgorithmName=\"SHA-512\""),
    content="true",
  )
  let parsed = read(bytes)
  let ok = try? parsed.unprotect_workbook(password="secret")
  inspect(ok, content="Ok(())")
}
