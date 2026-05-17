///|
fn print_tree_name_for_test(value : Int) -> String {
  match value {
    0 => "root"
    1 => "left"
    2 => "right"
    3 => "leaf"
    _ => "?"
  }
}

///|
fn print_tree_children_for_test(value : Int) -> Array[Int] {
  match value {
    0 => [1, 2]
    1 => [3]
    _ => []
  }
}

///|
test "pdf_print_tree_to_string renders cpdf tree layout" {
  @test.assert_eq(
    @pdflite.pdf_print_tree_to_string(
      0, print_tree_name_for_test, print_tree_children_for_test,
    ),
    "root\n├── left\n│   └── leaf\n└── right\n",
  )
}

///|
test "pdf_print_tree_to_string applies a line prefix to every line" {
  @test.assert_eq(
    @pdflite.pdf_print_tree_to_string(
      0,
      print_tree_name_for_test,
      print_tree_children_for_test,
      line_prefix="> ",
    ),
    "> root\n> ├── left\n> │   └── leaf\n> └── right\n",
  )
}
