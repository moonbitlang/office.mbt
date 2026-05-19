///|
priv enum PdfUAMatterhornContext {
  PdfUAMatterhornArtifact
  PdfUAMatterhornContent
  PdfUAMatterhornOther
}

///|
priv struct PdfUAMatterhornTest {
  name : String
  error : String
  section : String
}

///|
priv struct PdfUAMatterhornFailure {
  name : String
  error : String
  section : String
  extra : Json
}

///|
let pdf_ua_matterhorn_artifact_name : PdfName = pdf_ua_name("/Artifact")

///|
fn pdf_ua_matterhorn_artifact() -> PdfName {
  pdf_ua_matterhorn_artifact_name
}

///|
let pdf_ua_matterhorn_span_name : PdfName = pdf_ua_name("/Span")

///|
fn pdf_ua_matterhorn_span() -> PdfName {
  pdf_ua_matterhorn_span_name
}

///|
let pdf_ua_matterhorn_form_name : PdfName = pdf_ua_name("/Form")

///|
fn pdf_ua_matterhorn_form() -> PdfName {
  pdf_ua_matterhorn_form_name
}

///|
let pdf_ua_matterhorn_type0_name : PdfName = pdf_ua_name("/Type0")

///|
fn pdf_ua_matterhorn_type0() -> PdfName {
  pdf_ua_matterhorn_type0_name
}

///|
let pdf_ua_matterhorn_identity_h_name : PdfName = pdf_ua_name("/Identity-H")

///|
fn pdf_ua_matterhorn_identity_h() -> PdfName {
  pdf_ua_matterhorn_identity_h_name
}

///|
let pdf_ua_matterhorn_identity_v_name : PdfName = pdf_ua_name("/Identity-V")

///|
fn pdf_ua_matterhorn_identity_v() -> PdfName {
  pdf_ua_matterhorn_identity_v_name
}

///|
let pdf_ua_matterhorn_resources_key_name : PdfName = pdf_ua_name("/Resources")

///|
fn pdf_ua_matterhorn_resources_key() -> PdfName {
  pdf_ua_matterhorn_resources_key_name
}

///|
let pdf_ua_matterhorn_xobject_key_name : PdfName = pdf_ua_name("/XObject")

///|
fn pdf_ua_matterhorn_xobject_key() -> PdfName {
  pdf_ua_matterhorn_xobject_key_name
}

///|
let pdf_ua_matterhorn_ap_key_name : PdfName = pdf_ua_name("/AP")

///|
fn pdf_ua_matterhorn_ap_key() -> PdfName {
  pdf_ua_matterhorn_ap_key_name
}

///|
let pdf_ua_matterhorn_n_key_name : PdfName = pdf_ua_name("/N")

///|
fn pdf_ua_matterhorn_n_key() -> PdfName {
  pdf_ua_matterhorn_n_key_name
}

///|
let pdf_ua_matterhorn_mcid_key_name : PdfName = pdf_ua_name("/MCID")

///|
fn pdf_ua_matterhorn_mcid_key() -> PdfName {
  pdf_ua_matterhorn_mcid_key_name
}

///|
let pdf_ua_matterhorn_suspects_key_name : PdfName = pdf_ua_name("/Suspects")

///|
fn pdf_ua_matterhorn_suspects_key() -> PdfName {
  pdf_ua_matterhorn_suspects_key_name
}

///|
let pdf_ua_matterhorn_ref_key_name : PdfName = pdf_ua_name("/Ref")

///|
fn pdf_ua_matterhorn_ref_key() -> PdfName {
  pdf_ua_matterhorn_ref_key_name
}

///|
let pdf_ua_matterhorn_ct_key_name : PdfName = pdf_ua_name("/CT")

///|
fn pdf_ua_matterhorn_ct_key() -> PdfName {
  pdf_ua_matterhorn_ct_key_name
}

///|
let pdf_ua_matterhorn_encoding_key_name : PdfName = pdf_ua_name("/Encoding")

///|
fn pdf_ua_matterhorn_encoding_key() -> PdfName {
  pdf_ua_matterhorn_encoding_key_name
}

///|
let pdf_ua_matterhorn_descendant_fonts_key_name : PdfName = pdf_ua_name(
  "/DescendantFonts",
)

///|
fn pdf_ua_matterhorn_descendant_fonts_key() -> PdfName {
  pdf_ua_matterhorn_descendant_fonts_key_name
}

///|
let pdf_ua_matterhorn_cid_system_info_key_name : PdfName = pdf_ua_name(
  "/CIDSystemInfo",
)

///|
fn pdf_ua_matterhorn_cid_system_info_key() -> PdfName {
  pdf_ua_matterhorn_cid_system_info_key_name
}

///|
let pdf_ua_matterhorn_registry_key_name : PdfName = pdf_ua_name("/Registry")

///|
fn pdf_ua_matterhorn_registry_key() -> PdfName {
  pdf_ua_matterhorn_registry_key_name
}

///|
let pdf_ua_matterhorn_ordering_key_name : PdfName = pdf_ua_name("/Ordering")

///|
fn pdf_ua_matterhorn_ordering_key() -> PdfName {
  pdf_ua_matterhorn_ordering_key_name
}

///|
let pdf_ua_matterhorn_struct_parent_key_name : PdfName = pdf_ua_name(
  "/StructParent",
)

///|
fn pdf_ua_matterhorn_struct_parent_key() -> PdfName {
  pdf_ua_matterhorn_struct_parent_key_name
}

///|
let pdf_ua_matterhorn_media_clip_name : PdfName = pdf_ua_name("/MediaClip")

///|
fn pdf_ua_matterhorn_media_clip() -> PdfName {
  pdf_ua_matterhorn_media_clip_name
}

///|
let pdf_ua_matterhorn_mcd_name : PdfName = pdf_ua_name("/MCD")

///|
fn pdf_ua_matterhorn_mcd() -> PdfName {
  pdf_ua_matterhorn_mcd_name
}

///|
let pdf_ua_matterhorn_printer_mark_name : PdfName = pdf_ua_name("/PrinterMark")

///|
fn pdf_ua_matterhorn_printer_mark() -> PdfName {
  pdf_ua_matterhorn_printer_mark_name
}

///|
fn pdf_ua_matterhorn_test_01_003() -> PdfUAMatterhornTest {
  {
    name: "01-003",
    error: "Content marked as Artifact is present inside tagged content.",
    section: "UA1:7.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_01_004() -> PdfUAMatterhornTest {
  {
    name: "01-004",
    error: "Tagged content is present inside content marked as Artifact.",
    section: "UA1:7.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_01_005() -> PdfUAMatterhornTest {
  {
    name: "01-005",
    error: "Content is neither marked as Artifact nor tagged as real content.",
    section: "UA1:7-1-2",
  }
}

///|
fn pdf_ua_matterhorn_test_01_007() -> PdfUAMatterhornTest {
  {
    name: "01-007",
    error: "Suspects entry has a value of true.",
    section: "UA1:7-1-11",
  }
}

///|
fn pdf_ua_matterhorn_test_02_001() -> PdfUAMatterhornTest {
  {
    name: "02-001",
    error: "One or more non-standard tag’s mapping does not terminate with a standard type.",
    section: "UA1:7.1-3",
  }
}

///|
fn pdf_ua_matterhorn_test_02_003() -> PdfUAMatterhornTest {
  { name: "02-003", error: "A circular mapping exists.", section: "UA1:7.1-3" }
}

///|
fn pdf_ua_matterhorn_test_02_004() -> PdfUAMatterhornTest {
  {
    name: "02-004",
    error: "One or more standard types are remapped.",
    section: "UA1:7.1-4",
  }
}

///|
fn pdf_ua_matterhorn_test_06_001() -> PdfUAMatterhornTest {
  {
    name: "06-001",
    error: "Document does not contain an XMP metadata stream",
    section: "UA1:7.1-8",
  }
}

///|
fn pdf_ua_matterhorn_test_06_002() -> PdfUAMatterhornTest {
  {
    name: "06-002",
    error: "The XMP metadata stream in the Catalog dictionary does not include the PDF/UA identifier.",
    section: "UA1:5",
  }
}

///|
fn pdf_ua_matterhorn_test_06_003() -> PdfUAMatterhornTest {
  {
    name: "06-003",
    error: "XMP metadata stream does not contain dc:title",
    section: "UA1:7.1-8",
  }
}

///|
fn pdf_ua_matterhorn_test_07_001() -> PdfUAMatterhornTest {
  {
    name: "07-001",
    error: "ViewerPreferences dictionary of the Catalog dictionary does not contain a DisplayDocTitle entry",
    section: "UA1:7.1-9",
  }
}

///|
fn pdf_ua_matterhorn_test_07_002() -> PdfUAMatterhornTest {
  {
    name: "07-002",
    error: "ViewerPreferences dictionary of the Catalog dictionary contains a DisplayDocTitle entry with a value of false",
    section: "UA1:7.1-9",
  }
}

///|
fn pdf_ua_matterhorn_test_20_001() -> PdfUAMatterhornTest {
  {
    name: "20-001",
    error: "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary in the Configs entry in the OCProperties entry in the Catalog dictionary.",
    section: "UA1:7.10-1",
  }
}

///|
fn pdf_ua_matterhorn_test_20_002() -> PdfUAMatterhornTest {
  {
    name: "20-002",
    error: "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary that is the value of the D entry in the OCProperties entry in the Catalog dictionary.",
    section: "UA1:7.10-1",
  }
}

///|
fn pdf_ua_matterhorn_test_20_003() -> PdfUAMatterhornTest {
  {
    name: "20-003",
    error: "An AS entry appears in an Optional Content Configuration Dictionary.",
    section: "UA1:7.10-2",
  }
}

///|
fn pdf_ua_matterhorn_test_28_014() -> PdfUAMatterhornTest {
  {
    name: "28-014",
    error: "CT entry is missing from the media clip data dictionary.",
    section: "",
  }
}

///|
fn pdf_ua_matterhorn_test_28_015() -> PdfUAMatterhornTest {
  {
    name: "28-015",
    error: "Alt entry is missing from the media clip data dictionary.",
    section: "UA1:7.18.6.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_016() -> PdfUAMatterhornTest {
  {
    name: "28-016",
    error: "File attachment annotations do not conform to 7.11.",
    section: "UA1:7.18.7-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_017() -> PdfUAMatterhornTest {
  {
    name: "28-017",
    error: "A PrinterMark annotation is included in the logical structure.",
    section: "UA1:7.18.8-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_018() -> PdfUAMatterhornTest {
  {
    name: "28-018",
    error: "The appearance stream of a PrinterMark annotation is not marked as Artifact.",
    section: "UA1:7.18.8-2",
  }
}

///|
fn pdf_ua_matterhorn_test_30_001() -> PdfUAMatterhornTest {
  {
    name: "30-001",
    error: "A reference XObject is present.",
    section: "UA1:7.2",
  }
}

///|
fn pdf_ua_matterhorn_test_30_002() -> PdfUAMatterhornTest {
  {
    name: "30-002",
    error: "Form XObject contains MCIDs and is referenced more than once.",
    section: "UA1:7.21.3.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_001() -> PdfUAMatterhornTest {
  {
    name: "31-001",
    error: "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has values for Registry in both CIDSystemInfo dictionaries that are not identical.",
    section: "UA1:7.21.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_002() -> PdfUAMatterhornTest {
  {
    name: "31-002",
    error: "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has values for Ordering in both CIDSystemInfo dictionaries that are not identical.",
    section: "UA1:7.21.3.1-1",
  }
}

///|
fn pdf_ua_matterhorn_implemented_tests() -> Array[PdfUAMatterhornTest] {
  [
    pdf_ua_matterhorn_test_01_003(),
    pdf_ua_matterhorn_test_01_004(),
    pdf_ua_matterhorn_test_01_005(),
    pdf_ua_matterhorn_test_01_007(),
    pdf_ua_matterhorn_test_02_001(),
    pdf_ua_matterhorn_test_02_003(),
    pdf_ua_matterhorn_test_02_004(),
    pdf_ua_matterhorn_test_06_001(),
    pdf_ua_matterhorn_test_06_002(),
    pdf_ua_matterhorn_test_06_003(),
    pdf_ua_matterhorn_test_07_001(),
    pdf_ua_matterhorn_test_07_002(),
    pdf_ua_matterhorn_test_20_001(),
    pdf_ua_matterhorn_test_20_002(),
    pdf_ua_matterhorn_test_20_003(),
    pdf_ua_matterhorn_test_28_014(),
    pdf_ua_matterhorn_test_28_015(),
    pdf_ua_matterhorn_test_28_016(),
    pdf_ua_matterhorn_test_28_017(),
    pdf_ua_matterhorn_test_28_018(),
    pdf_ua_matterhorn_test_30_001(),
    pdf_ua_matterhorn_test_30_002(),
    pdf_ua_matterhorn_test_31_001(),
    pdf_ua_matterhorn_test_31_002(),
  ]
}

///|
fn pdf_ua_matterhorn_failure(
  check : PdfUAMatterhornTest,
  extra? : Json = Json::null(),
) -> PdfUAMatterhornFailure {
  { name: check.name, error: check.error, section: check.section, extra }
}

///|
fn PdfUAMatterhornFailure::to_json(self : PdfUAMatterhornFailure) -> Json {
  Json::object(
    Map::of([
      ("name", Json::string(self.name)),
      ("section", Json::string(self.section)),
      ("error", Json::string(self.error)),
      ("extra", self.extra),
    ]),
  )
}

///|
fn pdf_ua_matterhorn_is_form_stream(
  document : PdfDocument,
  object : PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_ua_matterhorn_form()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_stream_resources(
  self : PdfDocument,
  stream : PdfObject,
) -> PdfObject {
  match self.lookup_direct(pdf_ua_matterhorn_resources_key(), stream) {
    Some(resources) => resources
    None => PdfDictionary([])
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_all_ops(
  self : PdfDocument,
  xobjects? : Bool = true,
) -> Array[Array[PdfContentOp]] raise PdfError {
  let output : Array[Array[PdfContentOp]] = []
  if xobjects {
    for entry in self.stream_object_entries() {
      let stream = PdfStreamObject(entry.2)
      if pdf_ua_matterhorn_is_form_stream(self, stream) {
        let resources = self.pdf_ua_matterhorn_stream_resources(stream)
        output.push(self.parse_content_ops_with_resources(resources, [stream]))
      }
    }
  }
  for page in self.pages_of_pagetree() {
    output.push(
      self.parse_content_ops_with_resources(page.resources, page.content),
    )
  }
  output
}

///|
fn pdf_ua_matterhorn_artifact_in_content_ops(
  ops : ArrayView[PdfContentOp],
) -> Bool {
  let mut in_content = false
  let mut in_artifact = false
  for op in ops {
    match op {
      Op_BDC(_, _) => in_content = true
      Op_BMC(name) if name == pdf_ua_matterhorn_artifact() =>
        if in_content {
          return true
        } else {
          in_artifact = true
        }
      Op_EMC =>
        if in_content && in_artifact {
          return true
        } else if in_content {
          in_content = false
        } else {
          in_artifact = false
        }
      _ => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_content_in_artifact_ops(
  ops : ArrayView[PdfContentOp],
) -> Bool {
  let mut in_content = false
  let mut in_artifact = false
  for op in ops {
    match op {
      Op_BDC(_, _) => if in_artifact { return true } else { in_content = true }
      Op_BMC(name) if name == pdf_ua_matterhorn_artifact() => in_artifact = true
      Op_EMC =>
        if in_content && in_artifact {
          return true
        } else if in_content {
          in_content = false
        } else {
          in_artifact = false
        }
      _ => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_real_op(op : PdfContentOp) -> Bool {
  match op {
    Op_m(_, _)
    | Op_l(_, _)
    | Op_c(_, _, _, _, _, _)
    | Op_v(_, _, _, _)
    | Op_y(_, _, _, _)
    | Op_h
    | Op_re(_, _, _, _)
    | Op_S
    | Op_s
    | Op_f
    | Op_F
    | Op_fstar
    | Op_B
    | Op_Bstar
    | Op_b
    | Op_bstar
    | Op_W
    | Op_Wstar
    | Op_Tj(_)
    | Op_TJ(_)
    | Op_quote(_)
    | Op_double_quote(_, _, _)
    | Op_sh(_)
    | Op_InlineImage(_, _, _)
    | Op_Do(_) => true
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_path_construction_op(op : PdfContentOp) -> Bool {
  match op {
    Op_m(_, _)
    | Op_l(_, _)
    | Op_c(_, _, _, _, _, _)
    | Op_v(_, _, _, _)
    | Op_y(_, _, _, _)
    | Op_h
    | Op_re(_, _, _, _) => true
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_bdc_context(
  tag : PdfName,
  properties : PdfObject,
) -> PdfUAMatterhornContext {
  match properties {
    PdfDictionary(_) if properties.lookup_immediate(
        pdf_ua_matterhorn_mcid_key(),
      )
      is Some(_) => PdfUAMatterhornContent
    _ =>
      if tag == pdf_ua_matterhorn_artifact() {
        PdfUAMatterhornArtifact
      } else {
        PdfUAMatterhornOther
      }
  }
}

///|
fn pdf_ua_matterhorn_bmc_context(tag : PdfName) -> PdfUAMatterhornContext {
  if tag == pdf_ua_matterhorn_span() || tag == pdf_ua_matterhorn_artifact() {
    PdfUAMatterhornArtifact
  } else {
    PdfUAMatterhornOther
  }
}

///|
fn pdf_ua_matterhorn_stack_has_marking(
  stack : ArrayView[PdfUAMatterhornContext],
) -> Bool {
  for context in stack {
    match context {
      PdfUAMatterhornArtifact | PdfUAMatterhornContent => return true
      PdfUAMatterhornOther => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_naked_ops(
  ops : ArrayView[PdfContentOp],
) -> (Array[PdfContentOp], Json?) {
  let naked : Array[PdfContentOp] = []
  let stack : Array[PdfUAMatterhornContext] = []
  for op in ops {
    match op {
      Op_BDC(tag, properties) =>
        stack.push(pdf_ua_matterhorn_bdc_context(tag, properties))
      Op_BMC(tag) => stack.push(pdf_ua_matterhorn_bmc_context(tag))
      Op_EMC =>
        if stack.length() == 0 {
          return ([], Some(Json::string("empty stack")))
        } else {
          ignore(stack.pop())
        }
      _ =>
        if !pdf_ua_matterhorn_stack_has_marking(stack) &&
          pdf_ua_matterhorn_real_op(op) {
          naked.push(op)
        }
    }
  }
  (naked, None)
}

///|
fn pdf_ua_matterhorn_unfiltered_real_op(
  naked : ArrayView[PdfContentOp],
) -> Bool {
  let reversed = naked.rev()
  let mut index = 0
  while index < reversed.length() {
    match reversed[index] {
      Op_W | Op_Wstar => {
        index += 1
        while index < reversed.length() &&
              pdf_ua_matterhorn_path_construction_op(reversed[index]) {
          index += 1
        }
      }
      op => {
        if pdf_ua_matterhorn_real_op(op) {
          return true
        }
        index += 1
      }
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops() {
    if pdf_ua_matterhorn_artifact_in_content_ops(ops) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_004(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops() {
    if pdf_ua_matterhorn_content_in_artifact_ops(ops) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_005(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops(xobjects=false) {
    let (naked, error) = pdf_ua_matterhorn_naked_ops(ops)
    match error {
      Some(extra) => return Some(extra)
      None =>
        if pdf_ua_matterhorn_unfiltered_real_op(naked) {
          return Some(Json::null())
        }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_007(self : PdfDocument) -> Json? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ua_markinfo_key(),
      pdf_ua_matterhorn_suspects_key(),
    ]) {
    Some(PdfBoolean(true)) => Some(Json::null())
    _ => None
  }
}

///|
fn pdf_ua_matterhorn_name_text(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

///|
fn pdf_ua_matterhorn_standard_structure_types_2008() -> Array[PdfName] {
  [
    pdf_ua_name("/Document"),
    pdf_ua_name("/Part"),
    pdf_ua_name("/Sect"),
    pdf_ua_name("/Div"),
    pdf_ua_name("/NonStruct"),
    pdf_ua_name("/P"),
    pdf_ua_name("/H1"),
    pdf_ua_name("/H2"),
    pdf_ua_name("/H3"),
    pdf_ua_name("/H4"),
    pdf_ua_name("/H5"),
    pdf_ua_name("/H6"),
    pdf_ua_name("/H"),
    pdf_ua_name("/Lbl"),
    pdf_ua_name("/Span"),
    pdf_ua_name("/Link"),
    pdf_ua_name("/Annot"),
    pdf_ua_name("/Form"),
    pdf_ua_name("/Ruby"),
    pdf_ua_name("/RB"),
    pdf_ua_name("/RT"),
    pdf_ua_name("/RP"),
    pdf_ua_name("/Warichu"),
    pdf_ua_name("/WT"),
    pdf_ua_name("/WP"),
    pdf_ua_name("/L"),
    pdf_ua_name("/LI"),
    pdf_ua_name("/LBody"),
    pdf_ua_name("/Table"),
    pdf_ua_name("/TR"),
    pdf_ua_name("/TH"),
    pdf_ua_name("/TD"),
    pdf_ua_name("/THead"),
    pdf_ua_name("/TBody"),
    pdf_ua_name("/TFoot"),
    pdf_ua_name("/Caption"),
    pdf_ua_name("/Figure"),
    pdf_ua_name("/Formula"),
    pdf_ua_name("/Art"),
    pdf_ua_name("/BlockQuote"),
    pdf_ua_name("/TOC"),
    pdf_ua_name("/TOCI"),
    pdf_ua_name("/Index"),
    pdf_ua_name("/Private"),
    pdf_ua_name("/Quote"),
    pdf_ua_name("/Note"),
    pdf_ua_name("/Reference"),
    pdf_ua_name("/Code"),
    pdf_ua_name("/BibEntry"),
  ]
}

///|
fn pdf_ua_matterhorn_standard_structure_type(name : PdfName) -> Bool {
  pdf_ua_matterhorn_standard_structure_types_2008().contains(name)
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_role_is_circular(
  self : PdfUAStructTreeRoleMap,
  name : PdfName,
) -> Bool {
  let mut current = name
  let mut remaining = self.entries.length()
  while true {
    if remaining < 0 {
      return true
    }
    match self.mapped(current) {
      Some(next) => {
        current = next
        remaining -= 1
      }
      None => return false
    }
  }
  false
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_has_circular_mapping(
  self : PdfUAStructTreeRoleMap,
) -> Bool {
  for entry in self.entries {
    if self.pdf_ua_matterhorn_role_is_circular(entry.0) {
      return true
    }
  }
  false
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_role_terminates_at_standard(
  self : PdfUAStructTreeRoleMap,
  name : PdfName,
) -> Bool {
  let mut current = name
  let mut remaining = self.entries.length()
  while remaining >= 0 {
    match self.mapped(current) {
      Some(next) =>
        if pdf_ua_matterhorn_standard_structure_type(next) {
          return true
        } else {
          current = next
          remaining -= 1
        }
      None => return false
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_rolemap(
  self : PdfDocument,
) -> PdfUAStructTreeRoleMap {
  self.pdf_ua_struct_tree_rolemap()
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_001(self : PdfDocument) -> Json? {
  let rolemap = self.pdf_ua_matterhorn_rolemap()
  if rolemap.pdf_ua_matterhorn_has_circular_mapping() {
    None
  } else {
    for entry in rolemap.entries {
      if !rolemap.pdf_ua_matterhorn_role_terminates_at_standard(entry.0) {
        return Some(Json::string(pdf_ua_matterhorn_name_text(entry.0)))
      }
    }
    None
  }
}

///|
fn pdf_ua_matterhorn_circular_rolemap_extra() -> Json {
  Json::string("STOP. If rolemap circular, cannot proceed with other checks.")
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_003(self : PdfDocument) -> Json? {
  if self.pdf_ua_matterhorn_rolemap().pdf_ua_matterhorn_has_circular_mapping() {
    Some(pdf_ua_matterhorn_circular_rolemap_extra())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_004(self : PdfDocument) -> Json? {
  let rolemap = self.pdf_ua_matterhorn_rolemap()
  for entry in rolemap.entries {
    if pdf_ua_matterhorn_standard_structure_type(entry.0) {
      return Some(Json::string(pdf_ua_matterhorn_name_text(entry.0)))
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_xmp_field_exists(
  metadata : BytesView,
  xml_namespace : String,
  fallback_prefix : String,
  name : String,
) -> Bool {
  pdf_metadata_get_xmp_data(metadata, xml_namespace, fallback_prefix, name)
  is Some(_)
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(_) => None
    None => Some(Json::null())
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(metadata) =>
      if pdf_ua_matterhorn_xmp_field_exists(
          metadata, pdf_metadata_pdfuaid_namespace, "pdfuaid", "part",
        ) {
        None
      } else {
        Some(Json::null())
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(metadata) =>
      if pdf_ua_matterhorn_xmp_field_exists(
          metadata, pdf_metadata_dc_namespace, "dc", "title",
        ) {
        None
      } else {
        Some(Json::null())
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_display_doc_title(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ua_viewer_preferences_key(),
    pdf_ua_display_doc_title_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_07_001(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_display_doc_title() {
    None => Some(Json::null())
    Some(_) => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_07_002(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_display_doc_title() {
    Some(PdfBoolean(false)) => Some(Json::null())
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_ocproperties_d(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ocg_ocproperties_key(),
    pdf_ocg_d_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_ocproperties_configs(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ocg_ocproperties_key(),
    pdf_ocg_configs_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_001(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_ocproperties_configs() {
    Some(PdfArray(configs)) =>
      for config in configs {
        match self.lookup_direct(pdf_ocg_name_key(), config) {
          None => return Some(Json::null())
          Some(PdfNameObject(name)) if name == pdf_ua_empty_name() =>
            return Some(Json::null())
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_002(self : PdfDocument) -> Json? {
  match
    (
      self.pdf_ua_matterhorn_ocproperties_d(),
      self.lookup_chain(self.trailer_dict(), [
        pdf_ua_root_key(),
        pdf_ocg_ocproperties_key(),
        pdf_ocg_d_key(),
        pdf_ocg_name_key(),
      ]),
    ) {
    (Some(_), Some(PdfString(value))) if value.length() == 0 =>
      Some(Json::string("empty string"))
    (Some(_), None) => Some(Json::string("not present"))
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_003(self : PdfDocument) -> Json? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ocg_ocproperties_key(),
      pdf_ocg_d_key(),
      pdf_ocg_as_key(),
    ]) {
    Some(_) => return Some(Json::null())
    None => ()
  }
  match self.pdf_ua_matterhorn_ocproperties_configs() {
    Some(PdfArray(configs)) =>
      for config in configs {
        match self.lookup_direct(pdf_ocg_as_key(), config) {
          Some(_) => return Some(Json::null())
          None => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_media_clip_mcd_without_ct(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match
    (
      self.lookup_direct(pdf_ua_type_key(), object),
      self.lookup_direct(pdf_ua_s_key(), object),
      self.lookup_direct(pdf_ua_matterhorn_ct_key(), object),
    ) {
    (Some(PdfNameObject(kind)), Some(PdfNameObject(subtype)), None) =>
      kind == pdf_ua_matterhorn_media_clip() &&
      subtype == pdf_ua_matterhorn_mcd()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_014(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_media_clip_mcd_without_ct(entry.2) {
      return Some(Json::null())
    }
  }
  None
}

///|
// Preserve cpdf source behavior: 28-015 reports missing /Alt but checks the
// same missing /CT condition as 28-014.
fn PdfDocument::pdf_ua_matterhorn_check_28_015(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_media_clip_mcd_without_ct(entry.2) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_016(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_printer_mark(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_ua_matterhorn_printer_mark()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_017(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_printer_mark(entry.2) &&
      self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2)
      is Some(_) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_normal_appearance_streams(
  self : PdfDocument,
  annotation : PdfObject,
) -> Array[PdfObject] {
  let output : Array[PdfObject] = []
  match self.lookup_direct(pdf_ua_matterhorn_ap_key(), annotation) {
    Some(appearance_dictionary) =>
      match
        self.lookup_direct(pdf_ua_matterhorn_n_key(), appearance_dictionary) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            output.push(self.direct(entry.1))
          }
        Some(appearance) => output.push(appearance)
        None => ()
      }
    None => ()
  }
  output
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_018(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_printer_mark(entry.2) {
      for stream in self.pdf_ua_matterhorn_normal_appearance_streams(entry.2) {
        let resources = self.pdf_ua_matterhorn_stream_resources(stream)
        let ops = self.parse_content_ops_with_resources(resources, [stream])
        if pdf_content_add_artifacts(ops) != ops {
          return Some(Json::null())
        }
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_30_001(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_subtype_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_ref_key(), entry.2),
      ) {
      (Some(PdfNameObject(subtype)), Some(_)) if subtype ==
        pdf_ua_matterhorn_form() => return Some(Json::null())
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_int_array_contains(
  values : ArrayView[Int],
  target : Int,
) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_ops_contain_mcid(
  self : PdfDocument,
  ops : ArrayView[PdfContentOp],
) -> Bool {
  for op in ops {
    match op {
      Op_BDC(_, properties) =>
        if self.lookup_direct(pdf_ua_matterhorn_mcid_key(), properties)
          is Some(_) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_form_xobject_contains_mcid(
  self : PdfDocument,
  object_number : Int,
) -> Bool raise PdfError {
  let object = self.lookup_object_or_null(object_number)
  let resources = self.pdf_ua_matterhorn_stream_resources(object)
  let ops = self.parse_content_ops_with_resources(resources, [object])
  self.pdf_ua_matterhorn_ops_contain_mcid(ops)
}

///|
fn PdfDocument::pdf_ua_matterhorn_form_xobject_numbers(
  self : PdfDocument,
) -> Array[Int] {
  self.select_object_numbers(fn(object) {
    pdf_ua_matterhorn_is_form_stream(self, object)
  })
}

///|
fn PdfDocument::pdf_ua_matterhorn_referenced_mcid_xobjects(
  self : PdfDocument,
  object_number : Int,
  containing_mcids : ArrayView[Int],
) -> Array[Int] {
  let references : Array[Int] = []
  match
    self.lookup_direct(
      pdf_ua_matterhorn_resources_key(),
      PdfIndirect(object_number),
    ) {
    Some(resources) =>
      match self.lookup_direct(pdf_ua_matterhorn_xobject_key(), resources) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            match entry.1 {
              PdfIndirect(target) =>
                if pdf_ua_matterhorn_int_array_contains(
                    containing_mcids, target,
                  ) {
                  references.push(target)
                }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
  references
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_30_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  let page_numbers = self.page_reference_numbers()
  self.replace_inherit(page_numbers)
  let form_xobject_numbers = self.pdf_ua_matterhorn_form_xobject_numbers()
  let containing_mcids : Array[Int] = []
  for number in form_xobject_numbers {
    if self.pdf_ua_matterhorn_form_xobject_contains_mcid(number) {
      containing_mcids.push(number)
    }
  }
  let seen : Array[Int] = []
  for number in form_xobject_numbers {
    for
      target in self.pdf_ua_matterhorn_referenced_mcid_xobjects(
        number, containing_mcids,
      ) {
      if pdf_ua_matterhorn_int_array_contains(seen, target) {
        return Some(Json::null())
      }
      seen.push(target)
    }
  }
  for number in page_numbers {
    for
      target in self.pdf_ua_matterhorn_referenced_mcid_xobjects(
        number, containing_mcids,
      ) {
      if pdf_ua_matterhorn_int_array_contains(seen, target) {
        return Some(Json::null())
      }
      seen.push(target)
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_type0_indirect_encoding(
  self : PdfDocument,
  object : PdfObject,
) -> Int? {
  let direct_object = self.direct(object)
  match
    (
      self.lookup_direct(pdf_ua_subtype_key(), direct_object),
      direct_object.lookup_immediate(pdf_ua_matterhorn_encoding_key()),
    ) {
    (Some(PdfNameObject(subtype)), Some(PdfNameObject(encoding))) if subtype ==
      pdf_ua_matterhorn_type0() &&
      (
        encoding == pdf_ua_matterhorn_identity_h() ||
        encoding == pdf_ua_matterhorn_identity_v()
      ) => None
    (Some(PdfNameObject(subtype)), Some(PdfIndirect(encoding_number))) if subtype ==
      pdf_ua_matterhorn_type0() => Some(encoding_number)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_cid_system_entry(
  self : PdfDocument,
  object : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match self.lookup_direct(pdf_ua_matterhorn_cid_system_info_key(), object) {
    Some(info) => self.lookup_direct(key, info)
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_descendant_cid_system_entry(
  self : PdfDocument,
  type0_font : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match
    self.lookup_direct(pdf_ua_matterhorn_descendant_fonts_key(), type0_font) {
    Some(PdfArray([descendant, ..])) =>
      self.pdf_ua_matterhorn_cid_system_entry(descendant, key)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_type0_cid_system_entry(
  self : PdfDocument,
  key : PdfName,
) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.pdf_ua_matterhorn_type0_indirect_encoding(entry.2) {
      Some(encoding_number) =>
        if self.pdf_ua_matterhorn_cid_system_entry(
            PdfIndirect(encoding_number),
            key,
          ) !=
          self.pdf_ua_matterhorn_descendant_cid_system_entry(entry.2, key) {
          return Some(Json::null())
        }
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_001(self : PdfDocument) -> Json? {
  self.pdf_ua_matterhorn_check_type0_cid_system_entry(
    pdf_ua_matterhorn_registry_key(),
  )
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_002(self : PdfDocument) -> Json? {
  self.pdf_ua_matterhorn_check_type0_cid_system_entry(
    pdf_ua_matterhorn_ordering_key(),
  )
}

///|
fn PdfDocument::pdf_ua_matterhorn_run_test(
  self : PdfDocument,
  check : PdfUAMatterhornTest,
) -> PdfUAMatterhornFailure? raise PdfError {
  let result = match check.name {
    "01-003" => self.pdf_ua_matterhorn_check_01_003()
    "01-004" => self.pdf_ua_matterhorn_check_01_004()
    "01-005" => self.pdf_ua_matterhorn_check_01_005()
    "01-007" => self.pdf_ua_matterhorn_check_01_007()
    "02-001" => self.pdf_ua_matterhorn_check_02_001()
    "02-003" => self.pdf_ua_matterhorn_check_02_003()
    "02-004" => self.pdf_ua_matterhorn_check_02_004()
    "06-001" => self.pdf_ua_matterhorn_check_06_001()
    "06-002" => self.pdf_ua_matterhorn_check_06_002()
    "06-003" => self.pdf_ua_matterhorn_check_06_003()
    "07-001" => self.pdf_ua_matterhorn_check_07_001()
    "07-002" => self.pdf_ua_matterhorn_check_07_002()
    "20-001" => self.pdf_ua_matterhorn_check_20_001()
    "20-002" => self.pdf_ua_matterhorn_check_20_002()
    "20-003" => self.pdf_ua_matterhorn_check_20_003()
    "28-014" => self.pdf_ua_matterhorn_check_28_014()
    "28-015" => self.pdf_ua_matterhorn_check_28_015()
    "28-016" => self.pdf_ua_matterhorn_check_28_016()
    "28-017" => self.pdf_ua_matterhorn_check_28_017()
    "28-018" => self.pdf_ua_matterhorn_check_28_018()
    "30-001" => self.pdf_ua_matterhorn_check_30_001()
    "30-002" => self.pdf_ua_matterhorn_check_30_002()
    "31-001" => self.pdf_ua_matterhorn_check_31_001()
    "31-002" => self.pdf_ua_matterhorn_check_31_002()
    _ => None
  }
  match result {
    Some(extra) => Some(pdf_ua_matterhorn_failure(check, extra~))
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_circular_rolemap_failure(
  self : PdfDocument,
) -> PdfUAMatterhornFailure? {
  match self.pdf_ua_matterhorn_check_02_003() {
    Some(extra) =>
      Some(pdf_ua_matterhorn_failure(pdf_ua_matterhorn_test_02_003(), extra~))
    None => None
  }
}

///|
fn pdf_ua_matterhorn_tests_for_name(
  test_name : String,
) -> Array[PdfUAMatterhornTest] raise PdfError {
  let tests = pdf_ua_matterhorn_implemented_tests()
  if test_name == "" {
    tests
  } else {
    for check in tests {
      if check.name == test_name {
        return [check]
      }
    }
    raise SoftError("Matterhorn test not yet implemented: " + test_name)
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_failures(
  self : PdfDocument,
  test_name : String,
) -> Array[PdfUAMatterhornFailure] raise PdfError {
  let checks = pdf_ua_matterhorn_tests_for_name(test_name)
  match self.pdf_ua_matterhorn_circular_rolemap_failure() {
    Some(failure) => return [failure]
    None => ()
  }
  let failures : Array[PdfUAMatterhornFailure] = []
  for check in checks {
    match self.pdf_ua_matterhorn_run_test(check) {
      Some(failure) => failures.push(failure)
      None => ()
    }
  }
  failures
}

///|
/// Return cpdf-style PDF/UA Matterhorn failures as JSON.
///
/// The current migration covers content-marking checks `01-003`, `01-004`,
/// `01-005`, and `01-007`, role-map checks `02-001`, `02-003`, and `02-004`,
/// XMP metadata and DisplayDocTitle checks `06-001` through `07-002`, and
/// optional-content configuration checks `20-001` through `20-003`, media-clip
/// checks `28-014` and `28-015`, file-attachment no-op `28-016`, PrinterMark
/// object and appearance checks `28-017` and `28-018`, plus reference-XObject
/// checks `30-001` and `30-002`, plus Type 0 CIDSystemInfo checks `31-001` and
/// `31-002`. Passing `""` runs the covered subset; unsupported individual test
/// names raise a soft error until their source checks are ported.
pub fn PdfDocument::test_matterhorn_json(
  self : PdfDocument,
  test_name : String,
) -> Json raise PdfError {
  Json::array(
    [
      for failure in self.pdf_ua_matterhorn_failures(test_name) => {
        failure.to_json()
      }
    ],
  )
}

///|
fn pdf_ua_matterhorn_push_text_failure(
  output : Array[Byte],
  failure : PdfUAMatterhornFailure,
) -> Unit {
  pdf_ua_push_ascii(output, failure.name)
  output.push(32)
  pdf_ua_push_ascii(output, failure.section)
  output.push(32)
  pdf_ua_push_utf8(output, failure.error)
  output.push(32)
  if failure.extra != Json::null() {
    output.push(40)
    pdf_ua_push_utf8(output, failure.extra.stringify())
    output.push(41)
  }
  output.push(10)
}

///|
/// Return cpdf-style text lines for the covered Matterhorn failures.
pub fn PdfDocument::test_matterhorn_text(
  self : PdfDocument,
  test_name : String,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for failure in self.pdf_ua_matterhorn_failures(test_name) {
    pdf_ua_matterhorn_push_text_failure(output, failure)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::test_matterhorn_json`.
pub fn pdf_ua_test_matterhorn_json(
  document : PdfDocument,
  test_name : String,
) -> Json raise PdfError {
  document.test_matterhorn_json(test_name)
}

///|
/// Compatibility wrapper for `PdfDocument::test_matterhorn_text`.
pub fn pdf_ua_test_matterhorn_print(
  document : PdfDocument,
  test_name : String,
) -> PdfBytes raise PdfError {
  document.test_matterhorn_text(test_name)
}
