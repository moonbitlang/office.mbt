///|
test "ZIP names percent-encode Unicode without changing existing escapes" {
  let logical = "word/é中😀%ff!+@.xml"
  let physical = @uri.zip_item_name_from_logical_part_name(logical)
  debug_inspect(
    physical,
    content="Some(\"word/%C3%A9%E4%B8%AD%F0%9F%98%80%ff!+@.xml\")",
  )
  debug_inspect(
    @uri.logical_part_name_from_zip_item_name(physical.unwrap()) ==
    Some(logical),
    content="true",
  )
}

///|
test "opaque percent escapes survive strict Unicode decoding failures" {
  for
    escaped in [
      "%FF", "%C2%80", "%C0%AF", "%E0%80%AF", "%ED%A0%80", "%F4%90%80%80", "%E4%B8",
      "%E4xAD",
    ] {
    let name = "word/" + escaped + ".xml"
    debug_inspect(
      @uri.logical_part_name_from_zip_item_name(name) == Some(name),
      content="true",
    )
  }
}

///|
test "OPC still rejects escaped separators and unreserved characters" {
  for escaped in ["%2F", "%5c", "%41", "%7e", "%", "%ZZ"] {
    let name = "word/" + escaped + ".xml"
    debug_inspect(
      @uri.logical_part_name_from_zip_item_name(name),
      content="None",
    )
  }
}
