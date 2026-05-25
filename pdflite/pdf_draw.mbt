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
pub(all) enum PdfDrawStructureData {
  PdfDrawStructureMCID(String, Int, Int)
  PdfDrawStructureBeginTree(String)
  PdfDrawStructureEndTree
  PdfDrawStructureNamespace(String)
  PdfDrawStructureElementInfo(String, PdfObject)
  PdfDrawStructureEndElementInfo(String)
} derive(Debug, Eq, ToJson)

///|
/// Page-local context used to render `PdfDrawSpecialText`.
pub(all) struct PdfDrawSpecialTextContext {
  time : PdfStrftimeTime
  replacement_values : PdfAddTextReplacementValues
} derive(Debug, Eq, ToJson)

///|
/// Resource allocation state for rendering cpdf draw operations.
///
/// This ports the resource-numbering and ExtGState cache used by
/// `cpdfdraw.ml`'s `res`/`fresh_name`/`extgstate` helpers. Later rendering
/// slices will extend this state with tagged-content resources.
pub(all) struct PdfDrawRenderState {
  mut resource_number : Int
  mut marked_content_id : Int
  extgstates : Array[PdfDrawExtGStateResource]
  xobjects : Array[PdfDrawXObjectResource]
  form_xobjects : Array[PdfDrawXObjectResource]
  fonts : Array[PdfDrawFontResource]
  fontpacks : Array[PdfDrawFontPackState]
  mut current_fontpack_identifier : String
  mut current_fontpack : PdfFontPack
  mut font_size : Double
  mut structure_tree_enabled : Bool
  mut auto_tag : Bool
  mut structure_page_number : Int
  structure_data : Array[PdfDrawStructureData]
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
let pdf_draw_mcid_key_name : PdfName = pdf_draw_name("/MCID")

///|
let pdf_draw_type_key_name : PdfName = pdf_draw_name("/Type")

///|
let pdf_draw_struct_tree_root_key_name : PdfName = pdf_draw_name(
  "/StructTreeRoot",
)

///|
let pdf_draw_parent_tree_key_name : PdfName = pdf_draw_name("/ParentTree")

///|
let pdf_draw_s_key_name : PdfName = pdf_draw_name("/S")

///|
let pdf_draw_p_key_name : PdfName = pdf_draw_name("/P")

///|
let pdf_draw_k_key_name : PdfName = pdf_draw_name("/K")

///|
let pdf_draw_pg_key_name : PdfName = pdf_draw_name("/Pg")

///|
let pdf_draw_ns_key_name : PdfName = pdf_draw_name("/NS")

///|
let pdf_draw_namespaces_key_name : PdfName = pdf_draw_name("/Namespaces")

///|
let pdf_draw_role_map_key_name : PdfName = pdf_draw_name("/RoleMap")

///|
let pdf_draw_struct_parents_key_name : PdfName = pdf_draw_name("/StructParents")

///|
let pdf_draw_begin_artifact_name : PdfName = pdf_draw_name("/BeginArtifact")

///|
let pdf_draw_end_artifact_name : PdfName = pdf_draw_name("/EndArtifact")

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
fn pdf_draw_mcid_key() -> PdfName {
  pdf_draw_mcid_key_name
}

///|
fn pdf_draw_type_key() -> PdfName {
  pdf_draw_type_key_name
}

///|
fn pdf_draw_struct_tree_root_key() -> PdfName {
  pdf_draw_struct_tree_root_key_name
}

///|
fn pdf_draw_parent_tree_key() -> PdfName {
  pdf_draw_parent_tree_key_name
}

///|
fn pdf_draw_s_key() -> PdfName {
  pdf_draw_s_key_name
}

///|
fn pdf_draw_p_key() -> PdfName {
  pdf_draw_p_key_name
}

///|
fn pdf_draw_k_key() -> PdfName {
  pdf_draw_k_key_name
}

///|
fn pdf_draw_pg_key() -> PdfName {
  pdf_draw_pg_key_name
}

///|
fn pdf_draw_ns_key() -> PdfName {
  pdf_draw_ns_key_name
}

///|
fn pdf_draw_namespaces_key() -> PdfName {
  pdf_draw_namespaces_key_name
}

///|
fn pdf_draw_role_map_key() -> PdfName {
  pdf_draw_role_map_key_name
}

///|
fn pdf_draw_struct_parents_key() -> PdfName {
  pdf_draw_struct_parents_key_name
}

///|
fn pdf_draw_begin_artifact() -> PdfName {
  pdf_draw_begin_artifact_name
}

///|
fn pdf_draw_end_artifact() -> PdfName {
  pdf_draw_end_artifact_name
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
    marked_content_id: -1,
    extgstates: [],
    xobjects: [],
    form_xobjects: [],
    fonts: [],
    fontpacks: [],
    current_fontpack_identifier: "",
    current_fontpack: { fonts: [], entries: [] },
    font_size: 12.0,
    structure_tree_enabled: false,
    auto_tag: true,
    structure_page_number: 0,
    structure_data: [],
    page_names: [],
  }
}

///|
/// Build a special-text context from explicit replacement values.
pub fn pdf_draw_special_text_context(
  time : PdfStrftimeTime,
  replacement_values : PdfAddTextReplacementValues,
) -> PdfDrawSpecialTextContext {
  { time, replacement_values }
}

///|
/// Build cpdf draw special-text context for one page of a document.
pub fn PdfDocument::draw_special_text_context(
  self : PdfDocument,
  page_number : Int,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  time? : PdfStrftimeTime? = None,
) -> PdfDrawSpecialTextContext raise PdfError {
  let resolved_time = match time {
    Some(value) => value
    None => pdf_strftime_dummy_time()
  }
  let bookmarks = self.read_bookmarks(preserve_actions=false)
  let values = self.addtext_replacement_values(
    bookmarks,
    page_number,
    self.endpage(),
    filename,
    bates,
    bates_pad,
  )
  { time: resolved_time, replacement_values: values }
}

///|
/// Compatibility wrapper for `PdfDocument::draw_special_text_context`.
pub fn pdf_draw_special_text_context_for_document(
  document : PdfDocument,
  page_number : Int,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  time? : PdfStrftimeTime? = None,
) -> PdfDrawSpecialTextContext raise PdfError {
  document.draw_special_text_context(
    page_number,
    filename~,
    bates~,
    bates_pad~,
    time~,
  )
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
fn PdfDrawRenderState::fresh_mcid(self : PdfDrawRenderState) -> Int {
  self.marked_content_id += 1
  self.marked_content_id
}

///|
fn PdfDrawRenderState::set_minimum_resource_number(
  self : PdfDrawRenderState,
  minimum : Int,
) -> Unit {
  if self.resource_number < minimum {
    self.resource_number = minimum
  }
}

///|
fn PdfDrawRenderState::reset_for_page_chunk(self : PdfDrawRenderState) -> Unit {
  self.extgstates.clear()
  self.marked_content_id = -1
}

///|
fn PdfDrawRenderState::set_structure_tree_enabled(
  self : PdfDrawRenderState,
  enabled : Bool,
) -> Unit {
  self.structure_tree_enabled = enabled
}

///|
fn PdfDrawRenderState::set_structure_page_number(
  self : PdfDrawRenderState,
  page_number : Int,
) -> Unit {
  self.structure_page_number = page_number
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
  let width_cache = pdf_draw_font_width_cache_new(self.font_size)
  let (ops, _) = self.text_ops_and_width_with_cache(text, width_cache)
  ops
}

///|
priv struct PdfDrawFontWidthCache {
  font_size : Double
  entries : Array[(Int, Array[Double])]
}

///|
fn pdf_draw_font_width_cache_new(font_size : Double) -> PdfDrawFontWidthCache {
  { font_size, entries: [] }
}

///|
fn PdfDrawFontWidthCache::widths(
  self : PdfDrawFontWidthCache,
  font_index : Int,
  font : PdfFont,
) -> Array[Double] raise PdfError {
  for entry in self.entries {
    if entry.0 == font_index {
      return entry.1
    }
  }
  let widths = pdf_type_font_widths(font, self.font_size)
  self.entries.push((font_index, widths))
  widths
}

///|
fn PdfDrawRenderState::text_ops_and_width_with_cache(
  self : PdfDrawRenderState,
  text : String,
  width_cache : PdfDrawFontWidthCache,
) -> (Array[PdfContentOp], Double) raise PdfError {
  if self.current_fontpack_identifier == "" {
    raise SoftError("FontPack not selected")
  }
  let triples : Array[(Int, Int, PdfFont)] = []
  let mut width = 0.0
  for codepoint in pdf_codepoints_of_utf8(@utf8.encode(text)) {
    match self.current_fontpack.get_char(codepoint) {
      Some((charcode, font_index, font)) => {
        let widths = width_cache.widths(font_index, font)
        if charcode < 0 || charcode >= widths.length() {
          raise FontWidthExpected
        }
        width += widths[charcode]
        triples.push((charcode, font_index, font))
      }
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
    let bytes = Array::make(run.length(), b'\x00')
    for index, triple in run {
      bytes[index] = pdf_byte_of_int(triple.0)
    }
    output.push(Op_Tf(resource_name, self.font_size))
    output.push(Op_Tj(Bytes::from_array(bytes)))
  }
  (output, width)
}

///|
fn pdf_draw_decode_lossy_view(bytes : BytesView) -> String {
  let output = Array::make(bytes.length(), b'\x00')
  for index, byte in bytes {
    output[index] = byte
  }
  @utf8.decode_lossy(Bytes::from_array(output))
}

///|
fn pdf_draw_split_on_space(text : String) -> Array[String] {
  let bytes = @utf8.encode(text)
  let parts : Array[String] = []
  let mut part_start = 0
  let mut index = 0
  while index < bytes.length() {
    if bytes[index] == b' ' {
      parts.push(pdf_draw_decode_lossy_view(bytes[part_start:index]))
      index += 1
      part_start = index
    } else {
      index += 1
    }
  }
  parts.push(pdf_draw_decode_lossy_view(bytes[part_start:]))
  parts
}

///|
fn pdf_draw_remove_duplicate_tfs(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let mut previous : PdfName? = None
  for op in ops {
    match op {
      Op_Tf(font, _) =>
        match previous {
          Some(seen) if seen == font => ()
          _ => {
            output.push(op)
            previous = Some(font)
          }
        }
      _ => output.push(op)
    }
  }
  output
}

///|
fn pdf_draw_merge_adjacent_tjs(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let mut index = 0
  while index < ops.length() {
    match ops[index] {
      Op_Tj(_) => {
        let run_start = index
        let mut total_length = 0
        while index < ops.length() {
          match ops[index] {
            Op_Tj(text) => {
              total_length += text.length()
              index += 1
            }
            _ => break
          }
        }
        let bytes = Array::make(total_length, b'\x00')
        let mut position = 0
        for op_index in run_start..<index {
          match ops[op_index] {
            Op_Tj(text) =>
              for byte in text {
                bytes[position] = byte
                position += 1
              }
            _ => ()
          }
        }
        output.push(Op_Tj(Bytes::from_array(bytes)))
      }
      _ => {
        output.push(ops[index])
        index += 1
      }
    }
  }
  output
}

///|
fn pdf_draw_clean_up_text_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  pdf_draw_merge_adjacent_tjs(pdf_draw_remove_duplicate_tfs(ops))
}

///|
fn PdfDrawRenderState::justify_paragraph_line(
  self : PdfDrawRenderState,
  ops : ArrayView[PdfContentOp],
  first_line : Bool,
  indent : Double,
  justification : PdfDrawJustification,
  remaining : Double,
) -> Array[PdfContentOp] {
  ignore(self)
  let output : Array[PdfContentOp] = []
  match justification {
    PdfDrawLeft => {
      if first_line {
        output.push(Op_Td(-indent, 0.0))
      }
      output.append(ops)
      if first_line {
        output.push(Op_Td(indent, 0.0))
      }
    }
    PdfDrawRight => {
      output.push(Op_Td(-remaining, 0.0))
      output.append(ops)
      output.push(Op_Td(remaining, 0.0))
    }
    PdfDrawCentre => {
      output.push(Op_Td(-remaining / 2.0, 0.0))
      output.append(ops)
      output.push(Op_Td(remaining / 2.0, 0.0))
    }
  }
  output
}

///|
fn PdfDrawRenderState::format_paragraph(
  self : PdfDrawRenderState,
  indent : Double,
  justification : PdfDrawJustification,
  width : Double,
  text : String,
) -> Array[PdfContentOp] raise PdfError {
  let width_cache = pdf_draw_font_width_cache_new(self.font_size)
  let words : Array[(Array[PdfContentOp], Double)] = []
  for word in pdf_draw_split_on_space(text) {
    words.push(self.text_ops_and_width_with_cache(word, width_cache))
  }
  let (space_ops, space_width) = self.text_ops_and_width_with_cache(
    " ", width_cache,
  )
  let output : Array[PdfContentOp] = []
  let mut line_ops : Array[PdfContentOp] = []
  let mut remaining = width
  let mut first_line = true
  let mut first_loop = true
  let mut index = 0
  while index < words.length() {
    if first_loop {
      remaining -= indent
      first_loop = false
    }
    let (word_ops, word_width) = words[index]
    if remaining == width {
      line_ops.append(word_ops)
      remaining -= word_width
      index += 1
    } else if word_width + space_width <= remaining {
      line_ops.append(space_ops)
      line_ops.append(word_ops)
      remaining -= word_width + space_width
      index += 1
    } else {
      output.push(Op_Tstar)
      output.append(
        self.justify_paragraph_line(
          line_ops, first_line, indent, justification, remaining,
        ),
      )
      first_line = false
      line_ops = []
      remaining = width
    }
  }
  output.push(Op_Tstar)
  output.append(
    self.justify_paragraph_line(
      line_ops, first_line, indent, justification, remaining,
    ),
  )
  pdf_draw_clean_up_text_ops(output)
}

///|
fn PdfDrawRenderState::paragraph_ops(
  self : PdfDrawRenderState,
  indent : Double?,
  justification : PdfDrawJustification,
  width : Double,
  paragraphs : ArrayView[String],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  let mut first = true
  for paragraph in paragraphs {
    if !first {
      match indent {
        None => output.push(Op_Tstar)
        Some(_) => ()
      }
    }
    let paragraph_indent = match indent {
      Some(value) if !first => value
      _ => 0.0
    }
    let paragraph_ops = self.format_paragraph(
      paragraph_indent, justification, width, paragraph,
    )
    if self.structure_tree_enabled && self.auto_tag {
      output.append(self.structure_tagged_ops("/P", paragraph_ops))
    } else {
      output.append(paragraph_ops)
    }
    first = false
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
    marked_content_id: self.marked_content_id,
    extgstates: [],
    xobjects: pdf_draw_copy_xobject_resources(self.xobjects),
    form_xobjects: pdf_draw_copy_xobject_resources(self.form_xobjects),
    fonts: pdf_draw_copy_font_resources(self.fonts),
    fontpacks: pdf_draw_copy_fontpacks(self.fontpacks),
    current_fontpack_identifier: self.current_fontpack_identifier,
    current_fontpack: self.current_fontpack,
    font_size: self.font_size,
    structure_tree_enabled: self.structure_tree_enabled,
    auto_tag: self.auto_tag,
    structure_page_number: self.structure_page_number,
    structure_data: self.structure_data,
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
  if child.marked_content_id > self.marked_content_id {
    self.marked_content_id = child.marked_content_id
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
/// `PdfContentOp`; structure and page-level operations are represented here
/// and will be rendered by later cpdfdraw slices.
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
fn PdfDrawRenderState::tag_ops(
  self : PdfDrawRenderState,
  tag : String,
) -> Array[PdfContentOp] {
  let mcid = self.fresh_mcid()
  if self.structure_tree_enabled {
    self.structure_data.push(
      PdfDrawStructureMCID("/" + tag, self.structure_page_number, mcid),
    )
  }
  [
    Op_BDC(
      pdf_draw_name("/" + tag),
      PdfDictionary([(pdf_draw_mcid_key(), PdfInteger(mcid))]),
    ),
  ]
}

///|
fn PdfDrawRenderState::structure_tagged_ops(
  self : PdfDrawRenderState,
  tag : String,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let mcid = self.fresh_mcid()
  self.structure_data.push(
    PdfDrawStructureMCID(tag, self.structure_page_number, mcid),
  )
  let output : Array[PdfContentOp] = [
    Op_BDC(
      pdf_draw_name(tag),
      PdfDictionary([(pdf_draw_mcid_key(), PdfInteger(mcid))]),
    ),
  ]
  for op in ops {
    output.push(op)
  }
  output.push(Op_EMC)
  output
}

///|
fn PdfDrawSpecialTextContext::process(
  self : PdfDrawSpecialTextContext,
  text : String,
) -> String {
  pdf_addtext_process_text_with_time(
    self.time,
    text,
    pdf_addtext_replacement_pairs(self.replacement_values),
  )
}

///|
fn PdfDrawOp::to_content_ops_internal(
  self : PdfDrawOp,
  state : PdfDrawRenderState?,
  document : PdfDocument?,
  special_text_context : PdfDrawSpecialTextContext?,
) -> Array[PdfContentOp] raise PdfError {
  match self {
    PdfDrawQq(ops) => {
      let output : Array[PdfContentOp] = [Op_q]
      for op in ops {
        for
          content_op in op.to_content_ops_internal(
            state, document, special_text_context,
          ) {
          output.push(content_op)
        }
      }
      output.push(Op_Q)
      output
    }
    PdfDrawTextSection(ops) => {
      let output : Array[PdfContentOp] = [Op_BT]
      for op in ops {
        for
          content_op in op.to_content_ops_internal(
            state, document, special_text_context,
          ) {
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
          let content_ops = pdf_drawops_to_content_ops_internal(
            Some(form_state),
            Some(document),
            special_text_context,
            ops,
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
        Some(state) => {
          let ops = [Op_Do(state.image_resource_name(source_name))]
          if state.structure_tree_enabled && state.auto_tag {
            state.structure_tagged_ops("/Figure", ops)
          } else {
            ops
          }
        }
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
        Some(state) => {
          let ops = state.text_ops(text)
          if state.structure_tree_enabled && state.auto_tag {
            state.structure_tagged_ops("/P", ops)
          } else {
            ops
          }
        }
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawSpecialText(text) =>
      match (state, special_text_context) {
        (Some(state), Some(context)) => {
          let ops = state.text_ops(context.process(text))
          if state.structure_tree_enabled && state.auto_tag {
            state.structure_tagged_ops("/P", ops)
          } else {
            ops
          }
        }
        _ => pdf_draw_content_unsupported(self)
      }
    PdfDrawPara(indent, justification, width, paragraphs) =>
      match state {
        Some(state) =>
          state.paragraph_ops(indent, justification, width, paragraphs)
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
    PdfDrawTag(tag) =>
      match state {
        Some(state) => state.tag_ops(tag)
        None => pdf_draw_content_unsupported(self)
      }
    PdfDrawEndTag => [Op_EMC]
    PdfDrawBeginArtifact => [Op_BMC(pdf_draw_begin_artifact())]
    PdfDrawEndArtifact => [Op_BMC(pdf_draw_end_artifact())]
    PdfDrawSTag(name) => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureBeginTree("/" + name))
        _ => ()
      }
      []
    }
    PdfDrawEndSTag => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureEndTree)
        _ => ()
      }
      []
    }
    PdfDrawNamespace(namespace_uri) => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureNamespace(namespace_uri))
        _ => ()
      }
      []
    }
    PdfDrawEltInfo(key, value) => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureElementInfo(key, value))
        _ => ()
      }
      []
    }
    PdfDrawEndEltInfo(key) => {
      match state {
        Some(state) if state.structure_tree_enabled =>
          state.structure_data.push(PdfDrawStructureEndElementInfo(key))
        _ => ()
      }
      []
    }
    PdfDrawAutoTag(value) => {
      match state {
        Some(state) => state.auto_tag = value
        None => ()
      }
      []
    }
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
/// colour, paint, clip, `q`/`Q` grouping, resource-backed XObjects, fontpack
/// text, and paragraph layout. Later slices will fill in tagged-content and
/// page-level rendering.
pub fn PdfDrawOp::to_content_ops(
  self : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(None, None, None)
}

///|
/// Convert one cpdf draw operation using resource allocation state.
pub fn PdfDrawOp::to_content_ops_with_state(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), None, None)
}

///|
/// Convert one cpdf draw operation using resource state and special-text data.
pub fn PdfDrawOp::to_content_ops_with_context(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), None, Some(context))
}

///|
/// Convert one cpdf draw operation using resource state and a document for
/// indirect object allocation.
pub fn PdfDrawOp::to_content_ops_with_document(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  document : PdfDocument,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), Some(document), None)
}

///|
/// Convert one cpdf draw operation using document resources and special-text data.
pub fn PdfDrawOp::to_content_ops_with_document_context(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
) -> Array[PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), Some(document), Some(context))
}

///|
fn pdf_drawops_to_content_ops_internal(
  state : PdfDrawRenderState?,
  document : PdfDocument?,
  context : PdfDrawSpecialTextContext?,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  for op in ops {
    for content_op in op.to_content_ops_internal(state, document, context) {
      output.push(content_op)
    }
  }
  output
}

///|
/// Convert a sequence of cpdf draw operations to flat PDF content operators.
pub fn pdf_drawops_to_content_ops(
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(None, None, None, ops)
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
  pdf_drawops_to_content_ops_internal(Some(state), None, None, ops)
}

///|
/// Convert a sequence of cpdf draw operations using state and special-text data.
pub fn pdf_drawops_to_content_ops_with_context(
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(Some(state), None, Some(context), ops)
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
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_context`.
pub fn pdf_drawop_to_content_ops_with_context(
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops_with_context(state, context)
}

///|
/// Convert a sequence of cpdf draw operations using resource state and a
/// document for indirect object allocation.
pub fn pdf_drawops_to_content_ops_with_document(
  state : PdfDrawRenderState,
  document : PdfDocument,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(Some(state), Some(document), None, ops)
}

///|
/// Convert a sequence of cpdf draw operations using document resources and
/// special-text data.
pub fn pdf_drawops_to_content_ops_with_document_context(
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(
    Some(state),
    Some(document),
    Some(context),
    ops,
  )
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

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_document_context`.
pub fn pdf_drawop_to_content_ops_with_document_context(
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops_with_document_context(state, document, context)
}

///|
fn pdf_draw_resource_name_number(name : PdfName) -> Int? {
  let bytes = name.bytes()
  let mut start = bytes.length()
  while start > 0 {
    let byte = bytes[start - 1].to_int()
    if byte >= 48 && byte <= 57 {
      start -= 1
    } else {
      break
    }
  }
  if start == bytes.length() {
    None
  } else {
    let mut value = 0
    for index in start..<bytes.length() {
      value = value * 10 + bytes[index].to_int() - 48
    }
    Some(value)
  }
}

///|
fn PdfDocument::pdf_draw_page_resource_numbers(
  self : PdfDocument,
  resources : PdfObject,
) -> Array[Int] {
  let output : Array[Int] = []
  for
    key in [
      pdf_draw_xobject_key(),
      pdf_draw_extgstate_key(),
      pdf_draw_font_key(),
    ] {
    match self.lookup_direct(key, resources) {
      Some(PdfDictionary(entries)) =>
        for entry in entries {
          match pdf_draw_resource_name_number(entry.0) {
            Some(number) => output.push(number)
            None => ()
          }
        }
      _ => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_draw_minimum_resource_number(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Int raise PdfError {
  let pages = self.pages_of_pagetree()
  let mut maximum = -1
  for index in 0..<pages.length() {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
      for number in self.pdf_draw_page_resource_numbers(pages[index].resources) {
        if number > maximum {
          maximum = number
        }
      }
    }
  }
  if maximum < 0 {
    0
  } else {
    maximum + 1
  }
}

///|
fn pdf_draw_contains_special_text(op : PdfDrawOp) -> Bool {
  match op {
    PdfDrawSpecialText(_) => true
    PdfDrawQq(ops)
    | PdfDrawTextSection(ops)
    | PdfDrawFormXObject(_, _, _, _, _, ops) =>
      pdf_drawops_contain_special_text(ops)
    _ => false
  }
}

///|
fn pdf_drawops_contain_special_text(ops : ArrayView[PdfDrawOp]) -> Bool {
  for op in ops {
    if pdf_draw_contains_special_text(op) {
      return true
    }
  }
  false
}

///|
fn pdf_draw_fixup_manual_artifacts(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_BMC(name) if name == pdf_draw_begin_artifact() =>
        output.push(pdf_content_begin_artifact())
      Op_BMC(name) if name == pdf_draw_end_artifact() =>
        output.push(pdf_content_end_artifact())
      _ => output.push(op)
    }
  }
  output
}

///|
fn pdf_draw_artifact_ops(
  ops : ArrayView[PdfContentOp],
  add_artifacts : Bool,
) -> Array[PdfContentOp] {
  if add_artifacts {
    pdf_content_add_artifacts(ops)
  } else {
    pdf_draw_fixup_manual_artifacts(ops)
  }
}

///|
fn pdf_draw_double_trailing_new_page(
  drawops : ArrayView[PdfDrawOp],
) -> Array[PdfDrawOp] {
  let output = [ for op in drawops => op ]
  if output.length() > 0 && output[output.length() - 1] == PdfDrawNewPage {
    output.push(PdfDrawNewPage)
  }
  output
}

///|
fn pdf_draw_split_on_new_page(
  drawops : ArrayView[PdfDrawOp],
) -> Array[Array[PdfDrawOp]] {
  let chunks : Array[Array[PdfDrawOp]] = [[]]
  for op in drawops {
    if op == PdfDrawNewPage {
      chunks.push([])
    } else {
      chunks[chunks.length() - 1].push(op)
    }
  }
  if chunks.length() > 1 && chunks[chunks.length() - 1].length() == 0 {
    ignore(chunks.pop())
  }
  chunks
}

///|
fn PdfDocument::pdf_draw_has_fresh_structure_tree(self : PdfDocument) -> Bool {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_structure_root_key(),
      pdf_draw_struct_tree_root_key(),
    ]) {
    Some(PdfDictionary([(key, PdfNameObject(value))])) =>
      key == pdf_draw_type_key() && value == pdf_draw_struct_tree_root_key()
    _ => false
  }
}

///|
fn pdf_draw_single_page_ops(
  document : PdfDocument,
  state : PdfDrawRenderState,
  drawops : ArrayView[PdfDrawOp],
  page_number : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : PdfStrftimeTime?,
) -> Array[PdfContentOp] raise PdfError {
  let context = document.draw_special_text_context(
    page_number,
    filename~,
    bates~,
    bates_pad~,
    time~,
  )
  pdf_drawops_to_content_ops_with_document_context(
    state, document, context, drawops,
  )
}

///|
fn PdfDocument::pdf_draw_render_page_ops(
  self : PdfDocument,
  state : PdfDrawRenderState,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : PdfStrftimeTime?,
) -> Array[Array[PdfContentOp]] raise PdfError {
  let pages = self.pages_of_pagetree()
  let per_page : Array[Array[PdfContentOp]] = [ for _ in pages => [] ]
  if pdf_drawops_contain_special_text(drawops) {
    for index in 0..<pages.length() {
      let page_number = index + 1
      if pdf_page_box_contains_page(page_numbers, page_number) {
        state.set_structure_page_number(page_number)
        per_page[index] = pdf_draw_single_page_ops(
          self, state, drawops, page_number, filename, bates, bates_pad, time,
        )
      }
    }
  } else {
    let content_ops = pdf_drawops_to_content_ops_with_document(
      state, self, drawops,
    )
    for index in 0..<pages.length() {
      let page_number = index + 1
      if pdf_page_box_contains_page(page_numbers, page_number) {
        per_page[index] = content_ops
      }
    }
  }
  per_page
}

///|
fn PdfDocument::pdf_draw_apply_chunk(
  self : PdfDocument,
  state : PdfDrawRenderState,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree : Bool,
  fast : Bool,
  underneath : Bool,
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : PdfStrftimeTime?,
  add_artifacts : Bool,
) -> PdfDocument raise PdfError {
  state.set_structure_tree_enabled(struct_tree)
  state.set_minimum_resource_number(
    self.pdf_draw_minimum_resource_number(page_numbers),
  )
  let per_page = self.pdf_draw_render_page_ops(
    state, page_numbers, drawops, filename, bates, bates_pad, time,
  )
  let draw_resources = state.resources()
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_page_box_contains_page(page_numbers, page_number) {
      let content_ops = pdf_draw_artifact_ops(
        per_page[index],
        add_artifacts || struct_tree,
      )
      let page = {
        ..page,
        resources: self.combine_pdf_resources(page.resources, draw_resources),
      }
      rewritten.push(
        if underneath {
          self.prepend_operators(page, content_ops, fast~)
        } else {
          self.postpend_operators(page, content_ops, fast~)
        },
      )
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
fn pdf_draw_next_range(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> (PdfDocument, Array[Int]) raise PdfError {
  let end_page = document.endpage()
  match page_numbers {
    [page_number] if end_page > page_number => (document, [page_number + 1])
    _ => (document.pad_after([end_page]), [end_page + 1])
  }
}

///|
let pdf_draw_standard_namespace : String = "http://iso.org/pdf/ssn"

///|
priv enum PdfDrawStructureNode {
  PdfDrawStructureNodeMCID(Int)
  PdfDrawStructureNodeItem(PdfDrawStructureItem)
}

///|
priv struct PdfDrawStructureItem {
  kind : String
  namespace_uri : String
  page_object_number : Int?
  alt : Array[(String, PdfObject)]
  children : Array[PdfDrawStructureNode]
}

///|
priv struct PdfDrawStructureBuildContext {
  mut namespace_uri : String
  element_info : Array[(String, PdfObject)]
}

///|
fn pdf_draw_structure_context_new() -> PdfDrawStructureBuildContext {
  { namespace_uri: pdf_draw_standard_namespace, element_info: [] }
}

///|
fn PdfDrawStructureBuildContext::alt_copy(
  self : PdfDrawStructureBuildContext,
) -> Array[(String, PdfObject)] {
  [
    for entry in self.element_info => entry
  ]
}

///|
fn PdfDrawStructureBuildContext::set_element_info(
  self : PdfDrawStructureBuildContext,
  key : String,
  value : PdfObject,
) -> Unit {
  for index in 0..<self.element_info.length() {
    if self.element_info[index].0 == key {
      self.element_info[index] = (key, value)
      return
    }
  }
  self.element_info.push((key, value))
}

///|
fn PdfDrawStructureBuildContext::remove_element_info(
  self : PdfDrawStructureBuildContext,
  key : String,
) -> Unit {
  let output : Array[(String, PdfObject)] = []
  for entry in self.element_info {
    if entry.0 != key {
      output.push(entry)
    }
  }
  self.element_info.clear()
  for entry in output {
    self.element_info.push(entry)
  }
}

///|
fn pdf_draw_structure_page_object_number(
  page_object_numbers : ArrayView[Int],
  page_number : Int,
) -> Int? {
  if page_number >= 1 && page_number <= page_object_numbers.length() {
    Some(page_object_numbers[page_number - 1])
  } else {
    None
  }
}

///|
fn pdf_draw_make_structure_tree_items(
  data : ArrayView[PdfDrawStructureData],
  index : Ref[Int],
  context : PdfDrawStructureBuildContext,
  page_object_numbers : ArrayView[Int],
  expect_end_tree : Bool,
) -> Array[PdfDrawStructureNode] raise PdfError {
  let output : Array[PdfDrawStructureNode] = []
  while index.val < data.length() {
    match data[index.val] {
      PdfDrawStructureMCID(kind, page_number, mcid) => {
        output.push(
          PdfDrawStructureNodeItem({
            kind,
            namespace_uri: context.namespace_uri,
            page_object_number: pdf_draw_structure_page_object_number(
              page_object_numbers, page_number,
            ),
            alt: context.alt_copy(),
            children: [PdfDrawStructureNodeMCID(mcid)],
          }),
        )
        index.val += 1
      }
      PdfDrawStructureBeginTree(kind) => {
        let namespace_uri = context.namespace_uri
        let alt = context.alt_copy()
        index.val += 1
        let children = pdf_draw_make_structure_tree_items(
          data, index, context, page_object_numbers, true,
        )
        output.push(
          PdfDrawStructureNodeItem({
            kind,
            namespace_uri,
            page_object_number: None,
            alt,
            children,
          }),
        )
      }
      PdfDrawStructureEndTree =>
        if expect_end_tree {
          index.val += 1
          return output
        } else {
          raise SoftError("Too many -end-tags")
        }
      PdfDrawStructureNamespace(namespace_uri) => {
        context.namespace_uri = namespace_uri
        index.val += 1
      }
      PdfDrawStructureElementInfo(key, value) => {
        context.set_element_info(key, value)
        index.val += 1
      }
      PdfDrawStructureEndElementInfo(key) => {
        context.remove_element_info(key)
        index.val += 1
      }
    }
  }
  if expect_end_tree {
    raise SoftError("not enough -end-stag")
  } else {
    output
  }
}

///|
fn PdfDocument::pdf_draw_make_structure_tree(
  self : PdfDocument,
  data : ArrayView[PdfDrawStructureData],
) -> Array[PdfDrawStructureNode] raise PdfError {
  let index : Ref[Int] = { val: 0 }
  pdf_draw_make_structure_tree_items(
    data,
    index,
    pdf_draw_structure_context_new(),
    self.page_reference_numbers(),
    false,
  )
}

///|
priv struct PdfDrawNamespaceMap {
  entries : Array[(String, Int)]
}

///|
fn pdf_draw_namespace_map_new() -> PdfDrawNamespaceMap {
  { entries: [] }
}

///|
fn PdfDrawNamespaceMap::object_number(
  self : PdfDrawNamespaceMap,
  document : PdfDocument,
  namespace_uri : String,
) -> Int? {
  if namespace_uri == pdf_draw_standard_namespace {
    None
  } else {
    for entry in self.entries {
      if entry.0 == namespace_uri {
        return Some(entry.1)
      }
    }
    let number = document.add_object(
      PdfDictionary([
        (pdf_draw_ns_key(), PdfString(@ascii.encode(namespace_uri))),
      ]),
    )
    self.entries.push((namespace_uri, number))
    Some(number)
  }
}

///|
priv struct PdfDrawParentMap {
  entries : Array[(Int, Array[Int])]
}

///|
fn pdf_draw_parent_map_new() -> PdfDrawParentMap {
  { entries: [] }
}

///|
fn PdfDrawParentMap::add(
  self : PdfDrawParentMap,
  page_object_number : Int,
  structure_object_number : Int,
) -> Unit {
  for index in 0..<self.entries.length() {
    if self.entries[index].0 == page_object_number {
      self.entries[index].1.push(structure_object_number)
      return
    }
  }
  self.entries.push((page_object_number, [structure_object_number]))
}

///|
fn PdfDrawParentMap::number_tree_entries(
  self : PdfDrawParentMap,
) -> Array[(Int, PdfObject)] {
  [
    for entry in self.entries => {
      (
        entry.0,
        PdfArray([ for object_number in entry.1 => PdfIndirect(object_number) ]),
      )
    }
  ]
}

///|
fn PdfDocument::pdf_draw_write_structure_node(
  self : PdfDocument,
  parent_object_number : Int,
  namespaces : PdfDrawNamespaceMap,
  parent_map : PdfDrawParentMap,
  node : PdfDrawStructureNode,
) -> PdfObject raise PdfError {
  match node {
    PdfDrawStructureNodeMCID(mcid) => PdfInteger(mcid)
    PdfDrawStructureNodeItem(item) => {
      let object_number = self.add_object(PdfNull)
      match item.page_object_number {
        Some(page_object_number) =>
          parent_map.add(page_object_number, object_number)
        None => ()
      }
      let entries : Array[(PdfName, PdfObject)] = []
      for entry in item.alt {
        entries.push((pdf_draw_name("/" + entry.0), entry.1))
      }
      match item.page_object_number {
        Some(page_object_number) =>
          entries.push((pdf_draw_pg_key(), PdfIndirect(page_object_number)))
        None => ()
      }
      match namespaces.object_number(self, item.namespace_uri) {
        Some(namespace_object_number) =>
          entries.push(
            (pdf_draw_ns_key(), PdfIndirect(namespace_object_number)),
          )
        None => ()
      }
      entries.push((pdf_draw_s_key(), PdfNameObject(pdf_draw_name(item.kind))))
      entries.push((pdf_draw_p_key(), PdfIndirect(parent_object_number)))
      let children : Array[PdfObject] = []
      for child in item.children {
        children.push(
          self.pdf_draw_write_structure_node(
            object_number, namespaces, parent_map, child,
          ),
        )
      }
      entries.push((pdf_draw_k_key(), PdfArray(children)))
      self.add_object_given_number(object_number, PdfDictionary(entries))
      PdfIndirect(object_number)
    }
  }
}

///|
fn PdfDocument::pdf_draw_write_structure_tree(
  self : PdfDocument,
  data : ArrayView[PdfDrawStructureData],
  role_map : String,
) -> Unit raise PdfError {
  let tree = self.pdf_draw_make_structure_tree(data)
  let namespaces = pdf_draw_namespace_map_new()
  let parent_map = pdf_draw_parent_map_new()
  let root_object_number = self.add_object(PdfNull)
  let children : Array[PdfObject] = []
  for node in tree {
    children.push(
      self.pdf_draw_write_structure_node(
        root_object_number, namespaces, parent_map, node,
      ),
    )
  }
  for entry in parent_map.entries {
    let page_object = self.lookup_object_or_null(entry.0)
    self.add_object_given_number(
      entry.0,
      page_object.add_dict_entry(
        pdf_draw_struct_parents_key(),
        PdfInteger(entry.0),
      ),
    )
  }
  let parent_tree_number = self.add_object(
    self.build_number_tree(parent_map.number_tree_entries()),
  )
  let root_entries : Array[(PdfName, PdfObject)] = [
    (pdf_draw_type_key(), PdfNameObject(pdf_draw_struct_tree_root_key())),
    (pdf_draw_parent_tree_key(), PdfIndirect(parent_tree_number)),
    (pdf_draw_k_key(), PdfArray(children)),
  ]
  if role_map != "" {
    root_entries.push(
      (
        pdf_draw_role_map_key(),
        pdf_parse_object_from_bytes(@ascii.encode("<<" + role_map + ">>")),
      ),
    )
  }
  if namespaces.entries.length() > 0 {
    root_entries.push(
      (
        pdf_draw_namespaces_key(),
        PdfArray([ for entry in namespaces.entries => PdfIndirect(entry.1) ]),
      ),
    )
  }
  self.add_object_given_number(root_object_number, PdfDictionary(root_entries))
  self.replace_chain(
    [pdf_structure_root_key(), pdf_draw_struct_tree_root_key()],
    PdfIndirect(root_object_number),
  )
}

///|
/// Draw cpdf draw operations on selected pages.
///
/// This ports the page orchestration from `cpdfdraw.ml`: draw operations are
/// split around `PdfDrawNewPage`, selected page ranges are advanced or padded
/// between chunks, resources are merged into page resources, manual artifact
/// back-channel markers are fixed before writing content, and `struct_tree`
/// writes a fresh structure tree from rendered MCIDs only when the document has
/// cpdf's fresh `/StructTreeRoot` placeholder. If a real structure tree is
/// already present, or no fresh placeholder exists, requested structure mode
/// artifacts the drawn content instead of replacing the tree. When `role_map`
/// is not empty, it is parsed as the body of a PDF role-map dictionary and
/// attached to the generated `/StructTreeRoot`.
pub fn PdfDocument::draw(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree? : Bool = false,
  fast? : Bool = false,
  underneath? : Bool = false,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  time? : PdfStrftimeTime? = None,
  add_artifacts? : Bool = false,
  role_map? : String = "",
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(page_numbers, self.endpage(), "draw")
  let write_structure_tree = struct_tree &&
    self.pdf_draw_has_fresh_structure_tree()
  let effective_add_artifacts = add_artifacts ||
    (struct_tree && !write_structure_tree)
  let state = pdf_draw_render_state_new()
  state.set_structure_tree_enabled(write_structure_tree)
  let chunks = pdf_draw_split_on_new_page(
    pdf_draw_double_trailing_new_page(drawops),
  )
  let mut document = self
  let mut current_pages = [ for page_number in page_numbers => page_number ]
  for index in 0..<chunks.length() {
    state.reset_for_page_chunk()
    if chunks[index].length() > 0 {
      if current_pages.length() > 0 {
        state.set_structure_page_number(current_pages[0])
      } else {
        state.set_structure_page_number(0)
      }
      document = document.pdf_draw_apply_chunk(
        state,
        current_pages,
        chunks[index],
        write_structure_tree,
        fast,
        underneath,
        filename,
        bates,
        bates_pad,
        time,
        effective_add_artifacts,
      )
    }
    if index + 1 < chunks.length() {
      let next = pdf_draw_next_range(document, current_pages)
      document = next.0
      current_pages = next.1
    }
  }
  if write_structure_tree {
    document.pdf_draw_write_structure_tree(state.structure_data, role_map)
  }
  document
}

///|
/// Compatibility wrapper for `PdfDocument::draw`.
pub fn pdf_draw(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree? : Bool = false,
  fast? : Bool = false,
  underneath? : Bool = false,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  time? : PdfStrftimeTime? = None,
  add_artifacts? : Bool = false,
  role_map? : String = "",
) -> PdfDocument raise PdfError {
  document.draw(
    page_numbers,
    drawops,
    struct_tree~,
    fast~,
    underneath~,
    filename~,
    bates~,
    bates_pad~,
    time~,
    add_artifacts~,
    role_map~,
  )
}
