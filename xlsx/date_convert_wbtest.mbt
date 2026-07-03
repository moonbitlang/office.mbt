///|
test "date convert wb: 1904 serial negative returns None" {
  debug_inspect(excel_serial_to_parts_1904(-1.0), content="None")
}
