///|
/// Paragraph justification used by cpdf draw operations.
pub(all) enum PdfDrawJustification {
  PdfDrawLeft
  PdfDrawRight
  PdfDrawCentre
} derive(Debug, Eq, ToJson)

///|
/// External graphics-state resource allocated while rendering draw operations.
pub(all) struct PdfDrawExtGStateResource {
  kind : PdfName
  value : Double
  name : PdfName
} derive(Debug, Eq, ToJson)

///|
/// XObject resource tracked while rendering draw operations.
pub(all) struct PdfDrawXObjectResource {
  source_name : String
  resource_name : PdfName
  object_number : Int
} derive(Debug, Eq, ToJson)

///|
/// Font resource tracked while rendering draw operations.
pub(all) struct PdfDrawFontResource {
  identifier : String
  font_index : Int
  resource_name : PdfName
  object_number : Int
} derive(Debug, Eq, ToJson)

///|
/// Current font-pack binding used by draw rendering state.
pub(all) struct PdfDrawFontPackState {
  identifier : String
  fontpack : PdfFontPack
} derive(Debug, Eq, ToJson)

///|
/// Tagged-PDF structure-tree event emitted while rendering draw operations.
pub(all) enum PdfDrawStructureData {
  PdfDrawStructureMCID(String, Int, Int)
  PdfDrawStructureBeginTree(String)
  PdfDrawStructureEndTree
  PdfDrawStructureNamespace(String)
  PdfDrawStructureElementInfo(String, @syntax.PdfObject)
  PdfDrawStructureEndElementInfo(String)
} derive(Debug, Eq, ToJson)

///|
/// Page-local context used to render `PdfDrawSpecialText`.
pub(all) struct PdfDrawSpecialTextContext {
  time : @date.PdfStrftimeTime
  replacement_values : @addtext.PdfAddTextReplacementValues
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
/// Build a fresh draw render state with default resource caches.
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
  time : @date.PdfStrftimeTime,
  replacement_values : @addtext.PdfAddTextReplacementValues,
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
  time? : @date.PdfStrftimeTime? = None,
) -> PdfDrawSpecialTextContext raise PdfError {
  let resolved_time = match time {
    Some(value) => value
    None => @date.pdf_strftime_dummy_time()
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
  time? : @date.PdfStrftimeTime? = None,
) -> PdfDrawSpecialTextContext raise PdfError {
  document.draw_special_text_context(
    page_number,
    filename~,
    bates~,
    bates_pad~,
    time~,
  )
}
