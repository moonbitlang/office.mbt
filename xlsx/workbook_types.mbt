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
  default_table_style : String
  default_pivot_style : String
  theme_colors : Array[String]?
  theme_xml : String?
  indexed_colors : Array[String]?
  mru_colors_xml : String?
  styles_ext_lst_xml : String?
  mut io_context : WorkbookIOContext
  options : Options
  mut workbook_protection : WorkbookProtection?
  mut active_sheet_index : Int
  /// Kingsoft WPS Office embedded cell images parsed from
  /// xl/cellimages.xml on read, keyed by their DISPIMG identifier.
  cell_images : Array[CellImage]
  /// Modern rich-value ("Place in cell") image metadata parsed from
  /// xl/metadata.xml and xl/richData/* on read.
  rich_value_images : RichValueImages?
  /// Media parts referenced by rich-value images, keyed by archive path.
  rich_value_media : Map[String, Bytes]
  /// Per-sheet cell `vm` (value-metadata) indices captured on read,
  /// keyed by sheet name then canonical cell reference.
  rich_value_vm : Map[String, Map[String, Int]]
}

///|
enum SheetEntry {
  Worksheet(Int)
  ChartSheet(Int)
} derive(Show)

///|
let max_sheet_name_length = 31

///|
let ole_identifier_bytes : Bytes = Bytes::from_array(ole_identifier)

///|
fn check_sheet_name(name : StringView) -> Unit raise XlsxError {
  let text = name.to_string()
  if text == "" {
    raise InvalidSheetName(msg="sheet name is blank")
  }
  if text.length() > max_sheet_name_length {
    raise InvalidSheetName(msg="sheet name too long")
  }
  if text.has_prefix("'") || text.has_suffix("'") {
    raise InvalidSheetName(
      msg="sheet name cannot start or end with a single quote",
    )
  }
  for c in text {
    match c {
      ':' | '\\' | '/' | '?' | '*' | '[' | ']' =>
        raise InvalidSheetName(msg="sheet name contains invalid characters")
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
      Worksheet(idx) =>
        if normalize_sheet_name(self.sheets[idx].name()) == needle {
          return Some(i)
        }
      ChartSheet(idx) =>
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
      Worksheet(idx) =>
        if normalize_sheet_name(self.sheets[idx].name()) == needle {
          return Some(entry)
        }
      ChartSheet(idx) =>
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
    Worksheet(idx) => self.sheets[idx].name()
    ChartSheet(idx) => self.chart_sheets[idx].name()
  }
}

///|
fn Workbook::sheet_entry_state(
  self : Workbook,
  entry : SheetEntry,
) -> SheetState {
  match entry {
    Worksheet(idx) => self.sheets[idx].state()
    ChartSheet(idx) => self.chart_sheets[idx].state()
  }
}

///|
fn Workbook::set_sheet_entry_state(
  self : Workbook,
  entry : SheetEntry,
  state : SheetState,
) -> Unit {
  match entry {
    Worksheet(idx) => self.sheets[idx].state = state
    ChartSheet(idx) => self.chart_sheets[idx].state = state
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
pub fn Workbook::new(options? : Options = Options::new()) -> Workbook {
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
    default_table_style: "TableStyleMedium9",
    default_pivot_style: "PivotStyleLight16",
    theme_colors: None,
    theme_xml: None,
    indexed_colors: None,
    mru_colors_xml: None,
    styles_ext_lst_xml: None,
    io_context: empty_workbook_io_context(),
    options,
    workbook_protection: None,
    active_sheet_index: 0,
    cell_images: [],
    rich_value_images: None,
    rich_value_media: {},
    rich_value_vm: {},
  }
}
