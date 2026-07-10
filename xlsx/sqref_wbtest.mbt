///|
test "sqref wb: flat_sqref trims empty tokens and merges repeated single-column refs" {
  let normalized = delete_cells_from_sqref("A1  A2", Map([]))
  inspect(normalized, content="A1:A2")
}
