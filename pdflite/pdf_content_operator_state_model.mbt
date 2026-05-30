///|
/// Saved graphics/text interpreter frame pushed by PDF `q`/`Q` graphics-state
/// operators while walking a content stream.
pub(all) struct PdfContentOperatorFrame {
  ctm : @geometry.TransformMatrix
  partial_path : @path.PdfContentPartialPath
  clipping_path : Array[@shape.PdfPath]
  path : @shape.PdfDrawnPath
  path_state : PdfContentPathState
  text_state : PdfContentTextState
  miter_limit : Double
  flatness : Double
  alpha_constant_stroke : Double
  alpha_constant_non_stroke : Double
  alpha_source : Bool
  smoothness : Double
  stroke_adjustment : Bool
  overprint_stroke : Bool
  overprint_non_stroke : Bool
  overprint_mode : Int
  black_generation : PdfObject
  undercolour_removal : PdfObject
  transfer : PdfObject
  halftone : PdfObject
  blend_mode : PdfObject
  soft_mask : PdfObject
  black_point_compensation : String
  marked_content_point : PdfContentMarkedContent?
  marked_content : Array[PdfContentMarkedContent]
  type3_d0 : PdfContentType3D0?
  type3_d1 : PdfContentType3D1?
} derive(Debug, Eq, ToJson)

///|
/// Mutable interpreter state for cpdfcontent-style content stream analysis.
/// It tracks graphics state, text state, marked-content context, Type 3 font
/// metrics, and the saved graphics-state stack.
pub(all) struct PdfContentOperatorState {
  ctm : @geometry.TransformMatrix
  partial_path : @path.PdfContentPartialPath
  clipping_path : Array[@shape.PdfPath]
  path : @shape.PdfDrawnPath
  path_state : PdfContentPathState
  text_state : PdfContentTextState
  miter_limit : Double
  flatness : Double
  alpha_constant_stroke : Double
  alpha_constant_non_stroke : Double
  alpha_source : Bool
  smoothness : Double
  stroke_adjustment : Bool
  overprint_stroke : Bool
  overprint_non_stroke : Bool
  overprint_mode : Int
  black_generation : PdfObject
  undercolour_removal : PdfObject
  transfer : PdfObject
  halftone : PdfObject
  blend_mode : PdfObject
  soft_mask : PdfObject
  black_point_compensation : String
  marked_content_point : PdfContentMarkedContent?
  marked_content : Array[PdfContentMarkedContent]
  type3_d0 : PdfContentType3D0?
  type3_d1 : PdfContentType3D1?
  state_stack : Array[PdfContentOperatorFrame]
} derive(Debug, Eq, ToJson)

///|
/// Result of applying a text-related content operator.
pub(all) struct PdfContentOperatorTextResult {
  state : PdfContentOperatorState
  entries : Array[PdfContentJsonEntry]
} derive(Debug, Eq, ToJson)

///|
/// Result of applying an operator that can emit resource or graphics-state
/// JSON entries while updating interpreter state.
pub(all) struct PdfContentOperatorResourceResult {
  state : PdfContentOperatorState
  entries : Array[PdfContentJsonEntry]
} derive(Debug, Eq, ToJson)

///|
/// Active marked-content scope captured from `BMC`, `BDC`, `MP`, and `DP`
/// operators.
pub(all) struct PdfContentMarkedContent {
  tag : String
  properties : PdfObject?
} derive(Debug, Eq, ToJson)

///|
fn pdf_content_extgstate_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_content_extgstate_lw_name : PdfName = pdf_content_extgstate_name("/LW")

///|
let pdf_content_extgstate_lc_name : PdfName = pdf_content_extgstate_name("/LC")

///|
let pdf_content_extgstate_lj_name : PdfName = pdf_content_extgstate_name("/LJ")

///|
let pdf_content_extgstate_ml_name : PdfName = pdf_content_extgstate_name("/ML")

///|
let pdf_content_extgstate_d_name : PdfName = pdf_content_extgstate_name("/D")

///|
let pdf_content_extgstate_ri_name : PdfName = pdf_content_extgstate_name("/RI")

///|
let pdf_content_extgstate_resource_name : PdfName = pdf_content_extgstate_name(
  "/ExtGState",
)

///|
let pdf_content_extgstate_font_name : PdfName = pdf_content_extgstate_name(
  "/Font",
)

///|
let pdf_content_extgstate_op_stroke_name : PdfName = pdf_content_extgstate_name(
  "/OP",
)

///|
let pdf_content_extgstate_op_non_stroke_name : PdfName = pdf_content_extgstate_name(
  "/op",
)

///|
let pdf_content_extgstate_bg_name : PdfName = pdf_content_extgstate_name("/BG")

///|
let pdf_content_extgstate_bg2_name : PdfName = pdf_content_extgstate_name(
  "/BG2",
)

///|
let pdf_content_extgstate_ucr_name : PdfName = pdf_content_extgstate_name(
  "/UCR",
)

///|
let pdf_content_extgstate_ucr2_name : PdfName = pdf_content_extgstate_name(
  "/UCR2",
)

///|
let pdf_content_extgstate_tr_name : PdfName = pdf_content_extgstate_name("/TR")

///|
let pdf_content_extgstate_tr2_name : PdfName = pdf_content_extgstate_name(
  "/TR2",
)

///|
let pdf_content_extgstate_ht_name : PdfName = pdf_content_extgstate_name("/HT")

///|
let pdf_content_extgstate_smask_name : PdfName = pdf_content_extgstate_name(
  "/SMask",
)

///|
let pdf_content_extgstate_hto_name : PdfName = pdf_content_extgstate_name(
  "/HTO",
)

///|
let pdf_content_extgstate_bm_name : PdfName = pdf_content_extgstate_name("/BM")

///|
let pdf_content_extgstate_use_black_pt_comp_name : PdfName = pdf_content_extgstate_name(
  "/UseBlackPtComp",
)

///|
let pdf_content_extgstate_normal_name : PdfName = pdf_content_extgstate_name(
  "/Normal",
)

///|
let pdf_content_extgstate_fl_name : PdfName = pdf_content_extgstate_name("/FL")

///|
let pdf_content_extgstate_sm_name : PdfName = pdf_content_extgstate_name("/SM")

///|
let pdf_content_extgstate_sa_name : PdfName = pdf_content_extgstate_name("/SA")

///|
let pdf_content_extgstate_ca_stroke_name : PdfName = pdf_content_extgstate_name(
  "/CA",
)

///|
let pdf_content_extgstate_ca_non_stroke_name : PdfName = pdf_content_extgstate_name(
  "/ca",
)

///|
let pdf_content_extgstate_ais_name : PdfName = pdf_content_extgstate_name(
  "/AIS",
)

///|
let pdf_content_extgstate_tk_name : PdfName = pdf_content_extgstate_name("/TK")

///|
fn pdf_content_extgstate_tk_key() -> PdfName {
  pdf_content_extgstate_tk_name
}

///|
/// Type 3 font `d0` width declaration captured from a character procedure.
pub(all) struct PdfContentType3D0 {
  width_x : Double
  width_y : Double
} derive(Debug, Eq, ToJson)

///|
/// Type 3 font `d1` width and bounding-box declaration captured from a
/// character procedure.
pub(all) struct PdfContentType3D1 {
  width_x : Double
  width_y : Double
  llx : Double
  lly : Double
  urx : Double
  ury : Double
} derive(Debug, Eq, ToJson)

///|
/// Return cpdfcontent's initial operator state for a page boundary.
pub fn pdf_content_initial_operator_state(
  minx : Double,
  miny : Double,
  maxx : Double,
  maxy : Double,
) -> PdfContentOperatorState {
  let clipping_path = pdf_content_initial_clipping_path(minx, miny, maxx, maxy)
  {
    ctm: @geometry.transform_identity_matrix,
    partial_path: @path.pdf_content_no_partial_path(),
    clipping_path,
    path: pdf_content_initial_drawn_path(),
    path_state: pdf_content_initial_path_state(minx, miny, maxx, maxy),
    text_state: pdf_content_initial_text_state(),
    miter_limit: 10.0,
    flatness: 1.0,
    alpha_constant_stroke: 1.0,
    alpha_constant_non_stroke: 1.0,
    alpha_source: false,
    smoothness: 0.5,
    stroke_adjustment: false,
    overprint_stroke: false,
    overprint_non_stroke: false,
    overprint_mode: 0,
    black_generation: PdfNull,
    undercolour_removal: PdfNull,
    transfer: PdfNull,
    halftone: PdfNull,
    blend_mode: PdfNameObject(pdf_content_extgstate_normal_name),
    soft_mask: PdfNull,
    black_point_compensation: "/Default",
    marked_content_point: None,
    marked_content: [],
    type3_d0: None,
    type3_d1: None,
    state_stack: [],
  }
}
