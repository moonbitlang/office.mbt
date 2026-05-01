///|
fn pdf_bookmark_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_bookmark_outlines_key() -> PdfName {
  pdf_bookmark_name("/Outlines")
}

///|
fn pdf_bookmark_root_key() -> PdfName {
  pdf_bookmark_name("/Root")
}

///|
fn pdf_bookmark_first_key() -> PdfName {
  pdf_bookmark_name("/First")
}

///|
fn pdf_bookmark_next_key() -> PdfName {
  pdf_bookmark_name("/Next")
}

///|
fn pdf_bookmark_title_key() -> PdfName {
  pdf_bookmark_name("/Title")
}

///|
fn pdf_bookmark_dest_key() -> PdfName {
  pdf_bookmark_name("/Dest")
}

///|
fn pdf_bookmark_action_key() -> PdfName {
  pdf_bookmark_name("/A")
}

///|
fn pdf_bookmark_d_key() -> PdfName {
  pdf_bookmark_name("/D")
}

///|
fn pdf_bookmark_count_key() -> PdfName {
  pdf_bookmark_name("/Count")
}

///|
fn pdf_bookmark_colour_key() -> PdfName {
  pdf_bookmark_name("/C")
}

///|
fn pdf_bookmark_flags_key() -> PdfName {
  pdf_bookmark_name("/F")
}

///|
pub(all) struct PdfBookmarkColour {
  red : Double
  green : Double
  blue : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfBookmark {
  level : Int
  text : PdfBytes
  target : PdfDestination
  is_open : Bool
  colour : PdfBookmarkColour
  flags : Int
} derive(Debug, Eq, ToJson)

///|
pub let pdf_bookmark_black : PdfBookmarkColour = {
  red: 0.0,
  green: 0.0,
  blue: 0.0,
}

///|
fn PdfDocument::pdf_bookmark_title(
  self : PdfDocument,
  outline : PdfObject,
) -> PdfBytes {
  match self.lookup_direct(pdf_bookmark_title_key(), outline) {
    Some(PdfString(title)) => title
    _ => @ascii.encode("")
  }
}

///|
fn PdfDocument::pdf_bookmark_target(
  self : PdfDocument,
  outline : PdfObject,
  preserve_actions : Bool,
) -> PdfDestination raise PdfError {
  match self.lookup_direct(pdf_bookmark_dest_key(), outline) {
    Some(PdfString(key)) if preserve_actions => DestString(key)
    Some(destination) =>
      self.read_destination(destination, shallow=preserve_actions)
    None =>
      match self.lookup_direct(pdf_bookmark_action_key(), outline) {
        None => DestNull
        Some(action) =>
          if preserve_actions {
            match self.lookup_direct(pdf_bookmark_d_key(), action) {
              Some(PdfArray(_) as destination) =>
                self.read_destination(destination, shallow=true)
              _ => DestAction(self.direct(action))
            }
          } else {
            match self.lookup_direct(pdf_bookmark_d_key(), action) {
              Some(destination) => self.read_destination(destination)
              None => DestAction(self.direct(action))
            }
          }
      }
  }
}

///|
fn PdfDocument::pdf_bookmark_is_open(
  self : PdfDocument,
  outline : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_bookmark_count_key(), outline) {
    Some(PdfInteger(count)) => count > 0
    _ => false
  }
}

///|
fn PdfDocument::pdf_bookmark_colour_number(
  self : PdfDocument,
  object : PdfObject,
) -> Double? {
  try self.get_number(object) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn PdfDocument::pdf_bookmark_colour(
  self : PdfDocument,
  outline : PdfObject,
) -> PdfBookmarkColour {
  match self.lookup_direct(pdf_bookmark_colour_key(), outline) {
    Some(PdfArray([red, green, blue])) =>
      match
        (
          self.pdf_bookmark_colour_number(red),
          self.pdf_bookmark_colour_number(green),
          self.pdf_bookmark_colour_number(blue),
        ) {
        (Some(red), Some(green), Some(blue)) => { red, green, blue }
        _ => pdf_bookmark_black
      }
    _ => pdf_bookmark_black
  }
}

///|
fn PdfDocument::pdf_bookmark_flags(
  self : PdfDocument,
  outline : PdfObject,
) -> Int {
  match self.lookup_direct(pdf_bookmark_flags_key(), outline) {
    Some(PdfInteger(flags)) => flags
    _ => 0
  }
}

///|
fn PdfDocument::pdf_bookmark_of_outline(
  self : PdfDocument,
  level : Int,
  outline : PdfObject,
  preserve_actions : Bool,
) -> PdfBookmark raise PdfError {
  {
    level,
    text: self.pdf_bookmark_title(outline),
    target: self.pdf_bookmark_target(outline, preserve_actions),
    is_open: self.pdf_bookmark_is_open(outline),
    colour: self.pdf_bookmark_colour(outline),
    flags: self.pdf_bookmark_flags(outline),
  }
}

///|
fn PdfDocument::pdf_bookmark_traverse_siblings(
  self : PdfDocument,
  level : Int,
  first : PdfObject,
  preserve_actions : Bool,
  output : Array[PdfBookmark],
  depth : Int,
) -> Unit raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  output.push(self.pdf_bookmark_of_outline(level, first, preserve_actions))
  self.pdf_bookmark_traverse_children(
    level + 1,
    first,
    preserve_actions,
    output,
    depth + 1,
  )
  match self.lookup_direct(pdf_bookmark_next_key(), first) {
    Some(next) =>
      self.pdf_bookmark_traverse_siblings(
        level,
        next,
        preserve_actions,
        output,
        depth + 1,
      )
    None => ()
  }
}

///|
fn PdfDocument::pdf_bookmark_traverse_children(
  self : PdfDocument,
  level : Int,
  outline : PdfObject,
  preserve_actions : Bool,
  output : Array[PdfBookmark],
  depth : Int,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_bookmark_first_key(), outline) {
    Some(first) =>
      self.pdf_bookmark_traverse_siblings(
        level,
        first,
        preserve_actions,
        output,
        depth + 1,
      )
    None => ()
  }
}

///|
pub fn PdfDocument::read_bookmarks(
  self : PdfDocument,
  preserve_actions? : Bool = false,
) -> Array[PdfBookmark] raise PdfError {
  let output : Array[PdfBookmark] = []
  let root = self.lookup_object_or_null(self.root())
  if root == PdfNull {
    raise RootExpected
  }
  match self.lookup_direct(pdf_bookmark_outlines_key(), root) {
    Some(outlines) =>
      self.pdf_bookmark_traverse_children(
        0, outlines, preserve_actions, output, 0,
      )
    None => ()
  }
  output
}

///|
pub fn PdfDocument::remove_bookmarks(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.lookup_object_or_null(self.root())
  if root == PdfNull {
    raise RootExpected
  }
  let pdf = self.copy()
  let root_without_outlines = root.remove_dict_entry(
    pdf_bookmark_outlines_key(),
  )
  let new_root = pdf.add_object(root_without_outlines)
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf
    .trailer_dict()
    .add_dict_entry(pdf_bookmark_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
pub fn PdfDocument::transform_bookmark(
  self : PdfDocument,
  matrix : TransformMatrix,
  bookmark : PdfBookmark,
) -> PdfBookmark raise PdfError {
  { ..bookmark, target: self.transform_destination(matrix, bookmark.target) }
}
