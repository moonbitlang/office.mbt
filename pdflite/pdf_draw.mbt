///|
/// Colour specification used by cpdf draw operations.
///
/// The `CYMK` spelling follows the OCaml source variant name in `cpdfdraw.ml`.
pub(all) enum PdfDrawColour {
  PdfDrawNoCol
  PdfDrawRGB(Double, Double, Double)
  PdfDrawGrey(Double)
  PdfDrawCYMK(Double, Double, Double, Double)
} derive(Debug, Eq, ToJson)

///|
/// Paragraph justification used by cpdf draw operations.
pub(all) enum PdfDrawJustification {
  PdfDrawLeft
  PdfDrawRight
  PdfDrawCentre
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfDrawExtGStateResource {
  kind : PdfName
  value : Double
  name : PdfName
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfDrawXObjectResource {
  source_name : String
  resource_name : PdfName
  object_number : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfDrawFontResource {
  identifier : String
  font_index : Int
  resource_name : PdfName
  object_number : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfDrawFontPackState {
  identifier : String
  fontpack : PdfFontPack
} derive(Debug, Eq, ToJson)

///|
/// Resource allocation state for rendering cpdf draw operations.
///
/// This ports the resource-numbering and ExtGState cache used by
/// `cpdfdraw.ml`'s `res`/`fresh_name`/`extgstate` helpers. Later rendering
/// slices will extend this state with paragraph and tagged-content resources.
pub(all) struct PdfDrawRenderState {
  mut resource_number : Int
  extgstates : Array[PdfDrawExtGStateResource]
  xobjects : Array[PdfDrawXObjectResource]
  form_xobjects : Array[PdfDrawXObjectResource]
  fonts : Array[PdfDrawFontResource]
  fontpacks : Array[PdfDrawFontPackState]
  mut current_fontpack_identifier : String
  mut current_fontpack : PdfFontPack
  mut font_size : Double
  page_names : Array[PdfName]
} derive(Debug, Eq, ToJson)

///|
fn pdf_draw_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_draw_extgstate_key_name : PdfName = pdf_draw_name("/ExtGState")

///|
let pdf_draw_xobject_key_name : PdfName = pdf_draw_name("/XObject")

///|
let pdf_draw_font_key_name : PdfName = pdf_draw_name("/Font")

///|
let pdf_draw_length_key_name : PdfName = pdf_draw_name("/Length")

///|
let pdf_draw_subtype_key_name : PdfName = pdf_draw_name("/Subtype")

///|
let pdf_draw_form_key_name : PdfName = pdf_draw_name("/Form")

///|
let pdf_draw_resources_key_name : PdfName = pdf_draw_name("/Resources")

///|
let pdf_draw_bbox_key_name : PdfName = pdf_draw_name("/BBox")

///|
let pdf_draw_fill_alpha_key_name : PdfName = pdf_draw_name("/ca")

///|
let pdf_draw_stroke_alpha_key_name : PdfName = pdf_draw_name("/CA")

///|
fn pdf_draw_extgstate_key() -> PdfName {
  pdf_draw_extgstate_key_name
}

///|
fn pdf_draw_xobject_key() -> PdfName {
  pdf_draw_xobject_key_name
}

///|
fn pdf_draw_font_key() -> PdfName {
  pdf_draw_font_key_name
}

///|
fn pdf_draw_length_key() -> PdfName {
  pdf_draw_length_key_name
}

///|
fn pdf_draw_subtype_key() -> PdfName {
  pdf_draw_subtype_key_name
}

///|
fn pdf_draw_form_key() -> PdfName {
  pdf_draw_form_key_name
}

///|
fn pdf_draw_resources_key() -> PdfName {
  pdf_draw_resources_key_name
}

///|
fn pdf_draw_bbox_key() -> PdfName {
  pdf_draw_bbox_key_name
}

///|
fn pdf_draw_fill_alpha_key() -> PdfName {
  pdf_draw_fill_alpha_key_name
}

///|
fn pdf_draw_stroke_alpha_key() -> PdfName {
  pdf_draw_stroke_alpha_key_name
}

///|
pub fn pdf_draw_render_state_new() -> PdfDrawRenderState {
  {
    resource_number: 0,
    extgstates: [],
    xobjects: [],
    form_xobjects: [],
    fonts: [],
    fontpacks: [],
    current_fontpack_identifier: "",
    current_fontpack: { fonts: [], entries: [] },
    font_size: 12.0,
    page_names: [],
  }
}

///|
fn PdfDrawRenderState::fresh_name(
  self : PdfDrawRenderState,
  prefix : String,
) -> PdfName {
  self.resource_number += 1
  pdf_draw_name(prefix + self.resource_number.to_string())
}

///|
fn PdfDrawRenderState::extgstate(
  self : PdfDrawRenderState,
  kind : PdfName,
  value : Double,
) -> PdfName {
  for entry in self.extgstates {
    if entry.kind == kind && entry.value == value {
      return entry.name
    }
  }
  let name = self.fresh_name("/G")
  self.extgstates.push({ kind, value, name })
  name
}

///|
fn PdfDrawRenderState::register_xobject(
  self : PdfDrawRenderState,
  source_name : String,
  prefix : String,
  object_number : Int,
) -> PdfName {
  let resource_name = self.fresh_name(prefix)
  for index in 0..<self.xobjects.length() {
    if self.xobjects[index].source_name == source_name {
      self.xobjects[index] = { source_name, resource_name, object_number }
      return resource_name
    }
  }
  self.xobjects.push({ source_name, resource_name, object_number })
  resource_name
}

///|
fn PdfDrawRenderState::register_form_xobject(
  self : PdfDrawRenderState,
  source_name : String,
  object_number : Int,
) -> PdfName {
  let resource_name = self.fresh_name("/X")
  for index in 0..<self.form_xobjects.length() {
    if self.form_xobjects[index].source_name == source_name {
      self.form_xobjects[index] = { source_name, resource_name, object_number }
      return resource_name
    }
  }
  self.form_xobjects.push({ source_name, resource_name, object_number })
  resource_name
}

///|
fn PdfDrawRenderState::stored_fontpack(
  self : PdfDrawRenderState,
  identifier : String,
) -> PdfFontPack? {
  for entry in self.fontpacks {
    if entry.identifier == identifier {
      return Some(entry.fontpack)
    }
  }
  None
}

///|
fn PdfDrawRenderState::ensure_fontpack(
  self : PdfDrawRenderState,
  identifier : String,
  fontpack : PdfFontPack,
) -> PdfFontPack {
  match self.stored_fontpack(identifier) {
    Some(stored) => stored
    None => {
      self.fontpacks.push({ identifier, fontpack })
      fontpack
    }
  }
}

///|
fn PdfDrawRenderState::stored_font_resource(
  self : PdfDrawRenderState,
  identifier : String,
  font_index : Int,
) -> PdfDrawFontResource? {
  for resource in self.fonts {
    if resource.identifier == identifier && resource.font_index == font_index {
      return Some(resource)
    }
  }
  None
}

///|
fn PdfDrawRenderState::register_font_resource(
  self : PdfDrawRenderState,
  identifier : String,
  font_index : Int,
  object_number : Int,
) -> PdfName {
  let resource_name = self.fresh_name("/F")
  self.fonts.push({ identifier, font_index, resource_name, object_number })
  resource_name
}

///|
fn PdfDrawRenderState::register_fontpack_resources(
  self : PdfDrawRenderState,
  identifier : String,
  fontpack : PdfFontPack,
  document : PdfDocument,
) -> Unit raise PdfError {
  let stored = self.ensure_fontpack(identifier, fontpack)
  for index in 0..<stored.fonts.length() {
    let resource = match self.stored_font_resource(identifier, index) {
      Some(resource) => resource
      None => {
        let object_number = document.write_font(stored.fonts[index])
        let resource_name = self.register_font_resource(
          identifier, index, object_number,
        )
        { identifier, font_index: index, resource_name, object_number }
      }
    }
    self.mark_page_resource(resource.resource_name)
  }
}

///|
fn PdfDrawRenderState::mark_page_resource(
  self : PdfDrawRenderState,
  resource_name : PdfName,
) -> Unit {
  for name in self.page_names {
    if name == resource_name {
      return
    }
  }
  self.page_names.push(resource_name)
}

///|
fn PdfDrawRenderState::image_resource_name(
  self : PdfDrawRenderState,
  source_name : String,
) -> PdfName raise PdfError {
  for entry in self.xobjects {
    if entry.source_name == source_name {
      self.mark_page_resource(entry.resource_name)
      return entry.resource_name
    }
  }
  raise SoftError("Image not found: " + source_name)
}

///|
fn PdfDrawRenderState::form_resource_name(
  self : PdfDrawRenderState,
  source_name : String,
) -> PdfName raise PdfError {
  for entry in self.form_xobjects {
    if entry.source_name == source_name {
      self.mark_page_resource(entry.resource_name)
      return entry.resource_name
    }
  }
  raise SoftError("Form XObject not found: " + source_name)
}

///|
fn PdfDrawRenderState::font_resource_name(
  self : PdfDrawRenderState,
  identifier : String,
  font_index : Int,
) -> PdfName raise PdfError {
  match self.stored_font_resource(identifier, font_index) {
    Some(resource) => {
      self.mark_page_resource(resource.resource_name)
      resource.resource_name
    }
    None => raise SoftError("Font resource not found: " + identifier)
  }
}

///|
fn PdfDrawRenderState::set_current_font(
  self : PdfDrawRenderState,
  identifier : String,
  size : Double,
) -> Unit raise PdfError {
  match self.stored_fontpack(identifier) {
    Some(fontpack) => {
      self.current_fontpack_identifier = identifier
      self.current_fontpack = fontpack
      self.font_size = size
    }
    None => raise SoftError("FontPack not found: " + identifier)
  }
}

///|
fn PdfDrawRenderState::text_ops(
  self : PdfDrawRenderState,
  text : String,
) -> Array[PdfContentOp] raise PdfError {
  if self.current_fontpack_identifier == "" {
    raise SoftError("FontPack not selected")
  }
  let triples : Array[(Int, Int, PdfFont)] = []
  for codepoint in pdf_codepoints_of_utf8(@utf8.encode(text)) {
    match self.current_fontpack.get_char(codepoint) {
      Some(triple) => triples.push(triple)
      None => ()
    }
  }
  let output : Array[PdfContentOp] = []
  for run in pdf_fontpack_collate_runs(triples) {
    guard run.length() > 0 else { continue }
    let font_index = run[0].1
    let resource_name = self.font_resource_name(
      self.current_fontpack_identifier,
      font_index,
    )
    let bytes : Array[Byte] = []
    for triple in run {
      bytes.push(pdf_byte_of_int(triple.0))
    }
    output.push(Op_Tf(resource_name, self.font_size))
    output.push(Op_Tj(Bytes::from_array(bytes)))
  }
  output
}

///|
fn pdf_draw_copy_xobject_resources(
  resources : ArrayView[PdfDrawXObjectResource],
) -> Array[PdfDrawXObjectResource] {
  let output : Array[PdfDrawXObjectResource] = []
  for entry in resources {
    output.push(entry)
  }
  output
}

///|
fn pdf_draw_copy_font_resources(
  resources : ArrayView[PdfDrawFontResource],
) -> Array[PdfDrawFontResource] {
  let output : Array[PdfDrawFontResource] = []
  for entry in resources {
    output.push(entry)
  }
  output
}

///|
fn pdf_draw_copy_fontpacks(
  fontpacks : ArrayView[PdfDrawFontPackState],
) -> Array[PdfDrawFontPackState] {
  let output : Array[PdfDrawFontPackState] = []
  for entry in fontpacks {
    output.push(entry)
  }
  output
}

///|
fn pdf_draw_copy_page_names(names : ArrayView[PdfName]) -> Array[PdfName] {
  let output : Array[PdfName] = []
  for name in names {
    output.push(name)
  }
  output
}

///|
fn PdfDrawRenderState::nested_form_state(
  self : PdfDrawRenderState,
) -> PdfDrawRenderState {
  {
    resource_number: self.resource_number,
    extgstates: [],
    xobjects: pdf_draw_copy_xobject_resources(self.xobjects),
    form_xobjects: pdf_draw_copy_xobject_resources(self.form_xobjects),
    fonts: pdf_draw_copy_font_resources(self.fonts),
    fontpacks: pdf_draw_copy_fontpacks(self.fontpacks),
    current_fontpack_identifier: self.current_fontpack_identifier,
    current_fontpack: self.current_fontpack,
    font_size: self.font_size,
    page_names: pdf_draw_copy_page_names(self.page_names),
  }
}

///|
fn PdfDrawRenderState::adopt_resource_number(
  self : PdfDrawRenderState,
  child : PdfDrawRenderState,
) -> Unit {
  if child.resource_number > self.resource_number {
    self.resource_number = child.resource_number
  }
}

///|
fn pdf_draw_resource_is_used(
  page_names : ArrayView[PdfName],
  name : PdfName,
) -> Bool {
  for page_name in page_names {
    if page_name == name {
      return true
    }
  }
  false
}

///|
/// Return the resource dictionary needed by the operations rendered so far.
pub fn PdfDrawRenderState::resources(self : PdfDrawRenderState) -> PdfObject {
  let states : Array[(PdfName, PdfObject)] = []
  for entry in self.extgstates {
    states.push(
      (entry.name, PdfDictionary([(entry.kind, PdfReal(entry.value))])),
    )
  }
  let xobjects : Array[(PdfName, PdfObject)] = []
  for entry in self.xobjects {
    if pdf_draw_resource_is_used(self.page_names, entry.resource_name) {
      xobjects.push((entry.resource_name, PdfIndirect(entry.object_number)))
    }
  }
  for entry in self.form_xobjects {
    if pdf_draw_resource_is_used(self.page_names, entry.resource_name) {
      xobjects.push((entry.resource_name, PdfIndirect(entry.object_number)))
    }
  }
  let fonts : Array[(PdfName, PdfObject)] = []
  for entry in self.fonts {
    if pdf_draw_resource_is_used(self.page_names, entry.resource_name) {
      fonts.push((entry.resource_name, PdfIndirect(entry.object_number)))
    }
  }
  let resources : Array[(PdfName, PdfObject)] = []
  if xobjects.length() > 0 {
    resources.push((pdf_draw_xobject_key(), PdfDictionary(xobjects)))
  }
  if states.length() > 0 {
    resources.push((pdf_draw_extgstate_key(), PdfDictionary(states)))
  }
  if fonts.length() > 0 {
    resources.push((pdf_draw_font_key(), PdfDictionary(fonts)))
  }
  PdfDictionary(resources)
}

///|
/// Source-level cpdf draw operation.
///
/// This mirrors the operation shape from `cpdfdraw.ml`. The first rendering
/// slice converts path, graphics-state, colour, matrix, and paint operations to
/// `PdfContentOp`; text, image, form, and structure operations are represented
/// here and will be rendered by later cpdfdraw slices.
pub(all) enum PdfDrawOp {
  PdfDrawRect(Double, Double, Double, Double)
  PdfDrawBezier(Double, Double, Double, Double, Double, Double)
  PdfDrawBezier23(Double, Double, Double, Double)
  PdfDrawBezier13(Double, Double, Double, Double)
  PdfDrawTo(Double, Double)
  PdfDrawLine(Double, Double)
  PdfDrawClosePath
  PdfDrawSetFill(PdfDrawColour)
  PdfDrawSetStroke(PdfDrawColour)
  PdfDrawSetLineThickness(Double)
  PdfDrawSetLineCap(Int)
  PdfDrawSetLineJoin(Int)
  PdfDrawSetMiterLimit(Double)
  PdfDrawSetDashPattern(Array[Double], Double)
  PdfDrawMatrix(TransformMatrix)
  PdfDrawQq(Array[PdfDrawOp])
  PdfDrawFill
  PdfDrawFillEvenOdd
  PdfDrawStroke
  PdfDrawFillStroke
  PdfDrawFillStrokeEvenOdd
  PdfDrawClip
  PdfDrawClipEvenOdd
  PdfDrawFormXObject(Double, Double, Double, Double, String, Array[PdfDrawOp])
  PdfDrawUse(String)
  PdfDrawImageXObject(String, PdfObject)
  PdfDrawImage(String)
  PdfDrawNewPage
  PdfDrawOpacity(Double)
  PdfDrawSOpacity(Double)
  PdfDrawFontPack(String, PdfFontPack, Array[Int])
  PdfDrawFont(String, Double)
  PdfDrawTextSection(Array[PdfDrawOp])
  PdfDrawText(String)
  PdfDrawSpecialText(String)
  PdfDrawPara(Double?, PdfDrawJustification, Double, Array[String])
  PdfDrawNewline
  PdfDrawLeading(Double)
  PdfDrawCharSpace(Double)
  PdfDrawWordSpace(Double)
  PdfDrawTextScale(Double)
  PdfDrawRenderMode(Int)
  PdfDrawRise(Double)
  PdfDrawTag(String)
  PdfDrawEndTag
  PdfDrawSTag(String)
  PdfDrawEndSTag
  PdfDrawBeginArtifact
  PdfDrawEndArtifact
  PdfDrawNamespace(String)
  PdfDrawEltInfo(String, PdfObject)
  PdfDrawEndEltInfo(String)
  PdfDrawAutoTag(Bool)
} derive(Debug, Eq, ToJson)

///|
fn pdf_draw_colour_fill_ops(colour : PdfDrawColour) -> Array[PdfContentOp] {
  match colour {
    PdfDrawNoCol => []
    PdfDrawRGB(r, g, b) => [Op_rg(r, g, b)]
    PdfDrawGrey(g) => [Op_g(g)]
    PdfDrawCYMK(c, m, y, k) => [Op_k(c, m, y, k)]
  }
}

///|
fn pdf_draw_colour_stroke_ops(colour : PdfDrawColour) -> Array[PdfContentOp] {
  match colour {
    PdfDrawNoCol => []
    PdfDrawRGB(r, g, b) => [Op_RG(r, g, b)]
    PdfDrawGrey(g) => [Op_G(g)]
    PdfDrawCYMK(c, m, y, k) => [Op_K(c, m, y, k)]
  }
}

///|
/// Convert a cpdf content colour into the draw colour variant.
pub fn PdfContentColour::to_draw_colour(
  self : PdfContentColour,
) -> PdfDrawColour {
  match self {
    PdfContentGrey(grey) => PdfDrawGrey(grey)
    PdfContentRGB(red, green, blue) => PdfDrawRGB(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      PdfDrawCYMK(cyan, magenta, yellow, black)
  }
}

///|
/// Parse a cpdf draw-control colour argument.
///
/// This ports `cpdfdrawcontrol.ml`'s `parse_colour`/`col_of_string` path while
/// preserving the draw-layer `NoCol` sentinel separately from content colours.
pub fn pdf_parse_draw_colour(text : String) -> PdfDrawColour raise PdfError {
  pdf_parse_content_colour(text).to_draw_colour()
}

///|
/// Parse a cpdf draw colour, returning `PdfDrawNoCol` on malformed input.
pub fn pdf_draw_colour_of_string(text : String) -> PdfDrawColour {
  pdf_parse_draw_colour(text) catch {
    _ => PdfDrawNoCol
  }
}

///|
fn pdf_draw_content_unsupported(
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  raise SoftError("Cpdfdraw: unsupported draw operation " + op.debug_name())
}

///|
fn pdf_draw_form_xobject_stream(
  bbox : (Double, Double, Double, Double),
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> PdfObject raise PdfError {
  let data = pdf_content_bytes_of_ops(ops)
  let (a, b, c, d) = bbox
  pdf_stream(
    PdfDictionary([
      (pdf_draw_length_key(), PdfInteger(data.length())),
      (pdf_draw_subtype_key(), PdfNameObject(pdf_draw_form_key())),
      (pdf_draw_resources_key(), resources),
      (
        pdf_draw_bbox_key(),
        PdfArray([PdfReal(a), PdfReal(b), PdfReal(c), PdfReal(d)]),
      ),
    ]),
    StreamGot(data),
  )
}

///|
fn PdfDrawOp::to_content_ops_internal(
  self : PdfDrawOp,
  state : PdfDrawRenderState?,
  document : PdfDocument?,
) -> Array[PdfContentOp] raise PdfError {
  match self {
    PdfDrawQq(ops) => {
      let output : Array[PdfContentOp] = [Op_q]
      for op in ops {
        for content_op in op.to_content_ops_internal(state, document) {
          output.push(content_op)
        }
      }
      output.push(Op_Q)
      output
    }
    PdfDrawTextSection(ops) => {
      let output : Array[PdfContentOp] = [Op_BT]
      for op in ops {
        for content_op in op.to_content_ops_internal(state, document) {
          output.push(content_op)
        }
      }
      output.push(Op_ET)
      output
    }
    PdfDrawSetFill(colour) => pdf_draw_colour_fill_ops(colour)
    PdfDrawSetStroke(colour) => pdf_draw_colour_stroke_ops(colour)
    PdfDrawSetLineThickness(width) => [Op_w(width)]
    PdfDrawSetLineCap(cap) => [Op_J(cap)]
    PdfDrawSetLineJoin(join) => [Op_j(join)]
    PdfDrawSetMiterLimit(limit) => [Op_M(limit)]
    PdfDrawSetDashPattern(dashes, phase) => [Op_d(dashes, phase)]
    PdfDrawMatrix(matrix) => [Op_cm(matrix)]
    PdfDrawRect(x, y, w, h) => [Op_re(x, y, w, h)]
    PdfDrawBezier(x1, y1, x2, y2, x3, y3) => [Op_c(x1, y1, x2, y2, x3, y3)]
    PdfDrawBezier23(x2, y2, x3, y3) => [Op_v(x2, y2, x3, y3)]
    PdfDrawBezier13(x1, y1, x3, y3) => [Op_y(x1, y1, x3, y3)]
    PdfDrawTo(x, y) => [Op_m(x, y)]
    PdfDrawLine(x, y) => [Op_l(x, y)]
    PdfDrawClosePath => [Op_h]
    PdfDrawFill => [Op_f]
    PdfDrawFillEvenOdd => [Op_fstar]
    PdfDrawStroke => [Op_S]
    PdfDrawFillStroke => [Op_B]
    PdfDrawFillStrokeEvenOdd => [Op_Bstar]
    PdfDrawClip => [Op_W, Op_n]
    PdfDrawClipEvenOdd => [Op_Wstar, Op_n]
    PdfDrawFormXObject(a, b, c, d, source_name, ops) =>
      match (state, document) {
        (Some(state), Some(document)) => {
          let form_state = state.nested_form_state()
          let content_ops = pdf_drawops_to_content_ops_with_document(
            form_state, document, ops,
          )
          let form_object = pdf_draw_form_xobject_stream(
            (a, b, c, d),
            form_state.resources(),
            content_ops,
          )
          state.adopt_resource_number(form_state)
          let object_number = document.add_object(form_object)
          let _ = state.register_form_xobject(source_name, object_number)
          []
        }
        _ => pdf_draw_content_unsupported(self)
      }
    PdfDrawUse(source_name) =>
      match state {
        Some(state) => [Op_Do(state.form_resource_name(source_name))]
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawImage(source_name) =>
      match state {
        Some(state) => [Op_Do(state.image_resource_name(source_name))]
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawImageXObject(source_name, object) =>
      match (state, document) {
        (Some(state), Some(document)) => {
          let object_number = document.add_object(object)
          let _ = state.register_xobject(source_name, "/I", object_number)
          []
        }
        _ => pdf_draw_content_unsupported(self)
      }
    PdfDrawFontPack(identifier, fontpack, codepoints) =>
      match (state, document) {
        (Some(state), Some(document)) => {
          ignore(codepoints)
          state.register_fontpack_resources(identifier, fontpack, document)
          []
        }
        _ => pdf_draw_content_unsupported(self)
      }
    PdfDrawFont(identifier, size) =>
      match state {
        Some(state) => {
          state.set_current_font(identifier, size)
          []
        }
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawText(text) =>
      match state {
        Some(state) => state.text_ops(text)
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawOpacity(value) =>
      match state {
        Some(state) =>
          [Op_gs(state.extgstate(pdf_draw_fill_alpha_key(), value))]
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawSOpacity(value) =>
      match state {
        Some(state) =>
          [Op_gs(state.extgstate(pdf_draw_stroke_alpha_key(), value))]
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawLeading(leading) => [Op_TL(leading)]
    PdfDrawCharSpace(spacing) => [Op_Tc(spacing)]
    PdfDrawWordSpace(spacing) => [Op_Tw(spacing)]
    PdfDrawTextScale(scale) => [Op_Tz(scale)]
    PdfDrawRenderMode(mode) => [Op_Tr(mode)]
    PdfDrawRise(rise) => [Op_Ts(rise)]
    PdfDrawNewline => [Op_Tstar]
    _ => pdf_draw_content_unsupported(self)
  }
}

///|
/// Return the cpdf diagnostic spelling for one draw operation.
pub fn PdfDrawOp::debug_name(self : PdfDrawOp) -> String {
  match self {
    PdfDrawQq(ops) => "Qq (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawFormXObject(_, _, _, _, _, ops) =>
      "FormXObject (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawTextSection(ops) =>
      "TextSection (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawRect(_, _, _, _) => "Rect"
    PdfDrawBezier(_, _, _, _, _, _) => "Bezier"
    PdfDrawBezier23(_, _, _, _) => "Bezier23"
    PdfDrawBezier13(_, _, _, _) => "Bezier13"
    PdfDrawTo(_, _) => "To"
    PdfDrawLine(_, _) => "Line"
    PdfDrawClosePath => "ClosePath"
    PdfDrawSetFill(_) => "SetFill"
    PdfDrawSetStroke(_) => "SetStroke"
    PdfDrawSetLineThickness(_) => "SetLineThickness"
    PdfDrawSetLineCap(_) => "SetLineCap"
    PdfDrawSetLineJoin(_) => "SetLineJoin"
    PdfDrawSetMiterLimit(_) => "SetMiterLimit"
    PdfDrawSetDashPattern(_, _) => "SetDashPattern"
    PdfDrawMatrix(_) => "SetMatrix"
    PdfDrawFill => "Fill"
    PdfDrawFillEvenOdd => "FillEvenOdd"
    PdfDrawStroke => "Stroke"
    PdfDrawFillStroke => "FillStroke"
    PdfDrawFillStrokeEvenOdd => "FillStrokeEvenOdd"
    PdfDrawClip => "Clip"
    PdfDrawClipEvenOdd => "ClipEvenOdd"
    PdfDrawUse(_) => "Use"
    PdfDrawImageXObject(_, _) => "ImageXObject"
    PdfDrawImage(_) => "Image"
    PdfDrawNewPage => "NewPage"
    PdfDrawOpacity(_) => "Opacity"
    PdfDrawSOpacity(_) => "SOpacity"
    PdfDrawFontPack(name, _, _) => "FontPack " + name + " "
    PdfDrawFont(font, _) => "Font " + font + " "
    PdfDrawText(_) => "Text"
    PdfDrawSpecialText(_) => "SpecialText"
    PdfDrawPara(_, _, _, _) => "Para"
    PdfDrawNewline => "Newline"
    PdfDrawLeading(_) => "Leading"
    PdfDrawCharSpace(_) => "CharSpace"
    PdfDrawWordSpace(_) => "WordSpace"
    PdfDrawTextScale(_) => "TextScale"
    PdfDrawRenderMode(_) => "RenderMode"
    PdfDrawRise(_) => "Rise"
    PdfDrawEndTag => "EndTag"
    PdfDrawTag(name) => "Tag " + name
    PdfDrawEndSTag => "EndSTag"
    PdfDrawSTag(name) => "Tag " + name
    PdfDrawBeginArtifact => "BeginArtifact"
    PdfDrawEndArtifact => "EndArtifact"
    PdfDrawNamespace(name) => "Namespace " + name
    PdfDrawEltInfo(_, _) => "EltInfo"
    PdfDrawEndEltInfo(_) => "EndEltInfo"
    PdfDrawAutoTag(_) => "AutoTag"
  }
}

///|
/// Return cpdf's space-prefixed diagnostic string for a list of draw ops.
pub fn pdf_string_of_drawops(ops : ArrayView[PdfDrawOp]) -> String {
  let mut output = ""
  for op in ops {
    output = output + " " + op.debug_name()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDrawOp::debug_name`.
pub fn pdf_string_of_drawop(op : PdfDrawOp) -> String {
  op.debug_name()
}

///|
/// Convert one cpdf draw operation to flat PDF content operators.
///
/// The currently ported rendering subset covers the direct operator mappings in
/// the front of `cpdfdraw.ml`'s `ops_of_drawop`: graphics state, matrix, path,
/// colour, paint, clip, and `q`/`Q` grouping. Later slices will fill in forms,
/// images, text, and tagged-content rendering.
pub fn PdfDrawOp::to_content_ops(
  self : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(None, None)
}

///|
/// Convert one cpdf draw operation using resource allocation state.
pub fn PdfDrawOp::to_content_ops_with_state(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), None)
}

///|
/// Convert one cpdf draw operation using resource state and a document for
/// indirect object allocation.
pub fn PdfDrawOp::to_content_ops_with_document(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  document : PdfDocument,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), Some(document))
}

///|
/// Convert a sequence of cpdf draw operations to flat PDF content operators.
pub fn pdf_drawops_to_content_ops(
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  for op in ops {
    for content_op in op.to_content_ops() {
      output.push(content_op)
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops`.
pub fn pdf_drawop_to_content_ops(
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops()
}

///|
/// Convert a sequence of cpdf draw operations using resource allocation state.
pub fn pdf_drawops_to_content_ops_with_state(
  state : PdfDrawRenderState,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  for op in ops {
    for content_op in op.to_content_ops_with_state(state) {
      output.push(content_op)
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_state`.
pub fn pdf_drawop_to_content_ops_with_state(
  state : PdfDrawRenderState,
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops_with_state(state)
}

///|
/// Convert a sequence of cpdf draw operations using resource state and a
/// document for indirect object allocation.
pub fn pdf_drawops_to_content_ops_with_document(
  state : PdfDrawRenderState,
  document : PdfDocument,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  for op in ops {
    for content_op in op.to_content_ops_with_document(state, document) {
      output.push(content_op)
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_document`.
pub fn pdf_drawop_to_content_ops_with_document(
  state : PdfDrawRenderState,
  document : PdfDocument,
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops_with_document(state, document)
}
