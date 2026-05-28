///|
fn PdfContentOperatorState::content_clipping_content_state(
  self : PdfContentOperatorState,
) -> PdfContentState {
  PdfContentStateClipping(
    pdf_content_clipping_state_of_paths(self.clipping_path),
  )
}

///|
fn PdfContentOperatorState::content_path_content_state(
  self : PdfContentOperatorState,
) -> PdfContentState {
  PdfContentStatePath(
    self.path_state.content_with_clipping_path(self.clipping_path),
  )
}

///|
/// Return the cpdfcontent JSON entry for the current drawn path, when nonempty.
pub fn PdfContentOperatorState::content_path_entry(
  self : PdfContentOperatorState,
  stroking : Bool,
) -> PdfContentJsonEntry? {
  match
    self.path.path.content_bounding_box(
      self.ctm,
      self.path_state.line_width,
      stroking,
    ) {
    Some(bounding_box) =>
      Some({
        object: PdfContentPathObject(self.path),
        state: self.content_path_content_state(),
        bounding_box,
      })
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_path_entry`.
pub fn pdf_content_path_entry(
  state : PdfContentOperatorState,
  stroking : Bool,
) -> PdfContentJsonEntry? {
  state.content_path_entry(stroking)
}

///|
fn pdf_content_rectangle_bounding_box(
  rectangle : PdfRectangle,
) -> PdfContentBoundingBox {
  {
    x0: rectangle.min_x,
    y0: rectangle.min_y,
    x1: rectangle.min_x,
    y1: rectangle.max_y,
    x2: rectangle.max_x,
    y2: rectangle.max_y,
    x3: rectangle.max_x,
    y3: rectangle.min_y,
  }
}

///|
fn PdfContentOperatorState::content_unbounded_shading_bounding_box(
  self : PdfContentOperatorState,
) -> PdfContentBoundingBox? {
  if self.clipping_path.length() == 0 {
    None
  } else {
    self.clipping_path[0].content_bounding_box(
      self.ctm,
      self.path_state.line_width,
      false,
    )
  }
}

///|
/// Return the cpdfcontent JSON entry for a shading, when its bbox is valid.
pub fn PdfContentOperatorState::content_shading_entry(
  self : PdfContentOperatorState,
  name : PdfName,
  shading_bbox : PdfRectangle?,
) -> PdfContentJsonEntry? {
  let bounding_box = match shading_bbox {
    Some(rectangle) => Some(pdf_content_rectangle_bounding_box(rectangle))
    None => self.content_unbounded_shading_bounding_box()
  }
  match bounding_box {
    Some(bounding_box) =>
      Some({
        object: PdfContentShadingObject(pdf_content_state_name_text(name)),
        state: self.content_clipping_content_state(),
        bounding_box,
      })
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_shading_entry`.
pub fn pdf_content_shading_entry(
  state : PdfContentOperatorState,
  name : PdfName,
  shading_bbox : PdfRectangle?,
) -> PdfContentJsonEntry? {
  state.content_shading_entry(name, shading_bbox)
}

///|
/// Look up a named shading resource and return its cpdfcontent JSON entry.
pub fn PdfDocument::content_shading_entry_from_resources(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentJsonEntry? {
  match self.lookup_direct(pdf_content_shading_shading_name, resources) {
    Some(shading_dictionary) =>
      match self.lookup_direct(name, shading_dictionary) {
        Some(shading_object) =>
          try
            self.content_read_shading(
              transform_identity_matrix,
              PdfNull,
              shading_object,
            )
          catch {
            _ => None
          } noraise {
            shading =>
              match shading.shading_bbox {
                Some(bbox_object) =>
                  try self.parse_rectangle(bbox_object) catch {
                    _ => None
                  } noraise {
                    rectangle =>
                      state.content_shading_entry(name, Some(rectangle))
                  }
                None => state.content_shading_entry(name, None)
              }
          }
        None => None
      }
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_shading_entry_from_resources`.
pub fn pdf_content_shading_entry_from_resources(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentJsonEntry? {
  document.content_shading_entry_from_resources(state, resources, name)
}

///|
/// Return the CTM-transformed unit-square bounding box used for image objects.
pub fn PdfContentOperatorState::content_unit_square_bounding_box(
  self : PdfContentOperatorState,
) -> PdfContentBoundingBox {
  let p0 = self.ctm.apply(point2(0.0, 0.0))
  let p1 = self.ctm.apply(point2(0.0, 1.0))
  let p2 = self.ctm.apply(point2(1.0, 1.0))
  let p3 = self.ctm.apply(point2(1.0, 0.0))
  {
    x0: p0.x,
    y0: p0.y,
    x1: p1.x,
    y1: p1.y,
    x2: p2.x,
    y2: p2.y,
    x3: p3.x,
    y3: p3.y,
  }
}

///|
/// Return the cpdfcontent JSON entry for an inline image at the current CTM.
pub fn PdfContentOperatorState::content_inline_image_entry(
  self : PdfContentOperatorState,
) -> PdfContentJsonEntry {
  {
    object: PdfContentInlineImageObject,
    state: self.content_clipping_content_state(),
    bounding_box: self.content_unit_square_bounding_box(),
  }
}

///|
/// Return the cpdfcontent JSON entry for an image XObject at the current CTM.
pub fn PdfContentOperatorState::content_image_entry(
  self : PdfContentOperatorState,
  name : PdfName,
) -> PdfContentJsonEntry {
  {
    object: PdfContentImageObject(pdf_content_state_name_text(name)),
    state: self.content_clipping_content_state(),
    bounding_box: self.content_unit_square_bounding_box(),
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_inline_image_entry`.
pub fn pdf_content_inline_image_entry(
  state : PdfContentOperatorState,
) -> PdfContentJsonEntry {
  state.content_inline_image_entry()
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_image_entry`.
pub fn pdf_content_image_entry(
  state : PdfContentOperatorState,
  name : PdfName,
) -> PdfContentJsonEntry {
  state.content_image_entry(name)
}

///|
fn PdfDocument::content_xobject_from_resources(
  self : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> PdfObject raise PdfError {
  match self.lookup_direct(pdf_xobject_xobject(), resources) {
    Some(xobjects) =>
      match self.lookup_direct(name, xobjects) {
        Some(xobject) => xobject
        None => raise SoftError("Unknown xobject")
      }
    None => raise SoftError("xobject not found")
  }
}

///|
/// Look up a named image XObject resource and return its cpdfcontent JSON entry.
pub fn PdfDocument::content_image_entry_from_resources(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentJsonEntry? raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() =>
      Some(state.content_image_entry(name))
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() => None
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_image_entry_from_resources`.
pub fn pdf_content_image_entry_from_resources(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentJsonEntry? raise PdfError {
  document.content_image_entry_from_resources(state, resources, name)
}
