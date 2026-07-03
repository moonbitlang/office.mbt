///|
pub fn Workbook::add_sheet(
  self : Workbook,
  name : String,
) -> Worksheet raise XlsxError {
  check_sheet_name(name)
  match self.sheet_entry(name) {
    Some(_) => raise SheetAlreadyExists(name~)
    None => ()
  }
  let sheet = Worksheet::new(name)
  self.sheets.push(sheet)
  self.sheet_order.push(Worksheet(self.sheets.length() - 1))
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
    Some(_) => raise SheetAlreadyExists(name~)
    None => ()
  }
  let sheet = ChartSheet::new(name, chart_xml)
  self.chart_sheets.push(sheet)
  self.sheet_order.push(ChartSheet(self.chart_sheets.length() - 1))
  if self.sheet_order.length() == 1 {
    self.active_sheet_index = 0
  }
  sheet
}

///|
pub fn Workbook::add_chart_sheet_with_options(
  self : Workbook,
  name : String,
  opts : ChartOptions,
) -> ChartSheet raise XlsxError {
  let xml = chart_options_to_xml(opts)
  self.add_chart_sheet(name, xml)
}

///|
pub fn Workbook::new_stream_writer(
  self : Workbook,
  sheet_name : StringView,
) -> StreamWriter raise XlsxError {
  check_sheet_name(sheet_name)
  let sheet_id = match self.sheet_entry_index(sheet_name) {
    Some(value) => value + 1
    None => raise SheetNotFound(name=sheet_name.to_string())
  }
  let sheet = self.require_sheet(sheet_name)
  if sheet.stream_state != Idle {
    raise StreamModeConflict(msg="stream writer already active")
  }
  if sheet.cells().length() > 0 {
    raise StreamModeConflict(msg="worksheet already has data")
  }
  sheet.stream_state = Writing
  let date1904_now = () => {
    match self.get_workbook_props().date_1904 {
      Some(flag) => flag
      None => false
    }
  }
  StreamWriter::new(sheet, sheet_id, self.styles, date1904_now~)
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
fn Workbook::require_sheet(
  self : Workbook,
  sheet_name : StringView,
) -> Worksheet raise XlsxError {
  check_sheet_name(sheet_name)
  match self.sheet(sheet_name) {
    Some(value) => value
    None => raise SheetNotFound(name=sheet_name.to_string())
  }
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
    None => raise SheetNotFound(name=name.to_string())
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
fn Workbook::conditional_styles(self : Workbook) -> ArrayView[Style] {
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
    raise InvalidWorkbookProperty(msg="custom property name missing")
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
    raise InvalidVBAProject(msg="unsupported vba project")
  }
  self.vba_project = Some(data)
}

///|
fn Workbook::workbook_props(self : Workbook) -> WorkbookPropsOptions {
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
fn Workbook::calc_props(self : Workbook) -> CalcPropsOptions {
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
fn Workbook::default_font(self : Workbook) -> String {
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
pub fn Workbook::set_zip_writer(
  self : Workbook,
  writer : (@zip.Archive) -> Bytes raise,
) -> Unit {
  let io_context = workbook_io_context(self)
  self.set_io_context({
    file_path: io_context.file_path,
    zip_writer: Some(writer),
    charset_transcoder: io_context.charset_transcoder,
  })
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
    None => raise InvalidWorkbookProtection(msg="workbook not protected")
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
  if source.to_string() == target {
    return
  }
  let entry = match self.sheet_entry(source) {
    Some(value) => value
    None => raise SheetNotFound(name=source.to_string())
  }
  let old_name = self.sheet_entry_name(entry)
  if !sheet_name_equal(old_name, target) {
    match self.sheet_entry(target) {
      Some(_) => raise SheetAlreadyExists(name=target)
      None => ()
    }
  }
  match entry {
    Worksheet(idx) => self.sheets[idx].name = target
    ChartSheet(idx) => self.chart_sheets[idx].name = target
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
  let order_index = match self.sheet_entry_index(name) {
    Some(value) => value
    None => return ()
  }
  let entry = self.sheet_order[order_index]
  let deleted_name = self.sheet_entry_name(entry)
  if self.sheet_order.length() <= 1 {
    return ()
  }
  ignore(self.sheet_order.remove(order_index))
  match entry {
    Worksheet(idx) => {
      ignore(self.sheets.remove(idx))
      let updated : Array[SheetEntry] = []
      for item in self.sheet_order {
        match item {
          Worksheet(value) =>
            if value > idx {
              updated.push(Worksheet(value - 1))
            } else {
              updated.push(item)
            }
          ChartSheet(_) => updated.push(item)
        }
      }
      self.sheet_order.clear()
      self.sheet_order.append(updated[:])
    }
    ChartSheet(idx) => {
      ignore(self.chart_sheets.remove(idx))
      let updated : Array[SheetEntry] = []
      for item in self.sheet_order {
        match item {
          ChartSheet(value) =>
            if value > idx {
              updated.push(ChartSheet(value - 1))
            } else {
              updated.push(item)
            }
          Worksheet(_) => updated.push(item)
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
    raise InvalidSheetIndex(index=to_index)
  }
  let from_entry = self.sheet_order[from_index]
  let to_entry = self.sheet_order[to_index]
  match (from_entry, to_entry) {
    (Worksheet(from_sheet_idx), Worksheet(to_sheet_idx)) => {
      let from_sheet = self.sheets[from_sheet_idx]
      let to_sheet = self.sheets[to_sheet_idx]
      let cloned = clone_worksheet(
        from_sheet,
        to_sheet.name(),
        to_sheet.state(),
      )
      self.sheets[to_sheet_idx] = cloned
    }
    _ => raise InvalidSheetIndex(index=to_index)
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
  let index = self.sheet_index(name)
  let entry = self.sheet_order[index]
  let state = if visible {
    Visible
  } else if very_hidden {
    VeryHidden
  } else {
    Hidden
  }
  if state != Visible {
    let mut visible_count = 0
    for i, order_entry in self.sheet_order {
      let sheet_state = if i == index {
        state
      } else {
        self.sheet_entry_state(order_entry)
      }
      if sheet_state == Visible {
        visible_count = visible_count + 1
      }
    }
    if visible_count == 0 {
      raise InvalidSheetOperation(
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
    Some(entry) => self.sheet_entry_state(entry) == Visible
    None => raise SheetNotFound(name=name.to_string())
  }
}

///|
pub fn Workbook::set_page_margins(
  self : Workbook,
  sheet_name : StringView,
  options : PageLayoutMarginsOptions?,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_page_margins(options)
}

///|
pub fn Workbook::get_page_margins(
  self : Workbook,
  sheet_name : StringView,
) -> PageLayoutMarginsOptions raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.page_margins()
}

///|
pub fn Workbook::set_page_layout(
  self : Workbook,
  sheet_name : StringView,
  options : PageLayoutOptions?,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_page_layout(options)
}

///|
pub fn Workbook::get_page_layout(
  self : Workbook,
  sheet_name : StringView,
) -> PageLayoutOptions raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.page_layout()
}

///|
pub fn Workbook::set_header_footer(
  self : Workbook,
  sheet_name : StringView,
  options : HeaderFooterOptions?,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_header_footer(options)
}

///|
pub fn Workbook::set_sheet_props(
  self : Workbook,
  sheet_name : StringView,
  options : SheetPropsOptions?,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_sheet_props(options)
}

///|
pub fn Workbook::get_header_footer(
  self : Workbook,
  sheet_name : StringView,
) -> HeaderFooterOptions? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.header_footer()
}

///|
pub fn Workbook::get_header_footer_images(
  self : Workbook,
  sheet_name : StringView,
) -> Array[HeaderFooterImageOptions] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_header_footer_images()
}

///|
pub fn Workbook::get_sheet_props(
  self : Workbook,
  sheet_name : StringView,
) -> SheetPropsOptions raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.sheet_props()
}

///|
pub fn Workbook::set_sheet_view(
  self : Workbook,
  sheet_name : StringView,
  view_index : Int,
  options : SheetViewOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_sheet_view(view_index, options)
}

///|
pub fn Workbook::get_sheet_view(
  self : Workbook,
  sheet_name : StringView,
  view_index : Int,
) -> SheetViewOptions raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_sheet_view(view_index)
}

///|
pub fn Workbook::set_panes(
  self : Workbook,
  sheet_name : StringView,
  panes : Panes,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_panes(panes)
}

///|
pub fn Workbook::get_panes(
  self : Workbook,
  sheet_name : StringView,
) -> Panes raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_panes()
}

///|
pub fn Workbook::set_sheet_dimension(
  self : Workbook,
  sheet_name : StringView,
  range_ref : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_sheet_dimension(range_ref)
}

///|
pub fn Workbook::get_sheet_dimension(
  self : Workbook,
  sheet_name : StringView,
) -> String raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  sheet.protect_sheet(options)
}

///|
pub fn Workbook::unprotect_sheet(
  self : Workbook,
  sheet_name : StringView,
  password? : String = "",
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.unprotect_sheet(password~)
}

///|
pub fn Workbook::get_sheet_protection(
  self : Workbook,
  sheet_name : StringView,
) -> SheetProtectionOptions raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_sheet_protection()
}

///|
pub fn Workbook::set_sheet_background(
  self : Workbook,
  sheet_name : StringView,
  data : Bytes,
  extension : String,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_sheet_background(data, extension)
}

///|
pub fn Workbook::clear_sheet_background(
  self : Workbook,
  sheet_name : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.clear_sheet_background()
}

///|
pub fn Workbook::insert_page_break(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.insert_page_break(cell)
}

///|
pub fn Workbook::remove_page_break(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.remove_page_break(cell)
}

///|
pub fn Workbook::set_defined_name(
  self : Workbook,
  defined_name : DefinedName,
) -> Unit raise XlsxError {
  if defined_name.name == "" || defined_name.refers_to == "" {
    raise InvalidDefinedName(msg="defined name missing")
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
      raise DefinedNameDuplicate(name=defined_name.name)
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
    raise DefinedNameScope(name=defined_name.name)
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
    raise InvalidSheetOperation(
      msg="group worksheet must contain an active worksheet",
    )
  }
  for name in sheets {
    let sheet = match self.sheet(name) {
      Some(value) => value
      None => raise SheetNotFound(name~)
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
      Worksheet(sheet_idx) => {
        let sheet = self.sheets[sheet_idx]
        if sheet.sheet_views.length() == 0 {
          continue
        }
        sheet.ensure_stream_idle()
        for view in sheet.sheet_views {
          view.tab_selected = false
        }
      }
      ChartSheet(_) => ()
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
      author_id: value.author_id,
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
      range: value.range_ref,
      range_ref: value.range_ref,
      columns,
      style_name: value.style_name,
      show_first_column: value.show_first_column,
      show_last_column: value.show_last_column,
      show_row_stripes: value.show_row_stripes,
      show_column_stripes: value.show_column_stripes,
      show_header_row: value.show_header_row,
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
    out.push({
      sparkline_type: value.sparkline_type,
      sparklines,
      options: value.options,
    })
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
fn clone_x14_data_bars(
  values : Map[String, X14DataBarProps],
) -> Map[String, X14DataBarProps] {
  let out : Map[String, X14DataBarProps] = {}
  for key, value in values {
    out[key] = value
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
    cell_index: {},
    cell_index_valid: false,
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
    x14_data_bars: clone_x14_data_bars(sheet.x14_data_bars),
    unknown_ext_blocks: clone_strings(sheet.unknown_ext_blocks),
    x14_cf_rule_id_counter: sheet.x14_cf_rule_id_counter,
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
    stream_state: Idle,
    vml_drawing_xml: sheet.vml_drawing_xml,
    vml_drawing_hf_xml: sheet.vml_drawing_hf_xml,
  }
}

///|
pub fn Workbook::row_stream(
  self : Workbook,
  sheet_name : StringView,
) -> RowStream raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
    raise InvalidStyleId(index=style_id)
  }
}

///|
fn Workbook::check_conditional_style_id(
  self : Workbook,
  style_id : Int,
) -> Unit raise XlsxError {
  if style_id < 0 || style_id >= self.conditional_styles.length() {
    raise InvalidStyleId(index=style_id)
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
  options : Options,
) -> String raise XlsxError {
  if raw || options.raw_cell_value {
    return cell.value
  }
  if cell.style_id < 0 || cell.style_id >= styles.length() {
    raise InvalidStyleId(index=cell.style_id)
  }
  format_cell_value(
    cell.value_type,
    cell.value,
    Some(styles[cell.style_id]),
    options,
  )
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
    (normalized * factor).round() / factor
  }
}

///|
pub fn Workbook::set_cell(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : String,
) -> Unit raise XlsxError {
  check_sheet_name(sheet_name)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None =>
      match self.sheet_entry(sheet_name) {
        Some(ChartSheet(_)) =>
          raise InvalidSheetOperation(
            msg="sheet \{sheet_name.to_string()} is not a worksheet",
          )
        _ => raise SheetNotFound(name=sheet_name.to_string())
      }
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
  check_sheet_name(sheet_name)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None =>
      match self.sheet_entry(sheet_name) {
        Some(ChartSheet(_)) =>
          raise InvalidSheetOperation(
            msg="sheet \{sheet_name.to_string()} is not a worksheet",
          )
        _ => raise SheetNotFound(name=sheet_name.to_string())
      }
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
  self.set_cell_value(sheet_name, reference, Bool(value))
}

///|
pub fn Workbook::set_cell_int(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : Int,
) -> Unit raise XlsxError {
  self.set_cell_value(sheet_name, reference, Numeric(Double::from_int(value)))
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
    Numeric(Double::convert_uint(value)),
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
  self.set_cell_value(sheet_name, reference, Numeric(normalized))
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
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  sheet.set_cell_hyperlink(reference, target, link_type, display~, tooltip~)
}

///|
pub fn Workbook::set_cell_hyperlink_opts(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  target : String,
  link_type : HyperlinkType,
  opts? : HyperlinkOpts = HyperlinkOpts::new(),
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_cell_hyperlink_opts(reference, target, link_type, opts~)
}

///|
pub fn Workbook::set_cell_hyper_link(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  target : String,
  link_type : HyperlinkType,
  display? : String = "",
  tooltip? : String = "",
) -> Unit raise XlsxError {
  self.set_cell_hyperlink(
    sheet_name,
    reference,
    target,
    link_type,
    display~,
    tooltip~,
  )
}

///|
pub fn Workbook::remove_cell_hyperlink(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.remove_cell_hyperlink(reference)
}

///|
pub fn Workbook::get_cell(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> String? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_cell(reference)
}

///|
pub fn Workbook::get_cell_rich_text(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Array[RichTextRun]? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_cell_rich_text(reference)
}

///|
pub fn Workbook::get_cell_hyperlink(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Hyperlink? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_cell_hyperlink(reference)
}

///|
pub fn Workbook::get_cell_hyper_link(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Hyperlink? raise XlsxError {
  self.get_cell_hyperlink(sheet_name, reference)
}

///|
pub fn Workbook::get_hyperlink_cells(
  self : Workbook,
  sheet_name : StringView,
  link_type? : HyperlinkType,
) -> Array[String] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_hyperlink_cells(link_type?)
}

///|
pub fn Workbook::get_hyper_link_cells(
  self : Workbook,
  sheet_name : StringView,
  link_type? : HyperlinkType,
) -> Array[String] raise XlsxError {
  self.get_hyperlink_cells(sheet_name, link_type?)
}

///|
pub fn Workbook::get_cell_value_raw(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> CellValue? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_cell_value_raw(reference)
}

///|
pub fn Workbook::get_cell_type(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> CellValueType? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_cell_type(reference)
}

///|
pub fn Workbook::get_cell_value(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
  raw? : Bool = false,
  options? : Options,
) -> String? raise XlsxError {
  check_sheet_name(sheet_name)
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise SheetNotFound(name=sheet_name.to_string())
  }
  let (row, col) = cell_ref_to_rc(reference)
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      return Some(
        format_cell_value_for_workbook(self.styles, cell, raw, resolved_options),
      )
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
  options? : Options,
) -> String raise XlsxError {
  check_sheet_name(sheet_name)
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise SheetNotFound(name=sheet_name.to_string())
  }
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  let ctx = CalcContext::new()
  let value = resolve_cell_value(self, sheet.name(), canonical, ctx)
  let (value_type, raw_value) = formula_value_to_cell(value)
  if raw || resolved_options.raw_cell_value {
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
    raise InvalidStyleId(index=style_id)
  }
  format_cell_value(
    value_type,
    raw_value,
    Some(self.styles[style_id]),
    resolved_options,
  )
}

///|
pub fn Workbook::calc_cell_value_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  raw? : Bool = false,
  options? : Options,
) -> String raise XlsxError {
  let reference = cell_ref_from(row, col)
  match options {
    Some(value) =>
      self.calc_cell_value(sheet_name, reference, raw~, options=value)
    None => self.calc_cell_value(sheet_name, reference, raw~)
  }
}

///|
pub fn Workbook::set_cell_formula(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_cell_formula(reference, formula, value~)
}

///|
pub fn Workbook::set_cell_formula_opts(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  formula : String,
  opts? : FormulaOpts = FormulaOpts::new(),
  value? : String = "",
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_cell_formula_opts(reference, formula, opts~, value~)
}

///|
pub fn Workbook::get_cell_formula(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> String? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_cell_formula(reference)
}

///|
pub fn Workbook::set_cell_style(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  style_id : Int,
) -> Unit raise XlsxError {
  check_sheet_name(sheet_name)
  self.check_style_id(style_id)
  let sheet = self.require_sheet(sheet_name)
  sheet.set_cell_style(reference, style_id)
}

///|
pub fn Workbook::get_cell_style(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Int? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  hyperlink_type? : HyperlinkType = Unset,
  name? : String = "",
  alt_text? : String = "",
  lock_aspect_ratio? : Bool = false,
  auto_fit? : Bool = false,
  auto_fit_ignore_aspect? : Bool = false,
  print_object? : Bool = true,
  locked? : Bool = true,
  positioning? : PicturePositioning = OneCell,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
    name~,
    alt_text~,
    lock_aspect_ratio~,
    auto_fit~,
    auto_fit_ignore_aspect~,
    print_object~,
    locked~,
    positioning~,
  )
}

///|
pub fn Workbook::add_image_with_options(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  data : Bytes,
  extension : String,
  content_type : String,
  options : GraphicOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  let offset_x = match options.offset_x {
    Some(value) => value
    None => 0
  }
  let offset_y = match options.offset_y {
    Some(value) => value
    None => 0
  }
  let scale_x = match options.scale_x {
    Some(value) => value
    None => 1.0
  }
  let scale_y = match options.scale_y {
    Some(value) => value
    None => 1.0
  }
  let hyperlink = match options.hyperlink {
    Some(value) => value
    None => ""
  }
  let hyperlink_type = match options.hyperlink_type {
    Some(value) => value
    None => Unset
  }
  let name = match options.name {
    Some(value) => value
    None => ""
  }
  let alt_text = match options.alt_text {
    Some(value) => value
    None => ""
  }
  let lock_aspect_ratio = match options.lock_aspect_ratio {
    Some(value) => value
    None => false
  }
  let auto_fit = match options.auto_fit {
    Some(value) => value
    None => false
  }
  let auto_fit_ignore_aspect = match options.auto_fit_ignore_aspect {
    Some(value) => value
    None => false
  }
  let print_object = match options.print_object {
    Some(value) => value
    None => true
  }
  let locked = match options.locked {
    Some(value) => value
    None => true
  }
  let positioning = match options.positioning {
    Some(value) => value
    None => OneCell
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
    name~,
    alt_text~,
    lock_aspect_ratio~,
    auto_fit~,
    auto_fit_ignore_aspect~,
    print_object~,
    locked~,
    positioning~,
  )
}

///|
#cfg(target="native")
pub async fn Workbook::add_picture(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  path : String,
  offset_x? : Int = 0,
  offset_y? : Int = 0,
  scale_x? : Double = 1.0,
  scale_y? : Double = 1.0,
  hyperlink? : String = "",
  hyperlink_type? : HyperlinkType = Unset,
  name? : String = "",
  alt_text? : String = "",
  lock_aspect_ratio? : Bool = false,
  auto_fit? : Bool = false,
  auto_fit_ignore_aspect? : Bool = false,
  print_object? : Bool = true,
  locked? : Bool = true,
  positioning? : PicturePositioning = OneCell,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_picture(
    reference,
    path,
    offset_x~,
    offset_y~,
    scale_x~,
    scale_y~,
    hyperlink~,
    hyperlink_type~,
    name~,
    alt_text~,
    lock_aspect_ratio~,
    auto_fit~,
    auto_fit_ignore_aspect~,
    print_object~,
    locked~,
    positioning~,
  )
}

///|
#cfg(target="native")
pub async fn Workbook::add_picture_with_options(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  path : String,
  options : GraphicOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_picture_with_options(reference, path, options)
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
  hyperlink_type? : HyperlinkType = Unset,
  name? : String = "",
  alt_text? : String = "",
  lock_aspect_ratio? : Bool = false,
  auto_fit? : Bool = false,
  auto_fit_ignore_aspect? : Bool = false,
  print_object? : Bool = true,
  locked? : Bool = true,
  positioning? : PicturePositioning = OneCell,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
    name~,
    alt_text~,
    lock_aspect_ratio~,
    auto_fit~,
    auto_fit_ignore_aspect~,
    print_object~,
    locked~,
    positioning~,
  )
}

///|
pub fn Workbook::add_picture_from_bytes_with_options(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  data : Bytes,
  extension : String,
  options : GraphicOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_picture_from_bytes_with_options(reference, data, extension, options)
}

///|
pub fn Workbook::add_header_footer_image(
  self : Workbook,
  sheet_name : StringView,
  options : HeaderFooterImageOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_header_footer_image(options)
}

///|
#cfg(target="native")
pub async fn Workbook::add_header_footer_image_from_file(
  self : Workbook,
  sheet_name : StringView,
  options : HeaderFooterImageOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_header_footer_image_from_file(options)
}

///|
pub fn Workbook::get_pictures(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Array[Image] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_pictures(cell)
}

///|
pub fn Workbook::get_picture_cells(
  self : Workbook,
  sheet_name : StringView,
) -> Array[String] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_picture_cells()
}

///|
pub fn Workbook::delete_picture(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.delete_picture(cell)
}

///|
pub fn Workbook::add_chart(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_chart(reference, xml)
}

///|
pub fn Workbook::add_chart_with_options(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  opts : ChartOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_chart_with_options(reference, opts)
}

///|
pub fn Workbook::delete_chart(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.delete_chart(cell)
}

///|
pub fn Workbook::add_shape(
  self : Workbook,
  sheet_name : StringView,
  shape : Shape,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_shape(shape)
}

///|
pub fn Workbook::add_vml_drawing_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_vml_drawing_xml(xml)
}

///|
pub fn Workbook::add_vml_drawing_hf_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_vml_drawing_hf_xml(xml)
}

///|
pub fn Workbook::add_form_control(
  self : Workbook,
  sheet_name : StringView,
  control : FormControl,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_form_control(control)
}

///|
pub fn Workbook::get_form_controls(
  self : Workbook,
  sheet_name : StringView,
) -> Array[FormControl] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  sheet.delete_form_control(cell)
}

///|
pub fn Workbook::add_slicer(
  self : Workbook,
  sheet_name : StringView,
  opts : SlicerOptions,
) -> Unit raise XlsxError {
  fn slicer_cache_stub(value : StringView) -> String {
    let name = value.to_string()
    let sb = StringBuilder::new()
    for i, ch in name {
      let code = ch.to_int()
      let is_letter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
      let is_digit = code >= 48 && code <= 57
      if is_letter {
        sb.write_view(ch.to_string())
      } else if i > 0 && (is_digit || ch == '.') {
        sb.write_view(ch.to_string())
      } else {
        sb.write_view("_")
      }
    }
    sb.to_string()
  }

  fn gen_slicer_cache_name(
    workbook : Workbook,
    field_name : StringView,
  ) -> String {
    let base = "Slicer_" + slicer_cache_stub(field_name)
    let existing : Array[String] = []
    for dn in workbook.defined_names {
      if normalize_defined_name_scope(dn.scope) == "Workbook" {
        existing.push(dn.name.to_lower())
      }
    }
    let mut cnt = 0
    while cnt < 1000000 {
      let candidate = if cnt == 0 { base } else { "\{base}\{cnt}" }
      if !existing.contains(candidate.to_lower()) {
        return candidate
      }
      cnt = cnt + 1
    }
    base
  }

  fn gen_slicer_name(workbook : Workbook, base_name : StringView) -> String {
    let base = base_name.to_string()
    let existing : Array[String] = []
    for sheet in workbook.sheets {
      for slicer in sheet.slicers() {
        existing.push(slicer.name.to_lower())
      }
    }
    let mut cnt = 0
    while cnt < 1000000 {
      let candidate = if cnt == 0 { base } else { "\{base} \{cnt}" }
      if !existing.contains(candidate.to_lower()) {
        return candidate
      }
      cnt = cnt + 1
    }
    base
  }

  fn pivot_cache_field_names(
    cache_definition_xml : StringView,
  ) -> Array[String] {
    let xml = cache_definition_xml.to_string()
    let out : Array[String] = []
    let needle = "<cacheField name=\""
    let mut pos = 0
    while pos < xml.length() {
      let tail = xml[pos:]
      let rel = match tail.find(needle) {
        Some(v) => v
        None => break
      }
      let after = pos + rel + needle.length()
      let rest = xml.unsafe_substring(start=after, end=xml.length())
      let end = match rest.find("\"") {
        Some(v) => v
        None => break
      }
      let name = rest.unsafe_substring(start=0, end~)
      out.push(name.to_string())
      pos = after + end + 1
    }
    out
  }

  let sheet = self.require_sheet(sheet_name)
  ignore(check_sheet_name(opts.table_sheet))
  match self.sheet(opts.table_sheet) {
    Some(_) => ()
    None => raise SheetNotFound(name=opts.table_sheet)
  }
  let mut has_source = false
  let mut is_table_slicer = false
  let tables = self.get_tables(opts.table_sheet)
  for table in tables {
    if table.name == opts.table_name {
      has_source = true
      is_table_slicer = true
      if !table.columns.contains(opts.name) {
        raise InvalidSheetOperation(msg="slicer field not found in table")
      }
      break
    }
  }
  if !has_source {
    let pivots = self.get_pivot_tables(opts.table_sheet)
    for pivot in pivots {
      if pivot.name == opts.table_name {
        has_source = true
        let fields = pivot_cache_field_names(pivot.cache_definition_xml)
        let mut found = false
        for field in fields {
          if field.to_lower() == opts.name.to_lower() {
            found = true
            break
          }
        }
        if !found {
          raise InvalidSheetOperation(
            msg="slicer field not found in pivot cache",
          )
        }
        break
      }
    }
  }
  if !has_source {
    raise TableNotFound(name=opts.table_name)
  }
  let mut cache_name = ""
  for ws in self.sheets {
    for existing in ws.slicers() {
      if existing.table_sheet == opts.table_sheet &&
        existing.table_name == opts.table_name &&
        (if is_table_slicer {
          existing.source_name.to_lower() == opts.name.to_lower()
        } else {
          true
        }) {
        cache_name = existing.cache
        break
      }
    }
    if cache_name != "" {
      break
    }
  }
  if cache_name == "" {
    cache_name = gen_slicer_cache_name(self, opts.name)
    self.set_defined_name(DefinedName::new(cache_name, "#N/A"))
  }
  let slicer_name = gen_slicer_name(self, opts.name)
  let format = opts.format
  if format.positioning is None {
    format.positioning = Some(TwoCell)
  }
  if format.print_object is None {
    format.print_object = Some(true)
  }
  if format.locked is None {
    format.locked = Some(true)
  }
  let slicer = {
    name: slicer_name,
    cache: cache_name,
    source_name: opts.name,
    cell: opts.cell,
    table_sheet: opts.table_sheet,
    table_name: opts.table_name,
    caption: opts.caption,
    macro_name: opts.macro_name,
    width: opts.width,
    height: opts.height,
    display_header: opts.display_header,
    item_desc: opts.item_desc,
    format,
  }
  sheet.add_slicer(slicer)
}

///|
pub fn Workbook::add_slicer_with_options(
  self : Workbook,
  sheet_name : StringView,
  opts : SlicerOptions,
) -> Unit raise XlsxError {
  self.add_slicer(sheet_name, opts)
}

///|
pub fn Workbook::add_slicer_raw(
  self : Workbook,
  sheet_name : StringView,
  slicer : Slicer,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_slicer(slicer)
}

///|
pub fn Workbook::get_slicers(
  self : Workbook,
  sheet_name : StringView,
) -> Array[Slicer] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
    raise InvalidSheetOperation(msg="slicer not found")
  }
}

///|
pub fn Workbook::add_comment(
  self : Workbook,
  sheet_name : StringView,
  comment : Comment,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_comment(comment)
}

///|
pub fn Workbook::delete_comment(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.delete_comment(cell)
}

///|
pub fn Workbook::get_comments(
  self : Workbook,
  sheet_name : StringView,
) -> Array[Comment] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  sheet.set_auto_filter(range_ref, options)
  let abs_range = auto_filter_abs_range_ref(range_ref)
  let refers_to = "'\{escape_sheet_name(sheet_name)}'!\{abs_range}"
  upsert_defined_name_for_scope(
    self, "_xlnm._FilterDatabase", sheet_name, refers_to,
  )
}

///|
pub fn Workbook::clear_auto_filter(
  self : Workbook,
  sheet_name : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.clear_auto_filter()
  remove_defined_name_for_scope(self, "_xlnm._FilterDatabase", sheet_name)
}

///|
pub fn Workbook::get_auto_filter(
  self : Workbook,
  sheet_name : StringView,
) -> AutoFilter? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.auto_filter()
}

///|
fn abs_cell_ref_from_rc(row : Int, col : Int) -> String raise XlsxError {
  let base = cell_ref_from(row, col)
  let chars = base.to_array()
  let mut split = 0
  while split < chars.length() && chars[split].is_ascii_alphabetic() {
    split = split + 1
  }
  let col_text = base.unsafe_substring(start=0, end=split)
  let row_text = base.unsafe_substring(start=split, end=base.length())
  "$\{col_text}$\{row_text}"
}

///|
fn auto_filter_abs_range_ref(range_ref : StringView) -> String raise XlsxError {
  let normalized = normalize_range_ref(range_ref)
  let (min_row, min_col, max_row, max_col) = parse_range_ref(normalized)
  let start_ref = abs_cell_ref_from_rc(min_row, min_col)
  let end_ref = abs_cell_ref_from_rc(max_row, max_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn upsert_defined_name_for_scope(
  workbook : Workbook,
  name : String,
  scope : StringView,
  refers_to : String,
) -> Unit {
  let normalized_scope = normalize_defined_name_scope(scope)
  let scope_key = defined_name_scope_key(normalized_scope)
  for i, dn in workbook.defined_names {
    if dn.name == name && defined_name_scope_key(dn.scope) == scope_key {
      workbook.defined_names[i] = {
        name,
        refers_to,
        scope: normalized_scope,
        comment: dn.comment,
      }
      return
    }
  }
  workbook.defined_names.push({
    name,
    refers_to,
    scope: normalized_scope,
    comment: "",
  })
}

///|
fn remove_defined_name_for_scope(
  workbook : Workbook,
  name : String,
  scope : StringView,
) -> Unit {
  if workbook.defined_names.length() == 0 {
    return
  }
  let normalized_scope = normalize_defined_name_scope(scope)
  let scope_key = defined_name_scope_key(normalized_scope)
  let updated : Array[DefinedName] = []
  for dn in workbook.defined_names {
    if dn.name == name && defined_name_scope_key(dn.scope) == scope_key {
      continue
    }
    updated.push(dn)
  }
  workbook.defined_names.clear()
  workbook.defined_names.append(updated[:])
}

///|
pub fn Workbook::add_data_validation_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_data_validation_xml(xml)
}

///|
pub fn Workbook::add_data_validation(
  self : Workbook,
  sheet_name : StringView,
  dv : DataValidation,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  sheet.add_data_validation_list(range_ref, values, allow_blank~)
}

///|
pub fn Workbook::get_data_validations(
  self : Workbook,
  sheet_name : StringView,
) -> Array[DataValidation] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_data_validations()
}

///|
pub fn Workbook::delete_data_validation(
  self : Workbook,
  sheet_name : StringView,
  sqrefs? : Array[String] = [],
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.delete_data_validation(sqrefs~)
}

///|
pub fn Workbook::add_ignored_errors(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  error_type : IgnoredErrorType,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_ignored_errors(range_ref, error_type)
}

///|
pub fn Workbook::add_conditional_format_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_conditional_format_xml(xml)
}

///|
pub fn Workbook::set_conditional_format(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  options : ArrayView[ConditionalFormatOptions],
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_conditional_format(range_ref, options)
}

///|
pub fn Workbook::get_conditional_formats(
  self : Workbook,
  sheet_name : StringView,
) -> Map[String, Array[ConditionalFormatOptions]] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_conditional_formats()
}

///|
pub fn Workbook::unset_conditional_format(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.unset_conditional_format(range_ref)
}

///|
pub fn Workbook::merge_cells(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  let merged : Array[String] = []
  for range_ref in sheet.merged_cells() {
    merged.push(range_ref)
  }
  merged
}

///|
pub fn Workbook::get_merge_cells_info(
  self : Workbook,
  sheet_name : StringView,
  without_values? : Bool = false,
  options? : Options,
) -> Array[MergeCell] raise XlsxError {
  check_sheet_name(sheet_name)
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let sheet = self.require_sheet(sheet_name)
  let merged_ranges = merge_overlap_ranges(sheet.merged_cells())
  let results : Array[MergeCell] = []
  for range_ref in merged_ranges {
    let value = if without_values {
      ""
    } else {
      let (min_row, min_col, _, _) = parse_range_ref(range_ref)
      let start_axis = cell_ref_from(min_row, min_col)
      match
        self.get_cell_value(sheet_name, start_axis, options=resolved_options) {
        Some(text) => text
        None => ""
      }
    }
    results.push(MergeCell::new(range_ref, value))
  }
  results
}

///|
pub fn Workbook::add_table(
  self : Workbook,
  sheet_name : StringView,
  options : TableOptions,
) -> Table raise XlsxError {
  fn table_name_exists(workbook : Workbook, name : StringView) -> Bool {
    let target = name.to_string().to_lower()
    for sheet in workbook.sheets {
      for table in sheet.tables {
        if table.name.to_lower() == target {
          return true
        }
      }
    }
    false
  }

  fn next_table_name(workbook : Workbook) -> String {
    let mut max_id = 0
    for sheet in workbook.sheets {
      for table in sheet.tables {
        let name = table.name
        if !name.has_prefix("Table") {
          continue
        }
        let suffix = name["Table".length():]
        if suffix == "" {
          continue
        }
        let id = @strconv.parse_int(suffix, base=10) catch { _ => continue }
        if id > max_id {
          max_id = id
        }
      }
    }
    "Table\{max_id + 1}"
  }

  fn intersects_existing_tables(
    sheet : Worksheet,
    min_row : Int,
    min_col : Int,
    max_row : Int,
    max_col : Int,
  ) -> Bool raise XlsxError {
    for table in sheet.tables() {
      let (t_min_row, t_min_col, t_max_row, t_max_col) = parse_range_ref(
        table.range_ref,
      )
      let disjoint = max_row < t_min_row ||
        min_row > t_max_row ||
        max_col < t_min_col ||
        min_col > t_max_col
      if !disjoint {
        return true
      }
    }
    false
  }

  let sheet = self.require_sheet(sheet_name)
  let show_header_row = match options.show_header_row {
    Some(v) => v
    None => true
  }
  let show_row_stripes = match options.show_row_stripes {
    Some(v) => v
    None => true
  }
  let style_name = if options.style_name == "" {
    "TableStyleMedium9"
  } else {
    options.style_name
  }
  let normalized = normalize_range_ref(options.range_ref)
  let (min_row0, min_col, max_row0, max_col) = parse_range_ref(normalized)
  let max_row = if min_row0 == max_row0 { max_row0 + 1 } else { max_row0 }
  if intersects_existing_tables(sheet, min_row0, min_col, max_row, max_col) {
    raise InvalidTable(msg="table range intersects existing table")
  }
  let range_ref = normalize_range_ref(
    "\{cell_ref_from(min_row0, min_col)}:\{cell_ref_from(max_row, max_col)}",
  )
  let header_row = if show_header_row { min_row0 } else { min_row0 + 1 }
  let column_names : Array[String] = []
  let seen : Array[String] = []
  let mut idx = 0
  let mut col = min_col
  while col <= max_col {
    idx = idx + 1
    let cell = cell_ref_from(header_row, col)
    let raw = match self.get_cell_value(sheet_name, cell, raw=true) {
      Some(v) => v
      None => ""
    }
    let mut name = raw
    if name == "" || seen.contains(name.to_lower()) {
      name = "Column\{idx}"
      if show_header_row {
        self.set_cell(sheet_name, cell, name)
      }
    }
    seen.push(name.to_lower())
    column_names.push(name)
    col = col + 1
  }
  let mut table_name = options.name
  if table_name == "" {
    table_name = next_table_name(self)
  } else {
    check_defined_name(table_name) catch {
      _ => raise InvalidTable(msg="table name invalid")
    }
  }
  if table_name_exists(self, table_name) {
    raise InvalidTable(msg="table name exists")
  }
  sheet.add_table(
    range_ref,
    table_name,
    column_names,
    display_name=table_name,
    style_name~,
    show_first_column=options.show_first_column,
    show_last_column=options.show_last_column,
    show_row_stripes~,
    show_column_stripes=options.show_column_stripes,
    show_header_row~,
  )
}

///|
pub fn Workbook::add_table_with_columns(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  name : String,
  columns : ArrayView[String],
  display_name? : String = "",
  style_name? : String = "TableStyleMedium9",
  show_first_column? : Bool = false,
  show_last_column? : Bool = false,
  show_row_stripes? : Bool = true,
  show_column_stripes? : Bool = false,
  show_header_row? : Bool = true,
) -> Table raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_table(
    range_ref,
    name,
    columns,
    display_name~,
    style_name~,
    show_first_column~,
    show_last_column~,
    show_row_stripes~,
    show_column_stripes~,
    show_header_row~,
  )
}

///|
pub fn Workbook::get_tables(
  self : Workbook,
  sheet_name : StringView,
) -> Array[Table] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  raise TableNotFound(name=target)
}

///|
pub fn Workbook::add_sparkline(
  self : Workbook,
  sheet_name : StringView,
  options : SparklineOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_sparkline_options(options)
}

///|
pub fn Workbook::add_sparkline_group(
  self : Workbook,
  sheet_name : StringView,
  locations : ArrayView[String],
  ranges : ArrayView[String],
  sparkline_type? : SparklineType = Line,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_sparkline_group(locations, ranges, sparkline_type~)
}

///|
pub fn Workbook::add_sparkline_options(
  self : Workbook,
  sheet_name : StringView,
  options : SparklineOptions,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_sparkline_options(options)
}

///|
pub fn Workbook::add_sparkline_basic(
  self : Workbook,
  sheet_name : StringView,
  location : String,
  range_ref : String,
  sparkline_type? : SparklineType = Line,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.add_sparkline(location, range_ref, sparkline_type~)
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
  let sheet = self.require_sheet(sheet_name)
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
  opts : PivotTableOptions,
) -> PivotTable raise XlsxError {
  self.add_pivot_table_with_options(opts)
}

///|
fn Workbook::next_pivot_table_name(self : Workbook) -> String {
  let mut max_id = 0
  for sheet in self.sheets {
    for pivot in sheet.pivot_tables {
      let name = pivot.name
      if !name.has_prefix("PivotTable") {
        continue
      }
      let suffix = name["PivotTable".length():]
      if suffix == "" {
        continue
      }
      let id = @strconv.parse_int(suffix, base=10) catch { _ => continue }
      if id > max_id {
        max_id = id
      }
    }
  }
  "PivotTable\{max_id + 1}"
}

///|
fn Workbook::add_pivot_table_with_options(
  self : Workbook,
  opts : PivotTableOptions,
) -> PivotTable raise XlsxError {
  if opts.compact_data && opts.classic_layout {
    raise InvalidPivotTable(
      msg="pivot compactData is incompatible with classic layout",
    )
  }
  let (data_sheet, data_ref) = split_sheet_range(opts.data_range)
  let (pivot_sheet, pivot_ref) = split_sheet_range(opts.pivot_table_range)
  let (header_row, min_col, max_row, max_col) = parse_range_ref(data_ref)
  if max_row <= header_row || max_col <= min_col {
    raise InvalidPivotTable(msg="pivot data range invalid")
  }
  let field_names : Array[String] = []
  let mut col = min_col
  while col <= max_col {
    let axis = cell_ref_from(header_row, col)
    let value = match
      self.get_cell_value(data_sheet, axis, options=self.options) {
      Some(text) => text
      None => ""
    }
    if value == "" {
      raise InvalidPivotTable(msg="pivot field name empty")
    }
    field_names.push(value)
    col = col + 1
  }
  let field_index : Map[String, Int] = {}
  for i, name in field_names {
    field_index[name] = i
  }
  fn resolve_field_index(
    field_index : Map[String, Int],
    name : String,
  ) -> Int raise XlsxError {
    match field_index.get(name) {
      Some(idx) => idx
      None => raise InvalidPivotTable(msg="pivot field not found: \{name}")
    }
  }

  let row_fields : Array[(Int, PivotTableField)] = []
  for field in opts.rows {
    row_fields.push((resolve_field_index(field_index, field.data), field))
  }
  let col_fields : Array[(Int, PivotTableField)] = []
  for field in opts.columns {
    col_fields.push((resolve_field_index(field_index, field.data), field))
  }
  let page_fields : Array[(Int, PivotTableField)] = []
  for field in opts.filter {
    page_fields.push((resolve_field_index(field_index, field.data), field))
  }
  let data_fields : Array[(Int, PivotTableField)] = []
  for field in opts.data {
    let idx = resolve_field_index(field_index, field.data)
    data_fields.push((idx, field))
  }
  let mut pivot_name = opts.name
  if pivot_name == "" {
    pivot_name = self.next_pivot_table_name()
  }
  if pivot_name.length() > 255 {
    raise InvalidPivotTable(msg="pivot table name too long")
  }
  let cache_id_guess = 1
  let cache_xml = write_pivot_cache_definition_xml(
    data_sheet, data_ref, field_names,
  )
  let table_xml = write_pivot_table_definition_xml(
    pivot_name, cache_id_guess, pivot_ref, field_names, row_fields, col_fields, page_fields,
    data_fields, opts,
  )
  self.add_pivot_table_xml(
    pivot_sheet,
    table_xml,
    cache_xml,
    cache_records_xml="",
    name=pivot_name,
  )
}

///|
pub fn Workbook::get_pivot_tables(
  self : Workbook,
  sheet_name : StringView,
) -> Array[PivotTable] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  clone_pivot_tables(sheet.pivot_tables())
}

///|
pub fn Workbook::delete_pivot_table(
  self : Workbook,
  sheet_name : StringView,
  name : StringView,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  sheet.set_cell_value_rc(row, col, value)
}

///|
pub fn Workbook::get_cell_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> String? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_cell_rc(row, col)
}

///|
pub fn Workbook::get_cell_value_raw_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> CellValue? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_cell_value_raw_rc(row, col)
}

///|
pub fn Workbook::get_cell_value_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  raw? : Bool = false,
  options? : Options,
) -> String? raise XlsxError {
  check_sheet_name(sheet_name)
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let sheet = self.require_sheet(sheet_name)
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      return Some(
        format_cell_value_for_workbook(self.styles, cell, raw, resolved_options),
      )
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
  check_sheet_name(sheet_name)
  self.check_style_id(style_id)
  let sheet = self.require_sheet(sheet_name)
  sheet.set_cell_style_rc(row, col, style_id)
}

///|
pub fn Workbook::get_cell_style_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> Int? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  sheet.set_cell_formula_rc(row, col, formula, value~)
}

///|
pub fn Workbook::set_row(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_row(row, values)
}

///|
pub fn Workbook::get_row(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Array[String] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_row(row)
}

///|
pub fn Workbook::set_col(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_col(col, values)
}

///|
pub fn Workbook::get_col(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Array[String] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_col(col)
}

///|
pub fn Workbook::set_row_height(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  height : Double,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_row_height(row, height)
}

///|
pub fn Workbook::get_row_height(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Double? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_row_height(row)
}

///|
pub fn Workbook::set_row_visible(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_row_visible(row, visible)
}

///|
pub fn Workbook::row_visible(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Bool raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.row_visible(row)
}

///|
pub fn Workbook::set_row_outline_level(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  level : Int,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_row_outline_level(row, level)
}

///|
pub fn Workbook::row_outline_level(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Int raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.row_outline_level(row)
}

///|
pub fn Workbook::set_row_style(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.set_row_style_range(sheet_name, row, row, style_id)
}

///|
pub fn Workbook::set_row_style_range(
  self : Workbook,
  sheet_name : StringView,
  start : Int,
  end : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  check_sheet_name(sheet_name)
  self.check_style_id(style_id)
  let sheet = self.require_sheet(sheet_name)
  sheet.set_row_style_range(start, end, style_id)
}

///|
pub fn Workbook::get_row_style(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Int? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_row_style(row)
}

///|
pub fn Workbook::set_col_width(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  width : Double,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_col_width(col, width)
}

///|
pub fn Workbook::get_col_width(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Double? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_col_width(col)
}

///|
pub fn Workbook::set_col_visible(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_col_visible(col, visible)
}

///|
pub fn Workbook::col_visible(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Bool raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.col_visible(col)
}

///|
pub fn Workbook::set_col_outline_level(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  level : Int,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.set_col_outline_level(col, level)
}

///|
pub fn Workbook::col_outline_level(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Int raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.col_outline_level(col)
}

///|
pub fn Workbook::set_col_style(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  check_sheet_name(sheet_name)
  self.check_style_id(style_id)
  let sheet = self.require_sheet(sheet_name)
  sheet.set_col_style(col, style_id)
}

///|
pub fn Workbook::get_col_style(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Int? raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  sheet.get_col_style(col)
}

///|
pub fn Workbook::insert_rows(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
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
  let sheet = self.require_sheet(sheet_name)
  sheet.duplicate_row_to(row, target_row)
  self.adjust_defined_names_for_sheet(sheet.name(), fn(
    ref_text : StringView,
  ) -> String? raise XlsxError {
    adjust_ref_after_row_insert(ref_text, target_row, 1)
  })
}
