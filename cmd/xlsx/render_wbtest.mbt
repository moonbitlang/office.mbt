///|
test "render_ascii_table renders a header and body" {
  inspect(
    render_ascii_table([["Name", "Score"], ["Alice", "90"], ["Bob", "7"]]),
    content=(
      #|+-------+-------+
      #|| Name  | Score |
      #|+-------+-------+
      #|| Alice | 90    |
      #|| Bob   | 7     |
      #|+-------+-------+
    ),
  )
}

///|
test "render_ascii_table handles a single row and an empty grid" {
  inspect(
    render_ascii_table([["a", "bb"]]),
    content=(
      #|+---+----+
      #|| a | bb |
      #|+---+----+
    ),
  )
  inspect(render_ascii_table([]), content="(empty sheet)")
}

///|
test "render_ascii_table pads jagged rows to the widest column" {
  inspect(
    render_ascii_table([["x", "y"], ["long"]]),
    content=(
      #|+------+---+
      #|| x    | y |
      #|+------+---+
      #|| long |   |
      #|+------+---+
    ),
  )
}

///|
test "csv_field quotes only when necessary" {
  inspect(csv_field("plain"), content="plain")
  inspect(
    csv_field("a,b"),
    content=(
      #|"a,b"
    ),
  )
  inspect(
    csv_field("she said \"hi\""),
    content=(
      #|"she said ""hi"""
    ),
  )
}
