///|
fn pdf_page_root_pages_number(pdf : PdfDocument) -> Int raise @core.PdfError {
  let root = match pdf.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => raise RootExpected
  }
  match root.lookup_immediate(pdf_page_pages_key()) {
    Some(PdfIndirect(number)) => number
    _ => raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_page_tree_nodes_not_pages_inner(
  self : PdfDocument,
  node : @syntax.PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise @core.PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(pdf_page_type_key(), node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => []
    _ =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(kids)) => {
          let nodes : Array[Int] = Array::new(capacity=kids.length() + 1)
          nodes.push(node_number)
          for kid in kids {
            match kid {
              PdfIndirect(number) =>
                for
                  nested in self.pdf_page_tree_nodes_not_pages_inner(
                    self.direct(kid),
                    number,
                    depth + 1,
                  ) {
                  nodes.push(nested)
                }
              _ => ()
            }
          }
          nodes
        }
        _ => []
      }
  }
}

///|
fn PdfDocument::pdf_page_tree_nodes_not_pages(
  self : PdfDocument,
) -> Array[Int] raise @core.PdfError {
  let pages_number = pdf_page_root_pages_number(self)
  self.pdf_page_tree_nodes_not_pages_inner(
    self.lookup_object_or_null(pages_number),
    pages_number,
    0,
  )
}

///|
fn PdfDocument::pdf_page_reference_numbers_unordered_inner(
  self : PdfDocument,
  node : @syntax.PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise @core.PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(pdf_page_type_key(), node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => [node_number]
    _ =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(kids)) => {
          let numbers : Array[Int] = Array::new(capacity=kids.length())
          for kid in kids {
            match kid {
              PdfIndirect(number) =>
                for
                  page_number in self.pdf_page_reference_numbers_unordered_inner(
                    self.direct(kid),
                    number,
                    depth + 1,
                  ) {
                  numbers.push(page_number)
                }
              _ => ()
            }
          }
          numbers
        }
        _ => [node_number]
      }
  }
}

///|
fn PdfDocument::pdf_page_reference_numbers_unordered(
  self : PdfDocument,
) -> Array[Int] raise @core.PdfError {
  let pages_number = pdf_page_root_pages_number(self)
  self.pdf_page_reference_numbers_unordered_inner(
    self.lookup_object_or_null(pages_number),
    pages_number,
    0,
  )
}

///|
fn pdf_page_first_duplicate_number(numbers : ArrayView[Int]) -> Int? {
  let sorted = numbers.to_owned()
  sorted.sort()
  for i in 1..<sorted.length() {
    if sorted[i - 1] == sorted[i] {
      break Some(sorted[i])
    }
  } nobreak {
    None
  }
}

///|
fn pdf_page_rewrite_first_kid(
  kids : ArrayView[@syntax.PdfObject],
  old_number : Int,
  new_number : Int,
) -> (Array[@syntax.PdfObject], Bool) {
  let output : Array[@syntax.PdfObject] = Array::new(capacity=kids.length())
  let mut rewritten = false
  for kid in kids {
    match kid {
      PdfIndirect(number) if !rewritten && number == old_number => {
        output.push(PdfIndirect(new_number))
        rewritten = true
      }
      _ => output.push(kid)
    }
  }
  (output, rewritten)
}

///|
fn PdfDocument::pdf_page_rewrite_first_indirect(
  self : PdfDocument,
  node_number : Int,
  old_number : Int,
  new_number : Int,
) -> Bool raise @core.PdfError {
  let node = self.lookup_object_or_null(node_number)
  match node.lookup_immediate(pdf_page_kids_key()) {
    Some(PdfArray(kids)) => {
      let (rewritten_kids, rewritten) = pdf_page_rewrite_first_kid(
        kids, old_number, new_number,
      )
      if rewritten {
        self.add_object_given_number(
          node_number,
          node.add_dict_entry(pdf_page_kids_key(), PdfArray(rewritten_kids)),
        )
      }
      rewritten
    }
    _ => false
  }
}

///|
fn PdfDocument::pdf_page_rewrite_page_tree_first(
  self : PdfDocument,
  nodes : ArrayView[Int],
  page_number : Int,
) -> Unit raise @core.PdfError {
  let new_number = self.add_object(self.lookup_object_or_null(page_number))
  let mut rewritten = false
  for node_number in nodes {
    if !rewritten {
      rewritten = self.pdf_page_rewrite_first_indirect(
        node_number, page_number, new_number,
      )
    }
  }
  if !rewritten {
    self.remove_object(new_number)
    raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_page_fixup_duplicate_pages(
  self : PdfDocument,
) -> Unit raise @core.PdfError {
  let nodes = self.pdf_page_tree_nodes_not_pages()
  let mut done = false
  while !done {
    match
      pdf_page_first_duplicate_number(
        self.pdf_page_reference_numbers_unordered(),
      ) {
      Some(page_number) =>
        self.pdf_page_rewrite_page_tree_first(nodes, page_number)
      None => done = true
    }
  }
}

///|
fn PdfDocument::pdf_page_fixup_parents_inner(
  self : PdfDocument,
  parent_number : Int,
  node_number : Int,
  depth : Int,
) -> Unit raise @core.PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  let node = self.lookup_object_or_null(node_number)
  match node.lookup_immediate(pdf_page_parent_key()) {
    Some(PdfIndirect(_)) =>
      self.add_object_given_number(
        node_number,
        node.add_dict_entry(pdf_page_parent_key(), PdfIndirect(parent_number)),
      )
    _ => ()
  }
  match self.lookup_direct(pdf_page_kids_key(), node) {
    Some(PdfArray(kids)) =>
      for kid in kids {
        match kid {
          PdfIndirect(number) =>
            self.pdf_page_fixup_parents_inner(node_number, number, depth + 1)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_page_fixup_parents(
  self : PdfDocument,
) -> Unit raise @core.PdfError {
  self.pdf_page_fixup_parents_inner(0, pdf_page_root_pages_number(self), 0)
}
