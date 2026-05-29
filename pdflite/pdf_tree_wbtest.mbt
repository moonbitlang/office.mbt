// Whitebox tests for tree-building internals.
// Public tree behavior belongs in `_test.mbt` files.

///|
test "private tree group count covers threshold branches" {
  @test.assert_eq(pdf_tree_group_count(10), 1)
  @test.assert_eq(pdf_tree_group_count(11), 2)
  @test.assert_eq(pdf_tree_group_count(101), 10)
}
