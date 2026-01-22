///|
pub struct Workbook {
  sheets : Array[Worksheet]
  chart_sheets : Array[ChartSheet]
  sheet_order : Array[SheetEntry]
  styles : Array[Style]
  conditional_styles : Array[Style]
  defined_names : Array[DefinedName]
  mut core_properties : CoreProperties
  mut app_properties : AppProperties
  custom_properties : Array[CustomProperty]
  mut vba_project : Bytes?
  mut workbook_props : WorkbookPropsOptions
  mut calc_props : CalcPropsOptions
  mut default_font : String
  theme_colors : Array[String]?
  indexed_colors : Array[String]?
  mut workbook_protection : WorkbookProtection?
  mut active_sheet_index : Int
}

///|
enum SheetEntry {
  Worksheet(Int)
  ChartSheet(Int)
} derive(Eq, Show)

///|
let max_sheet_name_length = 31

///|
let ole_identifier_bytes : Bytes = Bytes::from_array(ole_identifier)

///|
fn check_sheet_name(name : StringView) -> Unit raise XlsxError {
  let text = name.to_string()
  if text == "" {
    raise XlsxError::InvalidSheetName(msg="sheet name is blank")
  }
  if text.length() > max_sheet_name_length {
    raise XlsxError::InvalidSheetName(msg="sheet name too long")
  }
  if text.has_prefix("'") || text.has_suffix("'") {
    raise XlsxError::InvalidSheetName(
      msg="sheet name cannot start or end with a single quote",
    )
  }
  for c in text {
    match c {
      ':' | '\\' | '/' | '?' | '*' | '[' | ']' =>
        raise XlsxError::InvalidSheetName(
          msg="sheet name contains invalid characters",
        )
      _ => ()
    }
  }
}

///|
fn normalize_sheet_name(name : StringView) -> String {
  name.to_string().to_lower()
}

///|
fn sheet_name_equal(a : StringView, b : StringView) -> Bool {
  normalize_sheet_name(a) == normalize_sheet_name(b)
}

///|
fn Workbook::sheet_entry_index(self : Workbook, name : StringView) -> Int? {
  let needle = normalize_sheet_name(name)
  for i, entry in self.sheet_order {
    match entry {
      SheetEntry::Worksheet(idx) =>
        if normalize_sheet_name(self.sheets[idx].name()) == needle {
          return Some(i)
        }
      SheetEntry::ChartSheet(idx) =>
        if normalize_sheet_name(self.chart_sheets[idx].name()) == needle {
          return Some(i)
        }
    }
  }
  None
}

///|
fn Workbook::sheet_entry(self : Workbook, name : StringView) -> SheetEntry? {
  let needle = normalize_sheet_name(name)
  for entry in self.sheet_order {
    match entry {
      SheetEntry::Worksheet(idx) =>
        if normalize_sheet_name(self.sheets[idx].name()) == needle {
          return Some(entry)
        }
      SheetEntry::ChartSheet(idx) =>
        if normalize_sheet_name(self.chart_sheets[idx].name()) == needle {
          return Some(entry)
        }
    }
  }
  None
}

///|
fn Workbook::sheet_entry_name(self : Workbook, entry : SheetEntry) -> String {
  match entry {
    SheetEntry::Worksheet(idx) => self.sheets[idx].name()
    SheetEntry::ChartSheet(idx) => self.chart_sheets[idx].name()
  }
}

///|
fn Workbook::sheet_entry_state(
  self : Workbook,
  entry : SheetEntry,
) -> SheetState {
  match entry {
    SheetEntry::Worksheet(idx) => self.sheets[idx].state()
    SheetEntry::ChartSheet(idx) => self.chart_sheets[idx].state()
  }
}

///|
fn Workbook::set_sheet_entry_state(
  self : Workbook,
  entry : SheetEntry,
  state : SheetState,
) -> Unit {
  match entry {
    SheetEntry::Worksheet(idx) => self.sheets[idx].state = state
    SheetEntry::ChartSheet(idx) => self.chart_sheets[idx].state = state
  }
}

///|
fn defined_name_scope_key(scope : StringView) -> String {
  let normalized = normalize_defined_name_scope(scope)
  if normalized == "Workbook" {
    "workbook"
  } else {
    normalize_sheet_name(normalized)
  }
}

///|
pub fn Workbook::new() -> Workbook {
  {
    sheets: [],
    chart_sheets: [],
    sheet_order: [],
    styles: [Style::new()],
    conditional_styles: [],
    defined_names: [],
    core_properties: CoreProperties::new(),
    app_properties: AppProperties::new(),
    custom_properties: [],
    vba_project: None,
    workbook_props: WorkbookPropsOptions::new(),
    calc_props: CalcPropsOptions::new(),
    default_font: "Calibri",
    theme_colors: None,
    indexed_colors: None,
    workbook_protection: None,
    active_sheet_index: 0,
  }
}

///|
pub fn Workbook::add_sheet(
  self : Workbook,
  name : String,
) -> Worksheet raise XlsxError {
  check_sheet_name(name)
  match self.sheet_entry(name) {
    Some(_) => raise XlsxError::SheetAlreadyExists(name~)
    None => ()
  }
  let sheet = Worksheet::new(name)
  self.sheets.push(sheet)
  self.sheet_order.push(SheetEntry::Worksheet(self.sheets.length() - 1))
  if self.sheet_order.length() == 1 {
    self.active_sheet_index = 0
  }
  sheet
}

///|
pub fn Workbook::add_chart_sheet(
  self : Workbook,
  name : String,
  chart_xml : String,
) -> ChartSheet raise XlsxError {
  check_sheet_name(name)
  match self.sheet_entry(name) {
    Some(_) => raise XlsxError::SheetAlreadyExists(name~)
    None => ()
  }
  let sheet = ChartSheet::new(name, chart_xml)
  self.chart_sheets.push(sheet)
  self.sheet_order.push(SheetEntry::ChartSheet(self.chart_sheets.length() - 1))
  if self.sheet_order.length() == 1 {
    self.active_sheet_index = 0
  }
  sheet
}

///|
pub fn Workbook::new_stream_writer(
  self : Workbook,
  sheet_name : StringView,
) -> StreamWriter raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  if sheet.stream_state != StreamState::Idle {
    raise XlsxError::StreamModeConflict(msg="stream writer already active")
  }
  if sheet.cells().length() > 0 {
    raise XlsxError::StreamModeConflict(msg="worksheet already has data")
  }
  sheet.stream_state = StreamState::Writing
  StreamWriter::new(sheet, self.styles.length())
}

///|
pub fn Workbook::sheet(self : Workbook, name : StringView) -> Worksheet? {
  let needle = normalize_sheet_name(name)
  for sheet in self.sheets {
    if normalize_sheet_name(sheet.name()) == needle {
      return Some(sheet)
    }
  }
  None
}

///|
pub fn Workbook::chart_sheet(self : Workbook, name : StringView) -> ChartSheet? {
  let needle = normalize_sheet_name(name)
  for sheet in self.chart_sheets {
    if normalize_sheet_name(sheet.name()) == needle {
      return Some(sheet)
    }
  }
  None
}

///|
pub fn Workbook::sheet_name(self : Workbook, index : Int) -> String? {
  if index < 0 || index >= self.sheet_order.length() {
    return None
  }
  Some(self.sheet_entry_name(self.sheet_order[index]))
}

///|
pub fn Workbook::get_sheet_list(self : Workbook) -> Array[String] {
  let names : Array[String] = []
  for entry in self.sheet_order {
    names.push(self.sheet_entry_name(entry))
  }
  names
}

///|
pub fn Workbook::get_sheet_map(self : Workbook) -> Map[Int, String] {
  let mapping : Map[Int, String] = {}
  for index, entry in self.sheet_order {
    mapping[index + 1] = self.sheet_entry_name(entry)
  }
  mapping
}

///|
pub fn Workbook::sheet_index(
  self : Workbook,
  name : StringView,
) -> Int raise XlsxError {
  match self.sheet_entry_index(name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=name.to_string())
  }
}

///|
pub fn Workbook::sheets(self : Workbook) -> ArrayView[Worksheet] {
  self.sheets[:]
}

///|
pub fn Workbook::chart_sheets(self : Workbook) -> ArrayView[ChartSheet] {
  self.chart_sheets[:]
}

///|
pub fn Workbook::styles(self : Workbook) -> ArrayView[Style] {
  self.styles[:]
}

///|
pub fn Workbook::conditional_styles(self : Workbook) -> ArrayView[Style] {
  self.conditional_styles[:]
}

///|
pub fn Workbook::defined_names(self : Workbook) -> ArrayView[DefinedName] {
  self.defined_names[:]
}

///|
pub fn Workbook::core_properties(self : Workbook) -> CoreProperties {
  self.core_properties
}

///|
pub fn Workbook::set_core_properties(
  self : Workbook,
  props : CoreProperties,
) -> Unit {
  self.core_properties = props
}

///|
pub fn Workbook::doc_properties(self : Workbook) -> CoreProperties {
  self.core_properties
}

///|
pub fn Workbook::set_doc_properties(
  self : Workbook,
  props : CoreProperties,
) -> Unit {
  self.core_properties = props
}

///|
pub fn Workbook::get_doc_props(self : Workbook) -> CoreProperties {
  self.core_properties
}

///|
pub fn Workbook::set_doc_props(self : Workbook, props : CoreProperties) -> Unit {
  self.core_properties = props
}

///|
pub fn Workbook::app_properties(self : Workbook) -> AppProperties {
  self.app_properties
}

///|
pub fn Workbook::set_app_properties(
  self : Workbook,
  props : AppProperties,
) -> Unit {
  self.app_properties = props
}

///|
pub fn Workbook::app_props(self : Workbook) -> AppProperties {
  self.app_properties
}

///|
pub fn Workbook::set_app_props(self : Workbook, props : AppProperties) -> Unit {
  self.app_properties = props
}

///|
pub fn Workbook::get_app_props(self : Workbook) -> AppProperties {
  self.app_properties
}

///|
pub fn Workbook::custom_properties(self : Workbook) -> Array[CustomProperty] {
  let props : Array[CustomProperty] = []
  for prop in self.custom_properties {
    props.push(prop)
  }
  props
}

///|
pub fn Workbook::get_custom_props(self : Workbook) -> Array[CustomProperty] {
  self.custom_properties()
}

///|
pub fn Workbook::set_custom_props(
  self : Workbook,
  prop : CustomProperty,
) -> Unit raise XlsxError {
  if prop.name == "" {
    raise XlsxError::InvalidWorkbookProperty(msg="custom property name missing")
  }
  let mut index : Int? = None
  for i, existing in self.custom_properties {
    if existing.name == prop.name {
      index = Some(i)
      break
    }
  }
  match prop.value {
    None =>
      match index {
        Some(i) => {
          ignore(self.custom_properties.remove(i))
          ()
        }
        None => ()
      }
    Some(_) =>
      match index {
        Some(i) => self.custom_properties[i] = prop
        None => self.custom_properties.push(prop)
      }
  }
}

///|
pub fn Workbook::add_vba_project(
  self : Workbook,
  data : Bytes,
) -> Unit raise XlsxError {
  if data.find(ole_identifier_bytes) is None {
    raise XlsxError::InvalidVBAProject(msg="unsupported vba project")
  }
  self.vba_project = Some(data)
}

///|
pub fn Workbook::workbook_props(self : Workbook) -> WorkbookPropsOptions {
  self.workbook_props
}

///|
pub fn Workbook::get_workbook_props(self : Workbook) -> WorkbookPropsOptions {
  self.workbook_props
}

///|
pub fn Workbook::set_workbook_props(
  self : Workbook,
  options : WorkbookPropsOptions?,
) -> Unit {
  self.workbook_props = match options {
    Some(value) => value
    None => WorkbookPropsOptions::new()
  }
}

///|
pub fn Workbook::calc_props(self : Workbook) -> CalcPropsOptions {
  self.calc_props
}

///|
pub fn Workbook::get_calc_props(self : Workbook) -> CalcPropsOptions {
  self.calc_props
}

///|
pub fn Workbook::set_calc_props(
  self : Workbook,
  options : CalcPropsOptions?,
) -> Unit raise XlsxError {
  let value = match options {
    Some(opts) => normalize_calc_props(opts)
    None => CalcPropsOptions::new()
  }
  self.calc_props = value
}

///|
pub fn Workbook::default_font(self : Workbook) -> String {
  self.default_font
}

///|
pub fn Workbook::get_default_font(self : Workbook) -> String {
  self.default_font
}

///|
pub fn Workbook::set_default_font(self : Workbook, font_name : String) -> Unit {
  self.default_font = font_name
}

///|
pub fn Workbook::protect_workbook(
  self : Workbook,
  options? : WorkbookProtectionOptions = WorkbookProtectionOptions::new(),
) -> Unit raise XlsxError {
  self.workbook_protection = Some(workbook_protection_from_options(options))
}

///|
pub fn Workbook::unprotect_workbook(
  self : Workbook,
  password? : String = "",
) -> Unit raise XlsxError {
  let protection = match self.workbook_protection {
    Some(value) => value
    None =>
      raise XlsxError::InvalidWorkbookProtection(msg="workbook not protected")
  }
  if password != "" {
    verify_workbook_protection_password(protection, password)
  }
  self.workbook_protection = None
}

///|
pub fn Workbook::active_sheet_index(self : Workbook) -> Int {
  self.active_sheet_index
}

///|
pub fn Workbook::set_active_sheet(self : Workbook, index : Int) -> Unit {
  if self.sheet_order.length() == 0 {
    self.active_sheet_index = 0
    return
  }
  if index < 0 || index >= self.sheet_order.length() {
    self.active_sheet_index = 0
  } else {
    self.active_sheet_index = index
  }
}

///|
pub fn Workbook::set_sheet_name(
  self : Workbook,
  source : StringView,
  target : String,
) -> Unit raise XlsxError {
  check_sheet_name(source)
  check_sheet_name(target)
  if sheet_name_equal(source, target) {
    return
  }
  match self.sheet_entry(target) {
    Some(_) => raise XlsxError::SheetAlreadyExists(name=target)
    None => ()
  }
  let entry = match self.sheet_entry(source) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=source.to_string())
  }
  let old_name = self.sheet_entry_name(entry)
  match entry {
    SheetEntry::Worksheet(idx) => self.sheets[idx].name = target
    SheetEntry::ChartSheet(idx) => self.chart_sheets[idx].name = target
  }
  if self.defined_names.length() > 0 {
    let updated : Array[DefinedName] = []
    for dn in self.defined_names {
      let scope = if sheet_name_equal(dn.scope, old_name) {
        target
      } else {
        dn.scope
      }
      let refers_to = replace_sheet_name_in_refers_to(
        dn.refers_to,
        old_name,
        target,
      )
      updated.push({ name: dn.name, refers_to, scope, comment: dn.comment })
    }
    self.defined_names.clear()
    self.defined_names.append(updated[:])
  }
}

///|
pub fn Workbook::delete_sheet(
  self : Workbook,
  name : StringView,
) -> Unit raise XlsxError {
  check_sheet_name(name)
  let entry = match self.sheet_entry(name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=name.to_string())
  }
  let order_index = match self.sheet_entry_index(name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=name.to_string())
  }
  let deleted_name = self.sheet_entry_name(entry)
  if self.sheet_order.length() <= 1 {
    raise XlsxError::InvalidSheetOperation(
      msg="workbook must contain at least one sheet",
    )
  }
  ignore(self.sheet_order.remove(order_index))
  match entry {
    SheetEntry::Worksheet(idx) => {
      ignore(self.sheets.remove(idx))
      let updated : Array[SheetEntry] = []
      for item in self.sheet_order {
        match item {
          SheetEntry::Worksheet(value) =>
            if value > idx {
              updated.push(SheetEntry::Worksheet(value - 1))
            } else {
              updated.push(item)
            }
          SheetEntry::ChartSheet(_) => updated.push(item)
        }
      }
      self.sheet_order.clear()
      self.sheet_order.append(updated[:])
    }
    SheetEntry::ChartSheet(idx) => {
      ignore(self.chart_sheets.remove(idx))
      let updated : Array[SheetEntry] = []
      for item in self.sheet_order {
        match item {
          SheetEntry::ChartSheet(value) =>
            if value > idx {
              updated.push(SheetEntry::ChartSheet(value - 1))
            } else {
              updated.push(item)
            }
          SheetEntry::Worksheet(_) => updated.push(item)
        }
      }
      self.sheet_order.clear()
      self.sheet_order.append(updated[:])
    }
  }
  if self.defined_names.length() > 0 {
    let deleted_key = defined_name_scope_key(deleted_name)
    let updated : Array[DefinedName] = []
    for dn in self.defined_names {
      if defined_name_scope_key(dn.scope) == deleted_key {
        continue
      }
      updated.push(dn)
    }
    self.defined_names.clear()
    self.defined_names.append(updated[:])
  }
  if self.active_sheet_index == order_index {
    let fallback = if order_index >= self.sheet_order.length() {
      self.sheet_order.length() - 1
    } else {
      order_index
    }
    self.active_sheet_index = fallback
  } else if self.active_sheet_index > order_index {
    self.active_sheet_index = self.active_sheet_index - 1
  }
}

///|
pub fn Workbook::move_sheet(
  self : Workbook,
  source : StringView,
  target : StringView,
) -> Unit raise XlsxError {
  check_sheet_name(source)
  check_sheet_name(target)
  if sheet_name_equal(source, target) {
    return
  }
  let source_index = self.sheet_index(source)
  let target_index = self.sheet_index(target)
  let entry = self.sheet_order.remove(source_index)
  let insert_index = if target_index > source_index {
    target_index - 1
  } else {
    target_index
  }
  self.sheet_order.insert(insert_index, entry)
  if self.active_sheet_index == source_index {
    self.active_sheet_index = insert_index
  } else if source_index < self.active_sheet_index &&
    insert_index >= self.active_sheet_index {
    self.active_sheet_index = self.active_sheet_index - 1
  } else if source_index > self.active_sheet_index &&
    insert_index <= self.active_sheet_index {
    self.active_sheet_index = self.active_sheet_index + 1
  }
}

///|
pub fn Workbook::copy_sheet(
  self : Workbook,
  from_index : Int,
  to_index : Int,
) -> Unit raise XlsxError {
  if from_index < 0 ||
    to_index < 0 ||
    from_index >= self.sheet_order.length() ||
    to_index >= self.sheet_order.length() ||
    from_index == to_index {
    raise XlsxError::InvalidSheetIndex(index=to_index)
  }
  let from_entry = self.sheet_order[from_index]
  let to_entry = self.sheet_order[to_index]
  match (from_entry, to_entry) {
    (SheetEntry::Worksheet(from_sheet_idx), SheetEntry::Worksheet(to_sheet_idx)) => {
      let from_sheet = self.sheets[from_sheet_idx]
      let to_sheet = self.sheets[to_sheet_idx]
      let cloned = clone_worksheet(
        from_sheet,
        to_sheet.name(),
        to_sheet.state(),
      )
      self.sheets[to_sheet_idx] = cloned
    }
    _ => raise XlsxError::InvalidSheetIndex(index=to_index)
  }
}

///|
pub fn Workbook::set_sheet_visible(
  self : Workbook,
  name : StringView,
  visible : Bool,
  very_hidden? : Bool = false,
) -> Unit raise XlsxError {
  check_sheet_name(name)
  let entry = match self.sheet_entry(name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=name.to_string())
  }
  let index = match self.sheet_entry_index(name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=name.to_string())
  }
  let state = if visible {
    SheetState::Visible
  } else if very_hidden {
    SheetState::VeryHidden
  } else {
    SheetState::Hidden
  }
  if state != SheetState::Visible {
    let mut visible_count = 0
    for i, order_entry in self.sheet_order {
      let sheet_state = if i == index {
        state
      } else {
        self.sheet_entry_state(order_entry)
      }
      if sheet_state == SheetState::Visible {
        visible_count = visible_count + 1
      }
    }
    if visible_count == 0 {
      raise XlsxError::InvalidSheetOperation(
        msg="workbook must contain at least one visible sheet",
      )
    }
  }
  self.set_sheet_entry_state(entry, state)
}

///|
pub fn Workbook::sheet_visible(
  self : Workbook,
  name : StringView,
) -> Bool raise XlsxError {
  check_sheet_name(name)
  match self.sheet_entry(name) {
    Some(entry) => self.sheet_entry_state(entry) == SheetState::Visible
    None => raise XlsxError::SheetNotFound(name=name.to_string())
  }
}

///|
pub fn Workbook::set_page_margins(
  self : Workbook,
  sheet_name : StringView,
  options : PageLayoutMarginsOptions?,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_page_margins(options)
}

///|
pub fn Workbook::get_page_margins(
  self : Workbook,
  sheet_name : StringView,
) -> PageLayoutMarginsOptions raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.page_margins()
}

///|
pub fn Workbook::set_page_layout(
  self : Workbook,
  sheet_name : StringView,
  options : PageLayoutOptions?,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_page_layout(options)
}

///|
pub fn Workbook::get_page_layout(
  self : Workbook,
  sheet_name : StringView,
) -> PageLayoutOptions raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.page_layout()
}

///|
pub fn Workbook::set_header_footer(
  self : Workbook,
  sheet_name : StringView,
  options : HeaderFooterOptions?,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_header_footer(options)
}

///|
pub fn Workbook::set_sheet_props(
  self : Workbook,
  sheet_name : StringView,
  options : SheetPropsOptions?,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_sheet_props(options)
}

///|
pub fn Workbook::get_header_footer(
  self : Workbook,
  sheet_name : StringView,
) -> HeaderFooterOptions? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.header_footer()
}

///|
pub fn Workbook::get_header_footer_images(
  self : Workbook,
  sheet_name : StringView,
) -> Array[HeaderFooterImageOptions] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_header_footer_images()
}

///|
pub fn Workbook::get_sheet_props(
  self : Workbook,
  sheet_name : StringView,
) -> SheetPropsOptions raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.sheet_props()
}

///|
pub fn Workbook::set_sheet_view(
  self : Workbook,
  sheet_name : StringView,
  view_index : Int,
  options : SheetViewOptions,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_sheet_view(view_index, options)
}

///|
pub fn Workbook::get_sheet_view(
  self : Workbook,
  sheet_name : StringView,
  view_index : Int,
) -> SheetViewOptions raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_sheet_view(view_index)
}

///|
pub fn Workbook::set_panes(
  self : Workbook,
  sheet_name : StringView,
  panes : Panes,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_panes(panes)
}

///|
pub fn Workbook::get_panes(
  self : Workbook,
  sheet_name : StringView,
) -> Panes raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_panes()
}

///|
pub fn Workbook::set_sheet_dimension(
  self : Workbook,
  sheet_name : StringView,
  range_ref : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_sheet_dimension(range_ref)
}

///|
pub fn Workbook::get_sheet_dimension(
  self : Workbook,
  sheet_name : StringView,
) -> String raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  match sheet.sheet_dimension() {
    Some(value) => value
    None => ""
  }
}

///|
pub fn Workbook::protect_sheet(
  self : Workbook,
  sheet_name : StringView,
  options : SheetProtectionOptions,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.protect_sheet(options)
}

///|
pub fn Workbook::unprotect_sheet(
  self : Workbook,
  sheet_name : StringView,
  password? : String = "",
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.unprotect_sheet(password~)
}

///|
pub fn Workbook::set_sheet_background(
  self : Workbook,
  sheet_name : StringView,
  data : Bytes,
  extension : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_sheet_background(data, extension)
}

///|
pub fn Workbook::clear_sheet_background(
  self : Workbook,
  sheet_name : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.clear_sheet_background()
}

///|
pub fn Workbook::insert_page_break(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.insert_page_break(cell)
}

///|
pub fn Workbook::remove_page_break(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.remove_page_break(cell)
}

///|
pub fn Workbook::set_defined_name(
  self : Workbook,
  defined_name : DefinedName,
) -> Unit raise XlsxError {
  if defined_name.name == "" || defined_name.refers_to == "" {
    raise XlsxError::InvalidDefinedName(msg="defined name missing")
  }
  if !is_builtin_defined_name(defined_name.name) {
    check_defined_name(defined_name.name)
  }
  let scope = normalize_defined_name_scope(defined_name.scope)
  let normalized_scope = if scope != "Workbook" {
    match self.sheet(scope) {
      Some(_) => scope
      None => "Workbook"
    }
  } else {
    scope
  }
  let scope_key = defined_name_scope_key(normalized_scope)
  for existing in self.defined_names {
    if existing.name == defined_name.name &&
      defined_name_scope_key(existing.scope) == scope_key {
      raise XlsxError::DefinedNameDuplicate(name=defined_name.name)
    }
  }
  self.defined_names.push({
    name: defined_name.name,
    refers_to: defined_name.refers_to,
    scope: normalized_scope,
    comment: defined_name.comment,
  })
}

///|
pub fn Workbook::delete_defined_name(
  self : Workbook,
  defined_name : DefinedName,
) -> Unit raise XlsxError {
  let scope_key = defined_name_scope_key(defined_name.scope)
  let updated : Array[DefinedName] = []
  let mut removed = false
  for dn in self.defined_names {
    if dn.name == defined_name.name &&
      defined_name_scope_key(dn.scope) == scope_key {
      removed = true
      continue
    }
    updated.push(dn)
  }
  if !removed {
    raise XlsxError::DefinedNameScope(name=defined_name.name)
  }
  self.defined_names.clear()
  self.defined_names.append(updated[:])
}

///|
pub fn Workbook::get_defined_names(self : Workbook) -> Array[DefinedName] {
  let names : Array[DefinedName] = []
  for dn in self.defined_names {
    names.push(dn)
  }
  names
}

///|
pub fn Workbook::group_sheets(
  self : Workbook,
  sheets : Array[String],
) -> Unit raise XlsxError {
  let active_index = self.active_sheet_index
  let active_name = if active_index >= 0 &&
    active_index < self.sheet_order.length() {
    self.sheet_entry_name(self.sheet_order[active_index])
  } else {
    ""
  }
  let mut contains_active = false
  for name in sheets {
    check_sheet_name(name)
    if sheet_name_equal(name, active_name) {
      contains_active = true
    }
  }
  if !contains_active {
    raise XlsxError::InvalidSheetOperation(
      msg="group worksheet must contain an active worksheet",
    )
  }
  for name in sheets {
    let sheet = match self.sheet(name) {
      Some(value) => value
      None => raise XlsxError::SheetNotFound(name~)
    }
    sheet.ensure_stream_idle()
    if sheet.sheet_views.length() == 0 {
      sheet.sheet_views.push(SheetView::new())
    }
    for view in sheet.sheet_views {
      view.tab_selected = true
    }
  }
}

///|
pub fn Workbook::ungroup_sheets(self : Workbook) -> Unit raise XlsxError {
  let active_index = self.active_sheet_index
  for idx, entry in self.sheet_order {
    if idx == active_index {
      continue
    }
    match entry {
      SheetEntry::Worksheet(sheet_idx) => {
        let sheet = self.sheets[sheet_idx]
        if sheet.sheet_views.length() == 0 {
          continue
        }
        sheet.ensure_stream_idle()
        for view in sheet.sheet_views {
          view.tab_selected = false
        }
      }
      SheetEntry::ChartSheet(_) => ()
    }
  }
}

///|
fn Workbook::adjust_defined_names_for_sheet(
  self : Workbook,
  sheet_name : String,
  adjust_fn : (StringView) -> String? raise XlsxError,
) -> Unit raise XlsxError {
  if self.defined_names.length() == 0 {
    return
  }
  let updated : Array[DefinedName] = []
  for dn in self.defined_names {
    let refers_to = adjust_defined_name_refers_to_for_sheet(
      dn.refers_to,
      sheet_name,
      adjust_fn,
    )
    updated.push({
      name: dn.name,
      refers_to,
      scope: dn.scope,
      comment: dn.comment,
    })
  }
  self.defined_names.clear()
  self.defined_names.append(updated[:])
}

///|
fn clone_strings(values : ArrayView[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_row_dimensions(
  values : Map[Int, RowDimension],
) -> Map[Int, RowDimension] {
  let out : Map[Int, RowDimension] = {}
  for row, dim in values {
    out[row] = dim
  }
  out
}

///|
fn clone_col_dimensions(
  values : Map[Int, ColDimension],
) -> Map[Int, ColDimension] {
  let out : Map[Int, ColDimension] = {}
  for col, dim in values {
    out[col] = dim
  }
  out
}

///|
fn clone_cells(values : ArrayView[Cell]) -> Array[Cell] {
  let out : Array[Cell] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_hyperlinks(values : ArrayView[Hyperlink]) -> Array[Hyperlink] {
  let out : Array[Hyperlink] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_comments(values : ArrayView[Comment]) -> Array[Comment] {
  let out : Array[Comment] = []
  for value in values {
    let paragraph : Array[RichTextRun] = []
    for run in value.paragraph {
      paragraph.push(run)
    }
    out.push({
      cell: value.cell,
      author: value.author,
      text: value.text,
      paragraph,
      width: value.width,
      height: value.height,
    })
  }
  out
}

///|
fn clone_tables(values : ArrayView[Table]) -> Array[Table] {
  let out : Array[Table] = []
  for value in values {
    let columns : Array[String] = []
    for column in value.columns {
      columns.push(column)
    }
    out.push({
      id: 0,
      name: value.name,
      display_name: value.display_name,
      range_ref: value.range_ref,
      columns,
      style_name: value.style_name,
    })
  }
  out
}

///|
fn clone_sparkline_groups(
  values : ArrayView[SparklineGroup],
) -> Array[SparklineGroup] {
  let out : Array[SparklineGroup] = []
  for value in values {
    let sparklines : Array[Sparkline] = []
    for sparkline in value.sparklines {
      sparklines.push(sparkline)
    }
    out.push({ sparkline_type: value.sparkline_type, sparklines })
  }
  out
}

///|
fn clone_pivot_tables(values : ArrayView[PivotTable]) -> Array[PivotTable] {
  let out : Array[PivotTable] = []
  for value in values {
    out.push({
      name: value.name,
      table_id: 0,
      cache_id: 0,
      table_xml: value.table_xml,
      cache_definition_xml: value.cache_definition_xml,
      cache_records_xml: value.cache_records_xml,
    })
  }
  out
}

///|
fn clone_images(values : ArrayView[Image]) -> Array[Image] {
  let out : Array[Image] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_header_footer_images(
  values : ArrayView[HeaderFooterImage],
) -> Array[HeaderFooterImage] {
  let out : Array[HeaderFooterImage] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_charts(values : ArrayView[Chart]) -> Array[Chart] {
  let out : Array[Chart] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_shapes(values : ArrayView[Shape]) -> Array[Shape] {
  let out : Array[Shape] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_form_controls(values : ArrayView[FormControl]) -> Array[FormControl] {
  let out : Array[FormControl] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_slicers(values : ArrayView[Slicer]) -> Array[Slicer] {
  let out : Array[Slicer] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_ignored_errors(
  values : ArrayView[IgnoredError],
) -> Array[IgnoredError] {
  let out : Array[IgnoredError] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_sheet_views(values : ArrayView[SheetView]) -> Array[SheetView] {
  let out : Array[SheetView] = []
  for view in values {
    let selection : Array[Selection] = []
    for item in view.selection {
      selection.push(item)
    }
    let pane = match view.pane {
      Some(value) =>
        Some({
          active_pane: value.active_pane,
          state: value.state,
          top_left_cell: value.top_left_cell,
          x_split: value.x_split,
          y_split: value.y_split,
        })
      None => None
    }
    out.push({
      default_grid_color: view.default_grid_color,
      right_to_left: view.right_to_left,
      show_formulas: view.show_formulas,
      show_grid_lines: view.show_grid_lines,
      show_row_col_headers: view.show_row_col_headers,
      show_ruler: view.show_ruler,
      show_zeros: view.show_zeros,
      top_left_cell: view.top_left_cell,
      view: view.view,
      zoom_scale: view.zoom_scale,
      tab_selected: view.tab_selected,
      workbook_view_id: view.workbook_view_id,
      pane,
      selection,
    })
  }
  out
}

///|
fn clone_worksheet(
  sheet : Worksheet,
  name : String,
  state : SheetState,
) -> Worksheet {
  {
    name,
    sheet_views: clone_sheet_views(sheet.sheet_views),
    dimension_ref: sheet.dimension_ref,
    cells: clone_cells(sheet.cells),
    merged_cells: clone_strings(sheet.merged_cells),
    hyperlinks: clone_hyperlinks(sheet.hyperlinks),
    tables: clone_tables(sheet.tables),
    sparkline_groups: clone_sparkline_groups(sheet.sparkline_groups),
    pivot_tables: clone_pivot_tables(sheet.pivot_tables),
    images: clone_images(sheet.images),
    header_footer_images: clone_header_footer_images(sheet.header_footer_images),
    charts: clone_charts(sheet.charts),
    shapes: clone_shapes(sheet.shapes),
    form_controls: clone_form_controls(sheet.form_controls),
    slicers: clone_slicers(sheet.slicers),
    data_validations: clone_strings(sheet.data_validations),
    conditional_formats: clone_strings(sheet.conditional_formats),
    ignored_errors: clone_ignored_errors(sheet.ignored_errors),
    comments: clone_comments(sheet.comments),
    auto_filter: match sheet.auto_filter {
      Some(filter) => Some(clone_auto_filter(filter))
      None => None
    },
    page_margins: sheet.page_margins,
    page_layout: sheet.page_layout,
    header_footer: sheet.header_footer,
    sheet_protection: sheet.sheet_protection,
    sheet_props: sheet.sheet_props,
    sheet_background: sheet.sheet_background,
    row_breaks: {
      let breaks : Array[PageBreak] = []
      for brk in sheet.row_breaks {
        breaks.push(brk)
      }
      breaks
    },
    col_breaks: {
      let breaks : Array[PageBreak] = []
      for brk in sheet.col_breaks {
        breaks.push(brk)
      }
      breaks
    },
    row_dimensions: clone_row_dimensions(sheet.row_dimensions),
    col_dimensions: clone_col_dimensions(sheet.col_dimensions),
    state,
    stream_state: StreamState::Idle,
    vml_drawing_xml: sheet.vml_drawing_xml,
    vml_drawing_hf_xml: sheet.vml_drawing_hf_xml,
  }
}

///|
pub fn Workbook::row_stream(
  self : Workbook,
  sheet_name : StringView,
) -> RowStream raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  RowStream::new(sheet)
}

///|
pub fn Workbook::add_style(self : Workbook, style : Style) -> Int {
  self.styles.push(style)
  self.styles.length() - 1
}

///|
pub fn Workbook::new_style(self : Workbook, style : Style) -> Int {
  self.add_style(style)
}

///|
fn Workbook::check_style_id(
  self : Workbook,
  style_id : Int,
) -> Unit raise XlsxError {
  if style_id < 0 || style_id >= self.styles.length() {
    raise XlsxError::InvalidStyleId(index=style_id)
  }
}

///|
fn Workbook::check_conditional_style_id(
  self : Workbook,
  style_id : Int,
) -> Unit raise XlsxError {
  if style_id < 0 || style_id >= self.conditional_styles.length() {
    raise XlsxError::InvalidStyleId(index=style_id)
  }
}

///|
pub fn Workbook::get_style(
  self : Workbook,
  style_id : Int,
) -> Style raise XlsxError {
  self.check_style_id(style_id)
  self.styles[style_id]
}

///|
pub fn Workbook::new_conditional_style(self : Workbook, style : Style) -> Int {
  self.conditional_styles.push(style)
  self.conditional_styles.length() - 1
}

///|
pub fn Workbook::get_conditional_style(
  self : Workbook,
  style_id : Int,
) -> Style raise XlsxError {
  self.check_conditional_style_id(style_id)
  self.conditional_styles[style_id]
}

///|
fn format_cell_value_for_workbook(
  styles : ArrayView[Style],
  cell : Cell,
  raw : Bool,
) -> String raise XlsxError {
  if raw {
    return cell.value
  }
  if cell.style_id < 0 || cell.style_id >= styles.length() {
    raise XlsxError::InvalidStyleId(index=cell.style_id)
  }
  format_cell_value(cell.value_type, cell.value, Some(styles[cell.style_id]))
}

///|
fn normalize_cell_float_value(
  value : Double,
  precision : Int,
  bit_size : Int,
) -> Double {
  let normalized = if bit_size == 32 {
    Float::from_double(value).to_double()
  } else {
    value
  }
  if precision < 0 {
    normalized
  } else {
    let factor = @math.pow(10.0, Double::from_int(precision))
    if factor == 0.0 {
      normalized
    } else {
      (normalized * factor).round() / factor
    }
  }
}

///|
pub fn Workbook::set_cell(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell(reference, value)
}

///|
pub fn Workbook::set_cell_value(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : CellValue,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_value(reference, value)
}

///|
pub fn Workbook::set_cell_bool(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : Bool,
) -> Unit raise XlsxError {
  self.set_cell_value(sheet_name, reference, CellValue::Bool(value))
}

///|
pub fn Workbook::set_cell_int(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : Int,
) -> Unit raise XlsxError {
  self.set_cell_value(
    sheet_name,
    reference,
    CellValue::Numeric(Double::from_int(value)),
  )
}

///|
pub fn Workbook::set_cell_uint(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : UInt,
) -> Unit raise XlsxError {
  self.set_cell_value(
    sheet_name,
    reference,
    CellValue::Numeric(Double::convert_uint(value)),
  )
}

///|
pub fn Workbook::set_cell_float(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : Double,
  precision? : Int = -1,
  bit_size? : Int = 64,
) -> Unit raise XlsxError {
  let normalized = normalize_cell_float_value(value, precision, bit_size)
  self.set_cell_value(sheet_name, reference, CellValue::Numeric(normalized))
}

///|
pub fn Workbook::set_cell_str(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : String,
) -> Unit raise XlsxError {
  self.set_cell(sheet_name, reference, value)
}

///|
pub fn Workbook::set_cell_default(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : String,
) -> Unit raise XlsxError {
  self.set_cell(sheet_name, reference, value)
}

///|
pub fn Workbook::set_cell_rich_text(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  runs : ArrayView[RichTextRun],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_rich_text(reference, runs)
}

///|
pub fn Workbook::set_cell_hyperlink(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  target : String,
  link_type : HyperlinkType,
  display? : String = "",
  tooltip? : String = "",
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_hyperlink(reference, target, link_type, display~, tooltip~)
}

///|
pub fn Workbook::remove_cell_hyperlink(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.remove_cell_hyperlink(reference)
}

///|
pub fn Workbook::get_cell(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell(reference)
}

///|
pub fn Workbook::get_cell_rich_text(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Array[RichTextRun]? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_rich_text(reference)
}

///|
pub fn Workbook::get_cell_hyperlink(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Hyperlink? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_hyperlink(reference)
}

///|
pub fn Workbook::get_cell_value_raw(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> CellValue? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_value_raw(reference)
}

///|
pub fn Workbook::get_cell_type(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> CellValueType? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_type(reference)
}

///|
pub fn Workbook::get_cell_value(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
  raw? : Bool = false,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (row, col) = cell_ref_to_rc(reference)
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      return Some(format_cell_value_for_workbook(self.styles, cell, raw))
    }
  }
  None
}

///|
pub fn Workbook::calc_cell_value(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
  raw? : Bool = false,
) -> String raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  let ctx = CalcContext::new()
  let value = resolve_cell_value(self, sheet.name(), canonical, ctx)
  let (value_type, raw_value) = formula_value_to_cell(value)
  if raw {
    return raw_value
  }
  let mut style_id = 0
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      style_id = cell.style_id
      break
    }
  }
  if style_id < 0 || style_id >= self.styles.length() {
    raise XlsxError::InvalidStyleId(index=style_id)
  }
  format_cell_value(value_type, raw_value, Some(self.styles[style_id]))
}

///|
pub fn Workbook::calc_cell_value_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  raw? : Bool = false,
) -> String raise XlsxError {
  let reference = cell_ref_from(row, col)
  self.calc_cell_value(sheet_name, reference, raw~)
}

///|
pub fn Workbook::set_cell_formula(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_formula(reference, formula, value~)
}

///|
pub fn Workbook::get_cell_formula(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_formula(reference)
}

///|
pub fn Workbook::set_cell_style(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  style_id : Int,
) -> Unit raise XlsxError {
  self.check_style_id(style_id)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_style(reference, style_id)
}

///|
pub fn Workbook::get_cell_style(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Int? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_style(reference)
}

///|
pub fn Workbook::add_image(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  data : Bytes,
  extension : String,
  content_type : String,
  offset_x? : Int = 0,
  offset_y? : Int = 0,
  scale_x? : Double = 1.0,
  scale_y? : Double = 1.0,
  hyperlink? : String = "",
  hyperlink_type? : HyperlinkType = HyperlinkType::Unset,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_image(
    reference,
    data,
    extension,
    content_type,
    offset_x~,
    offset_y~,
    scale_x~,
    scale_y~,
    hyperlink~,
    hyperlink_type~,
  )
}

///|
pub fn Workbook::add_picture_from_bytes(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  data : Bytes,
  extension : String,
  offset_x? : Int = 0,
  offset_y? : Int = 0,
  scale_x? : Double = 1.0,
  scale_y? : Double = 1.0,
  hyperlink? : String = "",
  hyperlink_type? : HyperlinkType = HyperlinkType::Unset,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_picture_from_bytes(
    reference,
    data,
    extension,
    offset_x~,
    offset_y~,
    scale_x~,
    scale_y~,
    hyperlink~,
    hyperlink_type~,
  )
}

///|
pub fn Workbook::add_header_footer_image(
  self : Workbook,
  sheet_name : StringView,
  options : HeaderFooterImageOptions,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_header_footer_image(options)
}

///|
pub fn Workbook::get_pictures(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Array[Image] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_pictures(cell)
}

///|
pub fn Workbook::get_picture_cells(
  self : Workbook,
  sheet_name : StringView,
) -> Array[String] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_picture_cells()
}

///|
pub fn Workbook::delete_picture(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.delete_picture(cell)
}

///|
pub fn Workbook::add_chart(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_chart(reference, xml)
}

///|
pub fn Workbook::delete_chart(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.delete_chart(cell)
}

///|
pub fn Workbook::add_shape(
  self : Workbook,
  sheet_name : StringView,
  shape : Shape,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_shape(shape)
}

///|
pub fn Workbook::add_vml_drawing_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_vml_drawing_xml(xml)
}

///|
pub fn Workbook::add_vml_drawing_hf_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_vml_drawing_hf_xml(xml)
}

///|
pub fn Workbook::add_form_control(
  self : Workbook,
  sheet_name : StringView,
  control : FormControl,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_form_control(control)
}

///|
pub fn Workbook::get_form_controls(
  self : Workbook,
  sheet_name : StringView,
) -> Array[FormControl] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let out : Array[FormControl] = []
  for control in sheet.get_form_controls() {
    out.push(control)
  }
  out
}

///|
pub fn Workbook::delete_form_control(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.delete_form_control(cell)
}

///|
pub fn Workbook::add_slicer(
  self : Workbook,
  sheet_name : StringView,
  slicer : Slicer,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_slicer(slicer)
}

///|
pub fn Workbook::get_slicers(
  self : Workbook,
  sheet_name : StringView,
) -> Array[Slicer] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let out : Array[Slicer] = []
  for slicer in sheet.get_slicers() {
    out.push(slicer)
  }
  out
}

///|
pub fn Workbook::delete_slicer(
  self : Workbook,
  name : StringView,
) -> Unit raise XlsxError {
  let target = name.to_string()
  let mut removed = false
  for sheet in self.sheets {
    let mut found = false
    for slicer in sheet.get_slicers() {
      if slicer.name == target {
        found = true
        break
      }
    }
    if found {
      sheet.delete_slicer(target)
      removed = true
      break
    }
  }
  if !removed {
    raise XlsxError::InvalidSheetOperation(msg="slicer not found")
  }
}

///|
pub fn Workbook::add_comment(
  self : Workbook,
  sheet_name : StringView,
  comment : Comment,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_comment(comment)
}

///|
pub fn Workbook::delete_comment(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.delete_comment(cell)
}

///|
pub fn Workbook::get_comments(
  self : Workbook,
  sheet_name : StringView,
) -> Array[Comment] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let comments : Array[Comment] = []
  for comment in sheet.comments() {
    comments.push(comment)
  }
  comments
}

///|
pub fn Workbook::set_auto_filter(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  options : ArrayView[AutoFilterOption],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_auto_filter(range_ref, options)
}

///|
pub fn Workbook::clear_auto_filter(
  self : Workbook,
  sheet_name : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.clear_auto_filter()
}

///|
pub fn Workbook::get_auto_filter(
  self : Workbook,
  sheet_name : StringView,
) -> AutoFilter? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.auto_filter()
}

///|
pub fn Workbook::add_data_validation_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_data_validation_xml(xml)
}

///|
pub fn Workbook::add_data_validation(
  self : Workbook,
  sheet_name : StringView,
  dv : DataValidation,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_data_validation(dv)
}

///|
pub fn Workbook::add_data_validation_list(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  values : ArrayView[String],
  allow_blank? : Bool = true,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_data_validation_list(range_ref, values, allow_blank~)
}

///|
pub fn Workbook::get_data_validations(
  self : Workbook,
  sheet_name : StringView,
) -> Array[DataValidation] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_data_validations()
}

///|
pub fn Workbook::delete_data_validation(
  self : Workbook,
  sheet_name : StringView,
  sqrefs? : Array[String] = [],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.delete_data_validation(sqrefs~)
}

///|
pub fn Workbook::add_ignored_errors(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  error_type : IgnoredErrorType,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_ignored_errors(range_ref, error_type)
}

///|
pub fn Workbook::add_conditional_format_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_conditional_format_xml(xml)
}

///|
pub fn Workbook::set_conditional_format(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  options : ArrayView[ConditionalFormatOptions],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_conditional_format(range_ref, options)
}

///|
pub fn Workbook::get_conditional_formats(
  self : Workbook,
  sheet_name : StringView,
) -> Map[String, Array[ConditionalFormatOptions]] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_conditional_formats()
}

///|
pub fn Workbook::unset_conditional_format(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.unset_conditional_format(range_ref)
}

///|
pub fn Workbook::merge_cells(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.merge_cells(range_ref)
}

///|
pub fn Workbook::merge_cell(
  self : Workbook,
  sheet_name : StringView,
  top_left : StringView,
  bottom_right : StringView,
) -> Unit raise XlsxError {
  self.merge_cells(
    sheet_name,
    "\{top_left.to_string()}:\{bottom_right.to_string()}",
  )
}

///|
pub fn Workbook::unmerge_cells(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.unmerge_cells(range_ref)
}

///|
pub fn Workbook::unmerge_cell(
  self : Workbook,
  sheet_name : StringView,
  top_left : StringView,
  bottom_right : StringView,
) -> Unit raise XlsxError {
  self.unmerge_cells(
    sheet_name,
    "\{top_left.to_string()}:\{bottom_right.to_string()}",
  )
}

///|
pub fn Workbook::get_merge_cells(
  self : Workbook,
  sheet_name : StringView,
) -> Array[String] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let merged : Array[String] = []
  for range_ref in sheet.merged_cells() {
    merged.push(range_ref)
  }
  merged
}

///|
pub fn Workbook::add_table(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  name : String,
  columns : ArrayView[String],
  display_name? : String = "",
  style_name? : String = "TableStyleMedium9",
) -> Table raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_table(range_ref, name, columns, display_name~, style_name~)
}

///|
pub fn Workbook::get_tables(
  self : Workbook,
  sheet_name : StringView,
) -> Array[Table] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let tables : Array[Table] = []
  for table in sheet.tables() {
    tables.push(table)
  }
  tables
}

///|
pub fn Workbook::delete_table(
  self : Workbook,
  name : StringView,
) -> Unit raise XlsxError {
  let target = name.to_string()
  for sheet in self.sheets {
    let mut found = false
    for table in sheet.tables {
      if table.name == target || table.display_name == target {
        found = true
        break
      }
    }
    if found {
      sheet.delete_table(target)
      return
    }
  }
  raise XlsxError::TableNotFound(name=target)
}

///|
pub fn Workbook::add_sparkline(
  self : Workbook,
  sheet_name : StringView,
  location : String,
  range_ref : String,
  sparkline_type? : SparklineType = SparklineType::Line,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_sparkline(location, range_ref, sparkline_type~)
}

///|
pub fn Workbook::add_sparkline_group(
  self : Workbook,
  sheet_name : StringView,
  locations : ArrayView[String],
  ranges : ArrayView[String],
  sparkline_type? : SparklineType = SparklineType::Line,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_sparkline_group(locations, ranges, sparkline_type~)
}

///|
pub fn Workbook::add_pivot_table_xml(
  self : Workbook,
  sheet_name : StringView,
  table_xml : String,
  cache_definition_xml : String,
  cache_records_xml? : String = "",
  name? : String = "",
) -> PivotTable raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_pivot_table_xml(
    table_xml,
    cache_definition_xml,
    cache_records_xml~,
    name~,
  )
}

///|
pub fn Workbook::add_pivot_table(
  self : Workbook,
  sheet_name : StringView,
  table_xml : String,
  cache_definition_xml : String,
  cache_records_xml? : String = "",
  name? : String = "",
) -> PivotTable raise XlsxError {
  self.add_pivot_table_xml(
    sheet_name,
    table_xml,
    cache_definition_xml,
    cache_records_xml~,
    name~,
  )
}

///|
pub fn Workbook::get_pivot_tables(
  self : Workbook,
  sheet_name : StringView,
) -> Array[PivotTable] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  clone_pivot_tables(sheet.pivot_tables())
}

///|
pub fn Workbook::delete_pivot_table(
  self : Workbook,
  sheet_name : StringView,
  name : StringView,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.delete_pivot_table(name)
}

///|
pub fn Workbook::set_cell_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  value : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_rc(row, col, value)
}

///|
pub fn Workbook::set_cell_value_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  value : CellValue,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_value_rc(row, col, value)
}

///|
pub fn Workbook::get_cell_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_rc(row, col)
}

///|
pub fn Workbook::get_cell_value_raw_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> CellValue? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_value_raw_rc(row, col)
}

///|
pub fn Workbook::get_cell_value_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  raw? : Bool = false,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      return Some(format_cell_value_for_workbook(self.styles, cell, raw))
    }
  }
  None
}

///|
pub fn Workbook::set_cell_style_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.check_style_id(style_id)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_style_rc(row, col, style_id)
}

///|
pub fn Workbook::get_cell_style_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> Int? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_style_rc(row, col)
}

///|
pub fn Workbook::set_cell_formula_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_formula_rc(row, col, formula, value~)
}

///|
pub fn Workbook::set_row(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row(row, values)
}

///|
pub fn Workbook::get_row(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Array[String] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_row(row)
}

///|
pub fn Workbook::set_col(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col(col, values)
}

///|
pub fn Workbook::get_col(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Array[String] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_col(col)
}

///|
pub fn Workbook::set_row_height(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  height : Double,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row_height(row, height)
}

///|
pub fn Workbook::get_row_height(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Double? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_row_height(row)
}

///|
pub fn Workbook::set_row_visible(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row_visible(row, visible)
}

///|
pub fn Workbook::row_visible(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Bool raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.row_visible(row)
}

///|
pub fn Workbook::set_row_outline_level(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  level : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row_outline_level(row, level)
}

///|
pub fn Workbook::row_outline_level(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Int raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.row_outline_level(row)
}

///|
pub fn Workbook::set_row_style(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.check_style_id(style_id)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row_style(row, style_id)
}

///|
pub fn Workbook::get_row_style(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Int? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_row_style(row)
}

///|
pub fn Workbook::set_col_width(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  width : Double,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col_width(col, width)
}

///|
pub fn Workbook::get_col_width(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Double? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_col_width(col)
}

///|
pub fn Workbook::set_col_visible(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col_visible(col, visible)
}

///|
pub fn Workbook::col_visible(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Bool raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.col_visible(col)
}

///|
pub fn Workbook::set_col_outline_level(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  level : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col_outline_level(col, level)
}

///|
pub fn Workbook::col_outline_level(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Int raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.col_outline_level(col)
}

///|
pub fn Workbook::set_col_style(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.check_style_id(style_id)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col_style(col, style_id)
}

///|
pub fn Workbook::get_col_style(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Int? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_col_style(col)
}

///|
pub fn Workbook::insert_rows(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.insert_rows(row, count)
  self.adjust_defined_names_for_sheet(sheet.name(), fn(
    ref_text : StringView,
  ) -> String? raise XlsxError {
    adjust_ref_after_row_insert(ref_text, row, count)
  })
}

///|
pub fn Workbook::remove_rows(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.remove_rows(row, count)
  self.adjust_defined_names_for_sheet(sheet.name(), fn(
    ref_text : StringView,
  ) -> String? raise XlsxError {
    adjust_ref_after_row_remove(ref_text, row, count)
  })
}

///|
/// Remove a single row (1-based) and shift rows upward.
pub fn Workbook::remove_row(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Unit raise XlsxError {
  self.remove_rows(sheet_name, row, 1)
}

///|
pub fn Workbook::insert_cols(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.insert_cols(col, count)
  self.adjust_defined_names_for_sheet(sheet.name(), fn(
    ref_text : StringView,
  ) -> String? raise XlsxError {
    adjust_ref_after_col_insert(ref_text, col, count)
  })
}

///|
pub fn Workbook::remove_cols(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.remove_cols(col, count)
  self.adjust_defined_names_for_sheet(sheet.name(), fn(
    ref_text : StringView,
  ) -> String? raise XlsxError {
    adjust_ref_after_col_remove(ref_text, col, count)
  })
}

///|
/// Remove a single column (1-based) and shift columns left.
pub fn Workbook::remove_col(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Unit raise XlsxError {
  self.remove_cols(sheet_name, col, 1)
}

///|
pub fn Workbook::duplicate_row(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Unit raise XlsxError {
  self.duplicate_row_to(sheet_name, row, row + 1)
}

///|
pub fn Workbook::duplicate_row_to(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  target_row : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.duplicate_row_to(row, target_row)
  self.adjust_defined_names_for_sheet(sheet.name(), fn(
    ref_text : StringView,
  ) -> String? raise XlsxError {
    adjust_ref_after_row_insert(ref_text, target_row, 1)
  })
}
