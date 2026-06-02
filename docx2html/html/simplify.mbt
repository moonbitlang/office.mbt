///|
/// Simplifies adjacent and redundant HTML nodes.
pub fn simplify_html(nodes : Array[HtmlNode]) -> Array[HtmlNode] {
  let result : Array[HtmlNode] = []
  for node in nodes {
    match simplify_html_node(node) {
      Some(simplified) => append_simplified(result, simplified)
      None => ()
    }
  }
  result
}

///|
fn simplify_html_node(node : HtmlNode) -> HtmlNode? {
  match node {
    TextNode("") => None
    Element(tag~, attributes~, children~, fresh~, separator~) => {
      let children = simplify_html(children)
      if children.is_empty() && !is_void_html_tag(tag) {
        None
      } else {
        Some(Element(tag~, attributes~, children~, fresh~, separator~))
      }
    }
    _ => Some(node)
  }
}

///|
fn append_simplified(result : Array[HtmlNode], node : HtmlNode) -> Unit {
  if result.length() == 0 {
    result.push(node)
  } else {
    let last_index = result.length() - 1
    match (result[last_index], node) {
      (
        Element(
          tag=tag_a,
          attributes=attrs_a,
          children=children_a,
          fresh=fresh_a,
          separator=separator_a
        ),
        Element(
          tag=tag_b,
          attributes=attrs_b,
          children=children_b,
          fresh=false,
          separator=separator_b
        ),
      ) =>
        if html_tag_matches(tag_b, tag_a) && attrs_a == attrs_b {
          let merged = merge_html_children(children_a, children_b, separator_b)
          result[last_index] = Element(
            tag=tag_a,
            attributes=attrs_a,
            children=merged,
            fresh=fresh_a,
            separator=separator_a,
          )
        } else {
          result.push(node)
        }
      _ => result.push(node)
    }
  }
}

///|
fn merge_html_children(
  left : Array[HtmlNode],
  right : Array[HtmlNode],
  separator : String?,
) -> Array[HtmlNode] {
  let merged : Array[HtmlNode] = []
  merged.append(left)
  match separator {
    Some(value) => append_simplified(merged, html_text(value))
    None => ()
  }
  for child in right {
    append_simplified(merged, child)
  }
  merged
}
