///|
/// A branch of `PdfDocument::pdf_page_tree_walk` being visited: its kids,
/// the next one to visit, the state its children get, their depth less
/// one, and the object numbers (the node's, its `/Kids` array's) it put on
/// the path.
priv struct PdfPageTreeFrame[S] {
  kids : Array[@syntax.PdfObject]
  mut next : Int
  state : S
  depth : Int
  entered : Array[Int]
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
/// Walk a page tree depth first, in document order, without recursion;
/// the walk keeps one frame per level of the path, so its own space is
/// proportional to the tree's depth.
///
/// `visit(node, number, state)` handles one node (`number` is -1 for a
/// direct node): None for a leaf, or the object number of its `/Kids`
/// array (-1 when direct), its kids, and the state to visit them with.
/// `child(kid)` resolves one kid, when it is reached, to the node and its
/// object number, or None to skip it.
///
/// A node or a `/Kids` array that is its own ancestor (a cycle) raises
/// `PageTreeExpected`, as does a node deeper than 10000 levels. Every node
/// visited, direct or not, and every `/Kids` array held by reference that
/// a branch expands costs one step, and more than `2 * object_count + 16`
/// steps raise `PageTreeExpected` too: a tree whose nodes are all held by
/// reference, each node and `/Kids` array appearing once, takes at most
/// `object_count` steps, while a
/// node or array shared by many parents (which a recursive walk would
/// visit once per parent, multiplying the tree) uses the allowance up.
fn[S] PdfDocument::pdf_page_tree_walk(
  self : PdfDocument,
  root : @syntax.PdfObject,
  root_number : Int,
  root_depth : Int,
  state : S,
  visit : (@syntax.PdfObject, Int, S) -> (Int, Array[@syntax.PdfObject], S)? raise @core.PdfError,
  child : (@syntax.PdfObject) -> (@syntax.PdfObject, Int)? raise @core.PdfError,
) -> Unit raise @core.PdfError {
  let budget = 2 * self.object_count() + 16
  let mut steps = 0
  let charge = fn() raise @core.PdfError {
    steps += 1
    if steps > budget {
      raise PageTreeExpected
    }
  }
  let on_path : Map[Int, Unit] = Map([])
  let stack : Array[PdfPageTreeFrame[S]] = []
  let enter = fn(
    node : @syntax.PdfObject,
    number : Int,
    state : S,
    depth : Int,
  ) raise @core.PdfError {
    charge()
    if depth > 10000 {
      raise PageTreeExpected
    }
    if number >= 0 && on_path.contains(number) {
      raise PageTreeExpected
    }
    guard visit(node, number, state) is Some((kids_number, kids, child_state)) else {
      return
    }
    let entered : Array[Int] = []
    if number >= 0 {
      on_path[number] = ()
      entered.push(number)
    }
    if kids_number >= 0 {
      charge()
      if on_path.contains(kids_number) {
        raise PageTreeExpected
      }
      on_path[kids_number] = ()
      entered.push(kids_number)
    }
    stack.push({ kids, next: 0, state: child_state, depth, entered, })
  }
  enter(root, root_number, state, root_depth)
  while stack.last() is Some(frame) {
    if frame.next >= frame.kids.length() {
      ignore(stack.pop())
      for number in frame.entered {
        on_path.remove(number)
      }
      continue
    }
    let kid = frame.kids[frame.next]
    frame.next += 1
    match child(kid) {
      Some((node, number)) => enter(node, number, frame.state, frame.depth + 1)
      None => ()
    }
  }
}
