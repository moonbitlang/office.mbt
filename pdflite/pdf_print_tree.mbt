///|
fn[T] pdf_print_tree_root(
  output : Array[String],
  indent : String,
  value : T,
  get_name : (T) -> String,
  get_children : (T) -> Array[T],
) -> Unit {
  output.push(get_name(value))
  output.push("\n")
  let children = get_children(value)
  for index in 0..<children.length() {
    let is_last = index + 1 == children.length()
    let line = if is_last { "└── " } else { "├── " }
    let extra_indent = if is_last { "    " } else { "│   " }
    output.push(indent)
    output.push(line)
    pdf_print_tree_root(
      output,
      indent + extra_indent,
      children[index],
      get_name,
      get_children,
    )
  }
}

///|
/// Render a tree to a string using cpdf's line-drawing layout.
///
/// `get_name` returns the label for a node, and `get_children` returns its
/// children in display order. `line_prefix` is prepended to every rendered line.
pub fn[T] pdf_print_tree_to_string(
  value : T,
  get_name : (T) -> String,
  get_children : (T) -> Array[T],
  line_prefix? : String = "",
) -> String {
  let output : Array[String] = [line_prefix]
  pdf_print_tree_root(output, line_prefix, value, get_name, get_children)
  output.join("")
}
