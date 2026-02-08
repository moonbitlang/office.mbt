///|
test "defined name wb: normalize empty scope to Workbook" {
  inspect(normalize_defined_name_scope(""), content="Workbook")
}

///|
test "defined name wb: builtin name detection includes print area" {
  inspect(is_builtin_defined_name("_xlnm.Print_Area"), content="true")
}

///|
test "defined name wb: reject too-long names" {
  let too_long : Result[Unit, Error] = try? check_defined_name("a".repeat(256))
  inspect(too_long is Err(XlsxError::InvalidDefinedName(_)), content="true")
}
