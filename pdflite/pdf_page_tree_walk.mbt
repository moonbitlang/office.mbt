///|
/// A step of `PdfDocument::pdf_page_tree_walk`: visit a node (its object
/// number, -1 when it is direct, the state its parent passed down and its
/// depth), or leave the nodes and `/Kids` arrays a branch put on the path.
priv enum PdfPageTreeStep[S] {
  Visit(@syntax.PdfObject, Int, S, Int)
  Leave(Array[Int])
}

///|
/// The object number of `node`'s `/Kids` array when the node holds it by
/// reference, else -1.
fn pdf_page_tree_kids_number(node : @syntax.PdfObject) -> Int {
  match node.lookup_immediate(pdf_page_kids_key()) {
    Some(PdfIndirect(number)) => number
    _ => -1
  }
}

///|
/// Walk a page tree depth first, in document order, without recursion.
///
/// `visit(node, number, state)` handles one node: None for a leaf, or the
/// object number of its `/Kids` array (-1 when direct) and its children,
/// each with its object number (-1 when direct) and the state to visit it
/// with. A node or a `/Kids` array that is its own ancestor (a cycle)
/// raises `PageTreeExpected`, as does a node deeper than 10000 levels, so
/// the walk always ends; a node shared by two parents is visited twice, as
/// a recursive walk would, but visiting more indirect nodes than twice the
/// document's object count (sharing that multiplies the tree) raises
/// `PageTreeExpected` as well.
fn[S] PdfDocument::pdf_page_tree_walk(
  self : PdfDocument,
  root : @syntax.PdfObject,
  root_number : Int,
  root_depth : Int,
  state : S,
  visit : (@syntax.PdfObject, Int, S) -> (
    Int,
    Array[(@syntax.PdfObject, Int, S)],
  )? raise @core.PdfError,
) -> Unit raise @core.PdfError {
  let budget = 2 * self.object_numbers().length() + 16
  let mut visits = 0
  let on_path : Map[Int, Unit] = Map([])
  let stack : Array[PdfPageTreeStep[S]] = [
    Visit(root, root_number, state, root_depth),
  ]
  while stack.pop() is Some(step) {
    match step {
      Leave(numbers) =>
        for number in numbers {
          on_path.remove(number)
        }
      Visit(node, number, state, depth) => {
        if depth > 10000 {
          raise PageTreeExpected
        }
        if number >= 0 {
          if on_path.contains(number) {
            raise PageTreeExpected
          }
          visits += 1
          if visits > budget {
            raise PageTreeExpected
          }
        }
        guard visit(node, number, state) is Some((kids_number, children)) else {
          continue
        }
        let entered : Array[Int] = []
        if number >= 0 {
          on_path[number] = ()
          entered.push(number)
        }
        if kids_number >= 0 {
          if on_path.contains(kids_number) {
            raise PageTreeExpected
          }
          on_path[kids_number] = ()
          entered.push(kids_number)
        }
        stack.push(Leave(entered))
        for i = children.length() - 1; i >= 0; i = i - 1 {
          let (child, child_number, child_state) = children[i]
          stack.push(Visit(child, child_number, child_state, depth + 1))
        }
      }
    }
  }
}
