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
) -> @destination.PdfDestination raise PdfError {
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
/// Read the document outline tree as flattened bookmarks.
///
/// When `preserve_actions` is false, actions with destinations are resolved to
/// destinations where possible. When it is true, action dictionaries and named
/// destinations are preserved more shallowly for round-tripping.
pub fn PdfDocument::read_bookmarks(
  self : PdfDocument,
  preserve_actions? : Bool = false,
) -> Array[PdfBookmark] raise PdfError {
  let output : Array[PdfBookmark] = []
  let root = self.pdf_bookmark_catalog()
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
/// Compatibility wrapper for `PdfDocument::read_bookmarks`.
pub fn pdf_read_bookmarks(
  document : PdfDocument,
  preserve_actions? : Bool = false,
) -> Array[PdfBookmark] raise PdfError {
  document.read_bookmarks(preserve_actions~)
}
