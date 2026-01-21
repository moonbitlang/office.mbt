///|
pub struct PageLayoutMarginsOptions {
  mut top : Double?
  mut bottom : Double?
  mut left : Double?
  mut right : Double?
  mut header : Double?
  mut footer : Double?
  mut horizontally : Bool?
  mut vertically : Bool?
} derive(Eq, Show)

///|
pub fn PageLayoutMarginsOptions::new() -> PageLayoutMarginsOptions {
  {
    top: None,
    bottom: None,
    left: None,
    right: None,
    header: None,
    footer: None,
    horizontally: None,
    vertically: None,
  }
}

///|
pub fn PageLayoutMarginsOptions::with_values(
  top? : Double,
  bottom? : Double,
  left? : Double,
  right? : Double,
  header? : Double,
  footer? : Double,
  horizontally? : Bool,
  vertically? : Bool,
) -> PageLayoutMarginsOptions {
  let opts = PageLayoutMarginsOptions::new()
  match top {
    Some(value) => opts.top = Some(value)
    None => ()
  }
  match bottom {
    Some(value) => opts.bottom = Some(value)
    None => ()
  }
  match left {
    Some(value) => opts.left = Some(value)
    None => ()
  }
  match right {
    Some(value) => opts.right = Some(value)
    None => ()
  }
  match header {
    Some(value) => opts.header = Some(value)
    None => ()
  }
  match footer {
    Some(value) => opts.footer = Some(value)
    None => ()
  }
  match horizontally {
    Some(value) => opts.horizontally = Some(value)
    None => ()
  }
  match vertically {
    Some(value) => opts.vertically = Some(value)
    None => ()
  }
  opts
}

///|
pub struct PageLayoutOptions {
  mut size : Int?
  mut orientation : String?
  mut first_page_number : Int?
  mut adjust_to : Int?
  mut fit_to_height : Int?
  mut fit_to_width : Int?
  mut black_and_white : Bool?
  mut page_order : String?
} derive(Eq, Show)

///|
pub fn PageLayoutOptions::new() -> PageLayoutOptions {
  {
    size: None,
    orientation: None,
    first_page_number: None,
    adjust_to: None,
    fit_to_height: None,
    fit_to_width: None,
    black_and_white: None,
    page_order: None,
  }
}

///|
pub fn PageLayoutOptions::with_values(
  size? : Int,
  orientation? : String,
  first_page_number? : Int,
  adjust_to? : Int,
  fit_to_height? : Int,
  fit_to_width? : Int,
  black_and_white? : Bool,
  page_order? : String,
) -> PageLayoutOptions {
  let opts = PageLayoutOptions::new()
  match size {
    Some(value) => opts.size = Some(value)
    None => ()
  }
  match orientation {
    Some(value) => opts.orientation = Some(value)
    None => ()
  }
  match first_page_number {
    Some(value) => opts.first_page_number = Some(value)
    None => ()
  }
  match adjust_to {
    Some(value) => opts.adjust_to = Some(value)
    None => ()
  }
  match fit_to_height {
    Some(value) => opts.fit_to_height = Some(value)
    None => ()
  }
  match fit_to_width {
    Some(value) => opts.fit_to_width = Some(value)
    None => ()
  }
  match black_and_white {
    Some(value) => opts.black_and_white = Some(value)
    None => ()
  }
  match page_order {
    Some(value) => opts.page_order = Some(value)
    None => ()
  }
  opts
}

///|
pub struct HeaderFooterOptions {
  mut align_with_margins : Bool?
  mut different_first : Bool
  mut different_odd_even : Bool
  mut scale_with_doc : Bool?
  mut odd_header : String
  mut odd_footer : String
  mut even_header : String
  mut even_footer : String
  mut first_header : String
  mut first_footer : String
} derive(Eq, Show)

///|
pub fn HeaderFooterOptions::new() -> HeaderFooterOptions {
  {
    align_with_margins: None,
    different_first: false,
    different_odd_even: false,
    scale_with_doc: None,
    odd_header: "",
    odd_footer: "",
    even_header: "",
    even_footer: "",
    first_header: "",
    first_footer: "",
  }
}

///|
pub fn HeaderFooterOptions::with_values(
  align_with_margins? : Bool,
  different_first? : Bool,
  different_odd_even? : Bool,
  scale_with_doc? : Bool,
  odd_header? : String,
  odd_footer? : String,
  even_header? : String,
  even_footer? : String,
  first_header? : String,
  first_footer? : String,
) -> HeaderFooterOptions {
  let opts = HeaderFooterOptions::new()
  match align_with_margins {
    Some(value) => opts.align_with_margins = Some(value)
    None => ()
  }
  match different_first {
    Some(value) => opts.different_first = value
    None => ()
  }
  match different_odd_even {
    Some(value) => opts.different_odd_even = value
    None => ()
  }
  match scale_with_doc {
    Some(value) => opts.scale_with_doc = Some(value)
    None => ()
  }
  match odd_header {
    Some(value) => opts.odd_header = value
    None => ()
  }
  match odd_footer {
    Some(value) => opts.odd_footer = value
    None => ()
  }
  match even_header {
    Some(value) => opts.even_header = value
    None => ()
  }
  match even_footer {
    Some(value) => opts.even_footer = value
    None => ()
  }
  match first_header {
    Some(value) => opts.first_header = value
    None => ()
  }
  match first_footer {
    Some(value) => opts.first_footer = value
    None => ()
  }
  opts
}

///|
pub struct SheetProtectionOptions {
  mut algorithm_name : String
  mut password : String
  mut auto_filter : Bool
  mut delete_columns : Bool
  mut delete_rows : Bool
  mut edit_objects : Bool
  mut edit_scenarios : Bool
  mut format_cells : Bool
  mut format_columns : Bool
  mut format_rows : Bool
  mut insert_columns : Bool
  mut insert_hyperlinks : Bool
  mut insert_rows : Bool
  mut pivot_tables : Bool
  mut select_locked_cells : Bool
  mut select_unlocked_cells : Bool
  mut sort : Bool
} derive(Eq, Show)

///|
pub fn SheetProtectionOptions::new() -> SheetProtectionOptions {
  {
    algorithm_name: "",
    password: "",
    auto_filter: false,
    delete_columns: false,
    delete_rows: false,
    edit_objects: false,
    edit_scenarios: false,
    format_cells: false,
    format_columns: false,
    format_rows: false,
    insert_columns: false,
    insert_hyperlinks: false,
    insert_rows: false,
    pivot_tables: false,
    select_locked_cells: false,
    select_unlocked_cells: false,
    sort: false,
  }
}

///|
pub fn SheetProtectionOptions::with_values(
  algorithm_name? : String,
  password? : String,
  auto_filter? : Bool,
  delete_columns? : Bool,
  delete_rows? : Bool,
  edit_objects? : Bool,
  edit_scenarios? : Bool,
  format_cells? : Bool,
  format_columns? : Bool,
  format_rows? : Bool,
  insert_columns? : Bool,
  insert_hyperlinks? : Bool,
  insert_rows? : Bool,
  pivot_tables? : Bool,
  select_locked_cells? : Bool,
  select_unlocked_cells? : Bool,
  sort? : Bool,
) -> SheetProtectionOptions {
  let opts = SheetProtectionOptions::new()
  match algorithm_name {
    Some(value) => opts.algorithm_name = value
    None => ()
  }
  match password {
    Some(value) => opts.password = value
    None => ()
  }
  match auto_filter {
    Some(value) => opts.auto_filter = value
    None => ()
  }
  match delete_columns {
    Some(value) => opts.delete_columns = value
    None => ()
  }
  match delete_rows {
    Some(value) => opts.delete_rows = value
    None => ()
  }
  match edit_objects {
    Some(value) => opts.edit_objects = value
    None => ()
  }
  match edit_scenarios {
    Some(value) => opts.edit_scenarios = value
    None => ()
  }
  match format_cells {
    Some(value) => opts.format_cells = value
    None => ()
  }
  match format_columns {
    Some(value) => opts.format_columns = value
    None => ()
  }
  match format_rows {
    Some(value) => opts.format_rows = value
    None => ()
  }
  match insert_columns {
    Some(value) => opts.insert_columns = value
    None => ()
  }
  match insert_hyperlinks {
    Some(value) => opts.insert_hyperlinks = value
    None => ()
  }
  match insert_rows {
    Some(value) => opts.insert_rows = value
    None => ()
  }
  match pivot_tables {
    Some(value) => opts.pivot_tables = value
    None => ()
  }
  match select_locked_cells {
    Some(value) => opts.select_locked_cells = value
    None => ()
  }
  match select_unlocked_cells {
    Some(value) => opts.select_unlocked_cells = value
    None => ()
  }
  match sort {
    Some(value) => opts.sort = value
    None => ()
  }
  opts
}

///|
pub struct SheetProtection {
  mut algorithm_name : String
  mut password : String
  mut hash_value : String
  mut salt_value : String
  mut spin_count : Int
  sheet : Bool
  objects : Bool
  scenarios : Bool
  format_cells : Bool
  format_columns : Bool
  format_rows : Bool
  insert_columns : Bool
  insert_rows : Bool
  insert_hyperlinks : Bool
  delete_columns : Bool
  delete_rows : Bool
  select_locked_cells : Bool
  sort : Bool
  auto_filter : Bool
  pivot_tables : Bool
  select_unlocked_cells : Bool
} derive(Eq, Show)

///|
pub struct SheetBackground {
  data : Bytes
  extension : String
  content_type : String
} derive(Eq, Show)

///|
pub struct PageBreak {
  id : Int
  min : Int
  max : Int
  manual : Bool
} derive(Eq, Show)

///|
let default_page_margins : PageLayoutMarginsOptions = PageLayoutMarginsOptions::with_values(
  top=0.75,
  bottom=0.75,
  left=0.7,
  right=0.7,
  header=0.3,
  footer=0.3,
)

///|
let default_page_layout : PageLayoutOptions = PageLayoutOptions::with_values(
  size=0,
  orientation="portrait",
  first_page_number=1,
  adjust_to=100,
)

///|
let supported_page_orientation : Array[String] = ["portrait", "landscape"]

///|
let supported_page_order : Array[String] = ["overThenDown", "downThenOver"]

///|
fn page_margins_with_defaults(
  options : PageLayoutMarginsOptions?,
) -> PageLayoutMarginsOptions {
  match options {
    Some(value) => {
      let merged = default_page_margins
      match value.top {
        Some(v) => merged.top = Some(v)
        None => ()
      }
      match value.bottom {
        Some(v) => merged.bottom = Some(v)
        None => ()
      }
      match value.left {
        Some(v) => merged.left = Some(v)
        None => ()
      }
      match value.right {
        Some(v) => merged.right = Some(v)
        None => ()
      }
      match value.header {
        Some(v) => merged.header = Some(v)
        None => ()
      }
      match value.footer {
        Some(v) => merged.footer = Some(v)
        None => ()
      }
      match value.horizontally {
        Some(v) => merged.horizontally = Some(v)
        None => ()
      }
      match value.vertically {
        Some(v) => merged.vertically = Some(v)
        None => ()
      }
      merged
    }
    None => default_page_margins
  }
}

///|
fn page_layout_with_defaults(options : PageLayoutOptions?) -> PageLayoutOptions {
  match options {
    Some(value) => {
      let merged = default_page_layout
      match value.size {
        Some(v) => merged.size = Some(v)
        None => ()
      }
      match value.orientation {
        Some(v) => merged.orientation = Some(v)
        None => ()
      }
      match value.first_page_number {
        Some(v) => merged.first_page_number = Some(v)
        None => ()
      }
      match value.adjust_to {
        Some(v) => merged.adjust_to = Some(v)
        None => ()
      }
      match value.fit_to_height {
        Some(v) => merged.fit_to_height = Some(v)
        None => ()
      }
      match value.fit_to_width {
        Some(v) => merged.fit_to_width = Some(v)
        None => ()
      }
      match value.black_and_white {
        Some(v) => merged.black_and_white = Some(v)
        None => ()
      }
      match value.page_order {
        Some(v) => merged.page_order = Some(v)
        None => ()
      }
      merged
    }
    None => default_page_layout
  }
}
