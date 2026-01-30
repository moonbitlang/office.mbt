///|
pub(all) enum SparklineType {
  Line
  Column
  WinLoss
} derive(Eq, Show)

///|
pub struct SparklineColor {
  rgb : String?
  theme : Int?
  tint : Double?
} derive(Eq, Show)

///|
pub fn SparklineColor::rgb(
  value : StringView,
) -> SparklineColor raise XlsxError {
  let raw = value.to_string().to_upper()
  let hex = if raw.has_prefix("#") {
    let rest = raw[1:] catch {
        _ => raise XlsxError::InvalidSparkline(msg="sparkline color invalid")
      }
    rest.to_string()
  } else {
    raw
  }
  let normalized = match hex.length() {
    6 => "FF" + hex
    8 => hex
    _ =>
      raise XlsxError::InvalidSparkline(
        msg="sparkline color must be RRGGBB or AARRGGBB",
      )
  }
  for ch in normalized.to_array() {
    let ok = (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'F')
    if !ok {
      raise XlsxError::InvalidSparkline(msg="sparkline color must be hex")
    }
  }
  { rgb: Some(normalized), theme: None, tint: None }
}

///|
pub fn SparklineColor::theme(
  theme : Int,
  tint? : Double = 0.0,
) -> SparklineColor {
  let tint_opt = if tint == 0.0 { None } else { Some(tint) }
  { rgb: None, theme: Some(theme), tint: tint_opt }
}

///|
pub struct Sparkline {
  range_ref : String
  location : String
}

///|
pub struct SparklineGroupOptions {
  mut display_empty_cells_as : String
  mut date_axis : Bool
  mut line_weight : Double?
  mut manual_max : Int?
  mut manual_min : Int?
  mut markers : Bool
  mut high : Bool
  mut low : Bool
  mut first : Bool
  mut last : Bool
  mut negative : Bool
  mut display_x_axis : Bool
  mut display_hidden : Bool
  mut right_to_left : Bool
  mut color_series : SparklineColor?
  mut color_negative : SparklineColor?
  mut color_axis : SparklineColor?
  mut color_markers : SparklineColor?
  mut color_first : SparklineColor?
  mut color_last : SparklineColor?
  mut color_high : SparklineColor?
  mut color_low : SparklineColor?
} derive(Eq, Show)

///|
pub fn SparklineGroupOptions::new() -> SparklineGroupOptions {
  {
    display_empty_cells_as: "",
    date_axis: false,
    line_weight: None,
    manual_max: None,
    manual_min: None,
    markers: false,
    high: false,
    low: false,
    first: false,
    last: false,
    negative: false,
    display_x_axis: false,
    display_hidden: false,
    right_to_left: false,
    color_series: None,
    color_negative: None,
    color_axis: None,
    color_markers: None,
    color_first: None,
    color_last: None,
    color_high: None,
    color_low: None,
  }
}

///|
pub struct SparklineGroup {
  sparkline_type : SparklineType
  sparklines : Array[Sparkline]
  options : SparklineGroupOptions
}

///|
pub struct SparklineOptions {
  locations : Array[String]
  ranges : Array[String]
  mut sparkline_type : SparklineType
  mut style : Int
  mut weight : Double?
  mut date_axis : Bool
  mut markers : Bool
  mut high : Bool
  mut low : Bool
  mut first : Bool
  mut last : Bool
  mut negative : Bool
  mut axis : Bool
  mut hidden : Bool
  mut reverse : Bool
  mut series_color : String?
  mut negative_color : String?
  mut markers_color : String?
  mut first_color : String?
  mut last_color : String?
  mut high_color : String?
  mut low_color : String?
  mut manual_max : Int?
  mut manual_min : Int?
  mut empty_cells : String?
} derive(Eq, Show)

///|
pub fn SparklineOptions::new(
  locations : ArrayView[String],
  ranges : ArrayView[String],
) -> SparklineOptions raise XlsxError {
  if locations.length() == 0 || ranges.length() == 0 {
    raise XlsxError::InvalidSparkline(msg="sparkline inputs empty")
  }
  if locations.length() != ranges.length() {
    raise XlsxError::InvalidSparkline(msg="sparkline inputs mismatch")
  }
  let locs : Array[String] = []
  let rs : Array[String] = []
  for v in locations {
    locs.push(v)
  }
  for v in ranges {
    rs.push(v)
  }
  {
    locations: locs,
    ranges: rs,
    sparkline_type: SparklineType::Line,
    style: 0,
    weight: None,
    date_axis: false,
    markers: false,
    high: false,
    low: false,
    first: false,
    last: false,
    negative: false,
    axis: false,
    hidden: false,
    reverse: false,
    series_color: None,
    negative_color: None,
    markers_color: None,
    first_color: None,
    last_color: None,
    high_color: None,
    low_color: None,
    manual_max: None,
    manual_min: None,
    empty_cells: None,
  }
}

///|
pub fn SparklineOptions::set_type(
  self : SparklineOptions,
  sparkline_type : SparklineType,
) -> Unit {
  self.sparkline_type = sparkline_type
}

///|
pub fn SparklineOptions::set_style(
  self : SparklineOptions,
  style : Int,
) -> Unit {
  self.style = style
}

///|
pub fn SparklineOptions::set_weight(
  self : SparklineOptions,
  weight : Double,
) -> Unit raise XlsxError {
  if weight <= 0.0 {
    raise XlsxError::InvalidSparkline(msg="sparkline weight must be > 0")
  }
  self.weight = Some(weight)
}

///|
pub fn SparklineOptions::clear_weight(self : SparklineOptions) -> Unit {
  self.weight = None
}

///|
pub fn SparklineOptions::set_date_axis(
  self : SparklineOptions,
  date_axis : Bool,
) -> Unit {
  self.date_axis = date_axis
}

///|
pub fn SparklineOptions::set_markers(
  self : SparklineOptions,
  markers : Bool,
) -> Unit {
  self.markers = markers
}

///|
pub fn SparklineOptions::set_high(self : SparklineOptions, high : Bool) -> Unit {
  self.high = high
}

///|
pub fn SparklineOptions::set_low(self : SparklineOptions, low : Bool) -> Unit {
  self.low = low
}

///|
pub fn SparklineOptions::set_first(
  self : SparklineOptions,
  first : Bool,
) -> Unit {
  self.first = first
}

///|
pub fn SparklineOptions::set_last(self : SparklineOptions, last : Bool) -> Unit {
  self.last = last
}

///|
pub fn SparklineOptions::set_negative(
  self : SparklineOptions,
  negative : Bool,
) -> Unit {
  self.negative = negative
}

///|
pub fn SparklineOptions::set_axis(self : SparklineOptions, axis : Bool) -> Unit {
  self.axis = axis
}

///|
pub fn SparklineOptions::set_hidden(
  self : SparklineOptions,
  hidden : Bool,
) -> Unit {
  self.hidden = hidden
}

///|
pub fn SparklineOptions::set_reverse(
  self : SparklineOptions,
  reverse : Bool,
) -> Unit {
  self.reverse = reverse
}

///|
pub fn SparklineOptions::set_series_color(
  self : SparklineOptions,
  value : String,
) -> Unit {
  self.series_color = Some(value)
}

///|
pub fn SparklineOptions::clear_series_color(self : SparklineOptions) -> Unit {
  self.series_color = None
}

///|
pub fn SparklineOptions::set_negative_color(
  self : SparklineOptions,
  value : String,
) -> Unit {
  self.negative_color = Some(value)
}

///|
pub fn SparklineOptions::clear_negative_color(self : SparklineOptions) -> Unit {
  self.negative_color = None
}

///|
pub fn SparklineOptions::set_markers_color(
  self : SparklineOptions,
  value : String,
) -> Unit {
  self.markers_color = Some(value)
}

///|
pub fn SparklineOptions::clear_markers_color(self : SparklineOptions) -> Unit {
  self.markers_color = None
}

///|
pub fn SparklineOptions::set_first_color(
  self : SparklineOptions,
  value : String,
) -> Unit {
  self.first_color = Some(value)
}

///|
pub fn SparklineOptions::clear_first_color(self : SparklineOptions) -> Unit {
  self.first_color = None
}

///|
pub fn SparklineOptions::set_last_color(
  self : SparklineOptions,
  value : String,
) -> Unit {
  self.last_color = Some(value)
}

///|
pub fn SparklineOptions::clear_last_color(self : SparklineOptions) -> Unit {
  self.last_color = None
}

///|
pub fn SparklineOptions::set_high_color(
  self : SparklineOptions,
  value : String,
) -> Unit {
  self.high_color = Some(value)
}

///|
pub fn SparklineOptions::clear_high_color(self : SparklineOptions) -> Unit {
  self.high_color = None
}

///|
pub fn SparklineOptions::set_hight_color(
  self : SparklineOptions,
  value : String,
) -> Unit {
  self.high_color = Some(value)
}

///|
pub fn SparklineOptions::clear_hight_color(self : SparklineOptions) -> Unit {
  self.high_color = None
}

///|
pub fn SparklineOptions::set_low_color(
  self : SparklineOptions,
  value : String,
) -> Unit {
  self.low_color = Some(value)
}

///|
pub fn SparklineOptions::clear_low_color(self : SparklineOptions) -> Unit {
  self.low_color = None
}

///|
pub fn SparklineOptions::set_manual_max(
  self : SparklineOptions,
  max : Int,
) -> Unit {
  self.manual_max = Some(max)
}

///|
pub fn SparklineOptions::clear_manual_max(self : SparklineOptions) -> Unit {
  self.manual_max = None
}

///|
pub fn SparklineOptions::set_manual_min(
  self : SparklineOptions,
  min : Int,
) -> Unit {
  self.manual_min = Some(min)
}

///|
pub fn SparklineOptions::clear_manual_min(self : SparklineOptions) -> Unit {
  self.manual_min = None
}

///|
pub fn SparklineOptions::set_empty_cells(
  self : SparklineOptions,
  mode : StringView,
) -> Unit raise XlsxError {
  match mode.to_string() {
    "gap" | "zero" | "span" => self.empty_cells = Some(mode.to_string())
    _ => raise XlsxError::InvalidSparkline(msg="sparkline empty cells invalid")
  }
}

///|
pub fn SparklineOptions::clear_empty_cells(self : SparklineOptions) -> Unit {
  self.empty_cells = None
}

///|
let sparkline_ext_uri = "{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"

///|
let sparkline_ns_x14 = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"

///|
let sparkline_ns_xm = "http://schemas.microsoft.com/office/excel/2006/main"

///|
fn sparkline_type_to_string(kind : SparklineType) -> String {
  match kind {
    SparklineType::Column => "column"
    SparklineType::WinLoss => "stacked"
    SparklineType::Line => "line"
  }
}

///|
fn sparkline_type_from_string(value : StringView) -> SparklineType {
  match value.to_string() {
    "column" => SparklineType::Column
    "winLoss" => SparklineType::WinLoss
    "stacked" => SparklineType::WinLoss
    _ => SparklineType::Line
  }
}

///|
priv struct SparklinePreset {
  color_series : SparklineColor
  color_negative : SparklineColor
  color_markers : SparklineColor
  color_first : SparklineColor
  color_last : SparklineColor
  color_high : SparklineColor
  color_low : SparklineColor
}

///|
let sparkline_presets : Array[SparklinePreset] = [
  {
    color_series: SparklineColor::theme(4, tint=-0.499984740745262),
    color_negative: SparklineColor::theme(5),
    color_markers: SparklineColor::theme(4, tint=-0.499984740745262),
    color_first: SparklineColor::theme(4, tint=0.3999755851924192),
    color_last: SparklineColor::theme(4, tint=0.3999755851924192),
    color_high: SparklineColor::theme(4),
    color_low: SparklineColor::theme(4),
  }, // 0
  {
    color_series: SparklineColor::theme(4, tint=-0.499984740745262),
    color_negative: SparklineColor::theme(5),
    color_markers: SparklineColor::theme(4, tint=-0.499984740745262),
    color_first: SparklineColor::theme(4, tint=0.3999755851924192),
    color_last: SparklineColor::theme(4, tint=0.3999755851924192),
    color_high: SparklineColor::theme(4),
    color_low: SparklineColor::theme(4),
  }, // 1
  {
    color_series: SparklineColor::theme(5, tint=-0.499984740745262),
    color_negative: SparklineColor::theme(6),
    color_markers: SparklineColor::theme(5, tint=-0.499984740745262),
    color_first: SparklineColor::theme(5, tint=0.3999755851924192),
    color_last: SparklineColor::theme(5, tint=0.3999755851924192),
    color_high: SparklineColor::theme(5),
    color_low: SparklineColor::theme(5),
  }, // 2
  {
    color_series: SparklineColor::theme(6, tint=-0.499984740745262),
    color_negative: SparklineColor::theme(7),
    color_markers: SparklineColor::theme(6, tint=-0.499984740745262),
    color_first: SparklineColor::theme(6, tint=0.3999755851924192),
    color_last: SparklineColor::theme(6, tint=0.3999755851924192),
    color_high: SparklineColor::theme(6),
    color_low: SparklineColor::theme(6),
  }, // 3
  {
    color_series: SparklineColor::theme(7, tint=-0.499984740745262),
    color_negative: SparklineColor::theme(8),
    color_markers: SparklineColor::theme(7, tint=-0.499984740745262),
    color_first: SparklineColor::theme(7, tint=0.3999755851924192),
    color_last: SparklineColor::theme(7, tint=0.3999755851924192),
    color_high: SparklineColor::theme(7),
    color_low: SparklineColor::theme(7),
  }, // 4
  {
    color_series: SparklineColor::theme(8, tint=-0.499984740745262),
    color_negative: SparklineColor::theme(9),
    color_markers: SparklineColor::theme(8, tint=-0.499984740745262),
    color_first: SparklineColor::theme(8, tint=0.3999755851924192),
    color_last: SparklineColor::theme(8, tint=0.3999755851924192),
    color_high: SparklineColor::theme(8),
    color_low: SparklineColor::theme(8),
  }, // 5
  {
    color_series: SparklineColor::theme(9, tint=-0.499984740745262),
    color_negative: SparklineColor::theme(4),
    color_markers: SparklineColor::theme(9, tint=-0.499984740745262),
    color_first: SparklineColor::theme(9, tint=0.3999755851924192),
    color_last: SparklineColor::theme(9, tint=0.3999755851924192),
    color_high: SparklineColor::theme(9),
    color_low: SparklineColor::theme(9),
  }, // 6
  {
    color_series: SparklineColor::theme(4, tint=-0.249977111117893),
    color_negative: SparklineColor::theme(5),
    color_markers: SparklineColor::theme(5, tint=-0.249977111117893),
    color_first: SparklineColor::theme(5, tint=-0.249977111117893),
    color_last: SparklineColor::theme(5, tint=-0.249977111117893),
    color_high: SparklineColor::theme(5),
    color_low: SparklineColor::theme(5),
  }, // 7
  {
    color_series: SparklineColor::theme(5, tint=-0.249977111117893),
    color_negative: SparklineColor::theme(6),
    color_markers: SparklineColor::theme(6, tint=-0.249977111117893),
    color_first: SparklineColor::theme(6, tint=-0.249977111117893),
    color_last: SparklineColor::theme(6, tint=-0.249977111117893),
    color_high: SparklineColor::theme(6, tint=-0.249977111117893),
    color_low: SparklineColor::theme(6, tint=-0.249977111117893),
  }, // 8
  {
    color_series: SparklineColor::theme(6, tint=-0.249977111117893),
    color_negative: SparklineColor::theme(7),
    color_markers: SparklineColor::theme(7, tint=-0.249977111117893),
    color_first: SparklineColor::theme(7, tint=-0.249977111117893),
    color_last: SparklineColor::theme(7, tint=-0.249977111117893),
    color_high: SparklineColor::theme(7, tint=-0.249977111117893),
    color_low: SparklineColor::theme(7, tint=-0.249977111117893),
  }, // 9
  {
    color_series: SparklineColor::theme(7, tint=-0.249977111117893),
    color_negative: SparklineColor::theme(8),
    color_markers: SparklineColor::theme(8, tint=-0.249977111117893),
    color_first: SparklineColor::theme(8, tint=-0.249977111117893),
    color_last: SparklineColor::theme(8, tint=-0.249977111117893),
    color_high: SparklineColor::theme(8, tint=-0.249977111117893),
    color_low: SparklineColor::theme(8, tint=-0.249977111117893),
  }, // 10
  {
    color_series: SparklineColor::theme(8, tint=-0.249977111117893),
    color_negative: SparklineColor::theme(9),
    color_markers: SparklineColor::theme(9, tint=-0.249977111117893),
    color_first: SparklineColor::theme(9, tint=-0.249977111117893),
    color_last: SparklineColor::theme(9, tint=-0.249977111117893),
    color_high: SparklineColor::theme(9, tint=-0.249977111117893),
    color_low: SparklineColor::theme(9, tint=-0.249977111117893),
  }, // 11
  {
    color_series: SparklineColor::theme(9, tint=-0.249977111117893),
    color_negative: SparklineColor::theme(4),
    color_markers: SparklineColor::theme(4, tint=-0.249977111117893),
    color_first: SparklineColor::theme(4, tint=-0.249977111117893),
    color_last: SparklineColor::theme(4, tint=-0.249977111117893),
    color_high: SparklineColor::theme(4, tint=-0.249977111117893),
    color_low: SparklineColor::theme(4, tint=-0.249977111117893),
  }, // 12
  {
    color_series: SparklineColor::theme(4),
    color_negative: SparklineColor::theme(5),
    color_markers: SparklineColor::theme(4, tint=-0.249977111117893),
    color_first: SparklineColor::theme(4, tint=-0.249977111117893),
    color_last: SparklineColor::theme(4, tint=-0.249977111117893),
    color_high: SparklineColor::theme(4, tint=-0.249977111117893),
    color_low: SparklineColor::theme(4, tint=-0.249977111117893),
  }, // 13
  {
    color_series: SparklineColor::theme(5),
    color_negative: SparklineColor::theme(6),
    color_markers: SparklineColor::theme(5, tint=-0.249977111117893),
    color_first: SparklineColor::theme(5, tint=-0.249977111117893),
    color_last: SparklineColor::theme(5, tint=-0.249977111117893),
    color_high: SparklineColor::theme(5, tint=-0.249977111117893),
    color_low: SparklineColor::theme(5, tint=-0.249977111117893),
  }, // 14
  {
    color_series: SparklineColor::theme(6),
    color_negative: SparklineColor::theme(7),
    color_markers: SparklineColor::theme(6, tint=-0.249977111117893),
    color_first: SparklineColor::theme(6, tint=-0.249977111117893),
    color_last: SparklineColor::theme(6, tint=-0.249977111117893),
    color_high: SparklineColor::theme(6, tint=-0.249977111117893),
    color_low: SparklineColor::theme(6, tint=-0.249977111117893),
  }, // 15
  {
    color_series: SparklineColor::theme(7),
    color_negative: SparklineColor::theme(8),
    color_markers: SparklineColor::theme(7, tint=-0.249977111117893),
    color_first: SparklineColor::theme(7, tint=-0.249977111117893),
    color_last: SparklineColor::theme(7, tint=-0.249977111117893),
    color_high: SparklineColor::theme(7, tint=-0.249977111117893),
    color_low: SparklineColor::theme(7, tint=-0.249977111117893),
  }, // 16
  {
    color_series: SparklineColor::theme(8),
    color_negative: SparklineColor::theme(9),
    color_markers: SparklineColor::theme(8, tint=-0.249977111117893),
    color_first: SparklineColor::theme(8, tint=-0.249977111117893),
    color_last: SparklineColor::theme(8, tint=-0.249977111117893),
    color_high: SparklineColor::theme(8, tint=-0.249977111117893),
    color_low: SparklineColor::theme(8, tint=-0.249977111117893),
  }, // 17
  {
    color_series: SparklineColor::theme(9),
    color_negative: SparklineColor::theme(4),
    color_markers: SparklineColor::theme(9, tint=-0.249977111117893),
    color_first: SparklineColor::theme(9, tint=-0.249977111117893),
    color_last: SparklineColor::theme(9, tint=-0.249977111117893),
    color_high: SparklineColor::theme(9, tint=-0.249977111117893),
    color_low: SparklineColor::theme(9, tint=-0.249977111117893),
  }, // 18
  {
    color_series: SparklineColor::theme(4, tint=0.3999755851924192),
    color_negative: SparklineColor::theme(0, tint=-0.499984740745262),
    color_markers: SparklineColor::theme(4, tint=0.7999816888943144),
    color_first: SparklineColor::theme(4, tint=-0.249977111117893),
    color_last: SparklineColor::theme(4, tint=-0.249977111117893),
    color_high: SparklineColor::theme(4, tint=-0.499984740745262),
    color_low: SparklineColor::theme(4, tint=-0.499984740745262),
  }, // 19
  {
    color_series: SparklineColor::theme(5, tint=0.3999755851924192),
    color_negative: SparklineColor::theme(0, tint=-0.499984740745262),
    color_markers: SparklineColor::theme(5, tint=0.7999816888943144),
    color_first: SparklineColor::theme(5, tint=-0.249977111117893),
    color_last: SparklineColor::theme(5, tint=-0.249977111117893),
    color_high: SparklineColor::theme(5, tint=-0.499984740745262),
    color_low: SparklineColor::theme(5, tint=-0.499984740745262),
  }, // 20
  {
    color_series: SparklineColor::theme(6, tint=0.3999755851924192),
    color_negative: SparklineColor::theme(0, tint=-0.499984740745262),
    color_markers: SparklineColor::theme(6, tint=0.7999816888943144),
    color_first: SparklineColor::theme(6, tint=-0.249977111117893),
    color_last: SparklineColor::theme(6, tint=-0.249977111117893),
    color_high: SparklineColor::theme(6, tint=-0.499984740745262),
    color_low: SparklineColor::theme(6, tint=-0.499984740745262),
  }, // 21
  {
    color_series: SparklineColor::theme(7, tint=0.3999755851924192),
    color_negative: SparklineColor::theme(0, tint=-0.499984740745262),
    color_markers: SparklineColor::theme(7, tint=0.7999816888943144),
    color_first: SparklineColor::theme(7, tint=-0.249977111117893),
    color_last: SparklineColor::theme(7, tint=-0.249977111117893),
    color_high: SparklineColor::theme(7, tint=-0.499984740745262),
    color_low: SparklineColor::theme(7, tint=-0.499984740745262),
  }, // 22
  {
    color_series: SparklineColor::theme(8, tint=0.3999755851924192),
    color_negative: SparklineColor::theme(0, tint=-0.499984740745262),
    color_markers: SparklineColor::theme(8, tint=0.7999816888943144),
    color_first: SparklineColor::theme(8, tint=-0.249977111117893),
    color_last: SparklineColor::theme(8, tint=-0.249977111117893),
    color_high: SparklineColor::theme(8, tint=-0.499984740745262),
    color_low: SparklineColor::theme(8, tint=-0.499984740745262),
  }, // 23
  {
    color_series: SparklineColor::theme(9, tint=0.3999755851924192),
    color_negative: SparklineColor::theme(0, tint=-0.499984740745262),
    color_markers: SparklineColor::theme(9, tint=0.7999816888943144),
    color_first: SparklineColor::theme(9, tint=-0.249977111117893),
    color_last: SparklineColor::theme(9, tint=-0.249977111117893),
    color_high: SparklineColor::theme(9, tint=-0.499984740745262),
    color_low: SparklineColor::theme(9, tint=-0.499984740745262),
  }, // 24
  {
    color_series: SparklineColor::theme(1, tint=0.499984740745262),
    color_negative: SparklineColor::theme(1, tint=0.249977111117893),
    color_markers: SparklineColor::theme(1, tint=0.249977111117893),
    color_first: SparklineColor::theme(1, tint=0.249977111117893),
    color_last: SparklineColor::theme(1, tint=0.249977111117893),
    color_high: SparklineColor::theme(1, tint=0.249977111117893),
    color_low: SparklineColor::theme(1, tint=0.249977111117893),
  }, // 25
  {
    color_series: SparklineColor::theme(1, tint=0.3499862666707358),
    color_negative: SparklineColor::theme(0, tint=0.249977111117893),
    color_markers: SparklineColor::theme(0, tint=0.249977111117893),
    color_first: SparklineColor::theme(0, tint=0.249977111117893),
    color_last: SparklineColor::theme(0, tint=0.249977111117893),
    color_high: SparklineColor::theme(0, tint=0.249977111117893),
    color_low: SparklineColor::theme(0, tint=0.249977111117893),
  }, // 26
  {
    color_series: { rgb: Some("FF323232"), theme: None, tint: None },
    color_negative: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_markers: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_first: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_last: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_high: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_low: { rgb: Some("FFD00000"), theme: None, tint: None },
  }, // 27
  {
    color_series: { rgb: Some("FF000000"), theme: None, tint: None },
    color_negative: { rgb: Some("FF0070C0"), theme: None, tint: None },
    color_markers: { rgb: Some("FF0070C0"), theme: None, tint: None },
    color_first: { rgb: Some("FF0070C0"), theme: None, tint: None },
    color_last: { rgb: Some("FF0070C0"), theme: None, tint: None },
    color_high: { rgb: Some("FF0070C0"), theme: None, tint: None },
    color_low: { rgb: Some("FF0070C0"), theme: None, tint: None },
  }, // 28
  {
    color_series: { rgb: Some("FF376092"), theme: None, tint: None },
    color_negative: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_markers: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_first: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_last: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_high: { rgb: Some("FFD00000"), theme: None, tint: None },
    color_low: { rgb: Some("FFD00000"), theme: None, tint: None },
  }, // 29
  {
    color_series: { rgb: Some("FF0070C0"), theme: None, tint: None },
    color_negative: { rgb: Some("FF000000"), theme: None, tint: None },
    color_markers: { rgb: Some("FF000000"), theme: None, tint: None },
    color_first: { rgb: Some("FF000000"), theme: None, tint: None },
    color_last: { rgb: Some("FF000000"), theme: None, tint: None },
    color_high: { rgb: Some("FF000000"), theme: None, tint: None },
    color_low: { rgb: Some("FF000000"), theme: None, tint: None },
  }, // 30
  {
    color_series: { rgb: Some("FF5F5F5F"), theme: None, tint: None },
    color_negative: { rgb: Some("FFFFB620"), theme: None, tint: None },
    color_markers: { rgb: Some("FFD70077"), theme: None, tint: None },
    color_first: { rgb: Some("FF5687C2"), theme: None, tint: None },
    color_last: { rgb: Some("FF359CEB"), theme: None, tint: None },
    color_high: { rgb: Some("FF56BE79"), theme: None, tint: None },
    color_low: { rgb: Some("FFFF5055"), theme: None, tint: None },
  }, // 31
  {
    color_series: { rgb: Some("FF5687C2"), theme: None, tint: None },
    color_negative: { rgb: Some("FFFFB620"), theme: None, tint: None },
    color_markers: { rgb: Some("FFD70077"), theme: None, tint: None },
    color_first: { rgb: Some("FF777777"), theme: None, tint: None },
    color_last: { rgb: Some("FF359CEB"), theme: None, tint: None },
    color_high: { rgb: Some("FF56BE79"), theme: None, tint: None },
    color_low: { rgb: Some("FFFF5055"), theme: None, tint: None },
  }, // 32
  {
    color_series: { rgb: Some("FFC6EFCE"), theme: None, tint: None },
    color_negative: { rgb: Some("FFFFC7CE"), theme: None, tint: None },
    color_markers: { rgb: Some("FF8CADD6"), theme: None, tint: None },
    color_first: { rgb: Some("FFFFDC47"), theme: None, tint: None },
    color_last: { rgb: Some("FFFFEB9C"), theme: None, tint: None },
    color_high: { rgb: Some("FF60D276"), theme: None, tint: None },
    color_low: { rgb: Some("FFFF5367"), theme: None, tint: None },
  }, // 33
  {
    color_series: { rgb: Some("FF00B050"), theme: None, tint: None },
    color_negative: { rgb: Some("FFFF0000"), theme: None, tint: None },
    color_markers: { rgb: Some("FF0070C0"), theme: None, tint: None },
    color_first: { rgb: Some("FFFFC000"), theme: None, tint: None },
    color_last: { rgb: Some("FFFFC000"), theme: None, tint: None },
    color_high: { rgb: Some("FF00B050"), theme: None, tint: None },
    color_low: { rgb: Some("FFFF0000"), theme: None, tint: None },
  }, // 34
  {
    color_series: SparklineColor::theme(3),
    color_negative: SparklineColor::theme(9),
    color_markers: SparklineColor::theme(8),
    color_first: SparklineColor::theme(4),
    color_last: SparklineColor::theme(5),
    color_high: SparklineColor::theme(6),
    color_low: SparklineColor::theme(7),
  }, // 35
]

///|
fn sparkline_preset(style : Int) -> SparklinePreset raise XlsxError {
  if style < 0 || style > 35 {
    raise XlsxError::InvalidSparkline(msg="sparkline style out of range")
  }
  sparkline_presets[style]
}

///|
fn write_sparkline_color_xml(
  sb : StringBuilder,
  tag_name : StringView,
  color : SparklineColor?,
) -> Unit {
  match color {
    None => ()
    Some(value) => {
      sb.write_view("          <x14:")
      sb.write_view(tag_name)
      match value.rgb {
        Some(rgb) => {
          sb.write_view(" rgb=\"")
          sb.write_view(escape_xml_attr(rgb))
          sb.write_view("\"")
        }
        None => ()
      }
      match value.theme {
        Some(t) => sb.write_view(" theme=\"\{t}\"")
        None => ()
      }
      match value.tint {
        Some(t) => sb.write_view(" tint=\"\{t}\"")
        None => ()
      }
      sb.write_view("/>\n")
    }
  }
}

///|
fn write_sparkline_ext_xml(groups : ArrayView[SparklineGroup]) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <extLst>\n")
  sb.write_view(write_sparkline_ext_block_xml(groups))
  sb.write_view("  </extLst>\n")
  sb.to_string()
}

///|
fn write_sparkline_ext_block_xml(groups : ArrayView[SparklineGroup]) -> String {
  let sb = StringBuilder::new()
  sb.write_view("    <ext uri=\"")
  sb.write_view(sparkline_ext_uri)
  sb.write_view("\">\n")
  sb.write_view("      <x14:sparklineGroups xmlns:x14=\"")
  sb.write_view(sparkline_ns_x14)
  sb.write_view("\" xmlns:xm=\"")
  sb.write_view(sparkline_ns_xm)
  sb.write_view("\">\n")
  for group in groups {
    sb.write_view("        <x14:sparklineGroup type=\"")
    sb.write_view(sparkline_type_to_string(group.sparkline_type))
    sb.write_view("\"")
    if group.options.display_empty_cells_as != "" {
      sb.write_view(" displayEmptyCellsAs=\"")
      sb.write_view(escape_xml_attr(group.options.display_empty_cells_as))
      sb.write_view("\"")
    }
    if group.options.date_axis {
      sb.write_view(" dateAxis=\"\{bool_attr(true)}\"")
    }
    match group.options.line_weight {
      Some(value) => sb.write_view(" lineWeight=\"\{value}\"")
      None => ()
    }
    match group.options.manual_max {
      Some(value) => sb.write_view(" manualMax=\"\{value}\"")
      None => ()
    }
    match group.options.manual_min {
      Some(value) => sb.write_view(" manualMin=\"\{value}\"")
      None => ()
    }
    if group.options.markers {
      sb.write_view(" markers=\"\{bool_attr(true)}\"")
    }
    if group.options.high {
      sb.write_view(" high=\"\{bool_attr(true)}\"")
    }
    if group.options.low {
      sb.write_view(" low=\"\{bool_attr(true)}\"")
    }
    if group.options.first {
      sb.write_view(" first=\"\{bool_attr(true)}\"")
    }
    if group.options.last {
      sb.write_view(" last=\"\{bool_attr(true)}\"")
    }
    if group.options.negative {
      sb.write_view(" negative=\"\{bool_attr(true)}\"")
    }
    if group.options.display_x_axis {
      sb.write_view(" displayXAxis=\"\{bool_attr(true)}\"")
    }
    if group.options.display_hidden {
      sb.write_view(" displayHidden=\"\{bool_attr(true)}\"")
    }
    if group.options.right_to_left {
      sb.write_view(" rightToLeft=\"\{bool_attr(true)}\"")
    }
    sb.write_view(">\n")
    write_sparkline_color_xml(sb, "colorSeries", group.options.color_series)
    write_sparkline_color_xml(sb, "colorNegative", group.options.color_negative)
    write_sparkline_color_xml(sb, "colorAxis", group.options.color_axis)
    write_sparkline_color_xml(sb, "colorMarkers", group.options.color_markers)
    write_sparkline_color_xml(sb, "colorFirst", group.options.color_first)
    write_sparkline_color_xml(sb, "colorLast", group.options.color_last)
    write_sparkline_color_xml(sb, "colorHigh", group.options.color_high)
    write_sparkline_color_xml(sb, "colorLow", group.options.color_low)
    sb.write_view("          <x14:sparklines>\n")
    for sparkline in group.sparklines {
      sb.write_view("            <x14:sparkline>\n")
      sb.write_view("              <xm:f>")
      sb.write_view(escape_xml_text(sparkline.range_ref))
      sb.write_view("</xm:f>\n")
      sb.write_view("              <xm:sqref>")
      sb.write_view(escape_xml_text(sparkline.location))
      sb.write_view("</xm:sqref>\n")
      sb.write_view("            </x14:sparkline>\n")
    }
    sb.write_view("          </x14:sparklines>\n")
    sb.write_view("        </x14:sparklineGroup>\n")
  }
  sb.write_view("      </x14:sparklineGroups>\n")
  sb.write_view("    </ext>\n")
  sb.to_string()
}

///|
fn parse_sparkline_color(tag : StringView) -> SparklineColor? raise XlsxError {
  let rgb = attr_value(tag, "rgb")
  let theme = attr_value(tag, "theme")
  let tint = attr_value(tag, "tint")
  let parsed_rgb = match rgb {
    Some(v) => Some(v.to_string())
    None => None
  }
  let parsed_theme = match theme {
    Some(v) => Some(@strconv.parse_int(v.to_string(), base=10) catch { _ => 0 })
    None => None
  }
  let parsed_tint = match tint {
    Some(v) => Some(@strconv.parse_double(v.to_string()) catch { _ => 0.0 })
    None => None
  }
  if parsed_rgb is None && parsed_theme is None {
    None
  } else {
    Some({ rgb: parsed_rgb, theme: parsed_theme, tint: parsed_tint })
  }
}

///|
fn find_sparkline_color_in_body(
  body : StringView,
  tag_name : StringView,
) -> SparklineColor? raise XlsxError {
  let text = body.to_string()
  let open = "<x14:" + tag_name.to_string()
  let start = match text.find(open) {
    Some(pos) => pos
    None => return None
  }
  let rest = text[start:] catch { _ => return None }
  let end = match rest.find(">") {
    Some(pos) => pos
    None => return None
  }
  let tag = rest[:end] catch { _ => return None }
  parse_sparkline_color(tag)
}

///|
fn parse_sparkline_groups(
  xml : StringView,
) -> Array[SparklineGroup] raise XlsxError {
  let groups : Array[SparklineGroup] = []
  let mut first = true
  for chunk in xml.split("<x14:sparklineGroup") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    if text.has_prefix("s") {
      continue
    }
    let tag_end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="sparklineGroup tag not closed")
    }
    let tag = text[:tag_end] catch {
        _ => raise XlsxError::InvalidXml(msg="sparklineGroup tag invalid")
      }
    let group_end = match text.find("</x14:sparklineGroup>") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="sparklineGroup end missing")
    }
    let body = text[tag_end + 1:group_end] catch {
        _ => raise XlsxError::InvalidXml(msg="sparklineGroup body invalid")
      }
    let kind = match attr_value(tag, "type") {
      Some(value) => sparkline_type_from_string(value)
      None => SparklineType::Line
    }
    let options = SparklineGroupOptions::new()
    match attr_value(tag, "displayEmptyCellsAs") {
      Some(value) => options.display_empty_cells_as = value.to_string()
      None => ()
    }
    match attr_value(tag, "dateAxis") {
      Some(value) => options.date_axis = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "lineWeight") {
      Some(value) =>
        options.line_weight = Some(
          @strconv.parse_double(value.to_string()) catch {
            _ => raise XlsxError::InvalidXml(msg="sparkline lineWeight invalid")
          },
        )
      None => ()
    }
    match attr_value(tag, "manualMax") {
      Some(value) =>
        options.manual_max = Some(
          @strconv.parse_int(value.to_string(), base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="sparkline manualMax invalid")
          },
        )
      None => ()
    }
    match attr_value(tag, "manualMin") {
      Some(value) =>
        options.manual_min = Some(
          @strconv.parse_int(value.to_string(), base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="sparkline manualMin invalid")
          },
        )
      None => ()
    }
    match attr_value(tag, "markers") {
      Some(value) => options.markers = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "high") {
      Some(value) => options.high = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "low") {
      Some(value) => options.low = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "first") {
      Some(value) => options.first = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "last") {
      Some(value) => options.last = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "negative") {
      Some(value) => options.negative = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "displayXAxis") {
      Some(value) => options.display_x_axis = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "displayHidden") {
      Some(value) => options.display_hidden = parse_bool_attr(value)
      None => ()
    }
    match attr_value(tag, "rightToLeft") {
      Some(value) => options.right_to_left = parse_bool_attr(value)
      None => ()
    }
    options.color_series = find_sparkline_color_in_body(body, "colorSeries") catch {
      _ => None
    }
    options.color_negative = find_sparkline_color_in_body(body, "colorNegative") catch {
      _ => None
    }
    options.color_axis = find_sparkline_color_in_body(body, "colorAxis") catch {
      _ => None
    }
    options.color_markers = find_sparkline_color_in_body(body, "colorMarkers") catch {
      _ => None
    }
    options.color_first = find_sparkline_color_in_body(body, "colorFirst") catch {
      _ => None
    }
    options.color_last = find_sparkline_color_in_body(body, "colorLast") catch {
      _ => None
    }
    options.color_high = find_sparkline_color_in_body(body, "colorHigh") catch {
      _ => None
    }
    options.color_low = find_sparkline_color_in_body(body, "colorLow") catch {
      _ => None
    }
    let sparklines : Array[Sparkline] = []
    let mut sparkline_first = true
    for spark_chunk in body.split("<x14:sparkline>") {
      if sparkline_first {
        sparkline_first = false
        continue
      }
      let spark_text = spark_chunk.to_string()
      let spark_end = match spark_text.find("</x14:sparkline>") {
        Some(pos) => pos
        None => raise XlsxError::InvalidXml(msg="sparkline end missing")
      }
      let spark_body = spark_text[:spark_end] catch {
          _ => raise XlsxError::InvalidXml(msg="sparkline body invalid")
        }
      let range = match spark_body.find("<xm:f>") {
        Some(pos) => {
          let rest = spark_body[pos + 6:] catch {
              _ => raise XlsxError::InvalidXml(msg="sparkline range invalid")
            }
          let end = match rest.find("</xm:f>") {
            Some(value) => value
            None =>
              raise XlsxError::InvalidXml(msg="sparkline range end missing")
          }
          unescape_xml_text(try! rest[:end])
        }
        None => raise XlsxError::InvalidXml(msg="sparkline range missing")
      }
      let location = match spark_body.find("<xm:sqref>") {
        Some(pos) => {
          let rest = spark_body[pos + 10:] catch {
              _ => raise XlsxError::InvalidXml(msg="sparkline location invalid")
            }
          let end = match rest.find("</xm:sqref>") {
            Some(value) => value
            None =>
              raise XlsxError::InvalidXml(msg="sparkline location end missing")
          }
          unescape_xml_text(try! rest[:end])
        }
        None => raise XlsxError::InvalidXml(msg="sparkline location missing")
      }
      let (row, col) = cell_ref_to_rc(location)
      let canonical_loc = cell_ref_from(row, col)
      let normalized_range = normalize_range_ref(range)
      sparklines.push({ range_ref: normalized_range, location: canonical_loc })
    }
    if sparklines.length() > 0 {
      groups.push({ sparkline_type: kind, sparklines, options })
    }
  }
  groups
}

///|
fn sparkline_group_options_from_sparkline_options(
  opts : SparklineOptions,
) -> SparklineGroupOptions raise XlsxError {
  let preset = sparkline_preset(opts.style)
  let group_opts = SparklineGroupOptions::new()
  group_opts.display_empty_cells_as = match opts.empty_cells {
    Some(value) => value
    None => "gap"
  }
  group_opts.date_axis = opts.date_axis
  group_opts.line_weight = opts.weight
  group_opts.manual_max = opts.manual_max
  group_opts.manual_min = opts.manual_min
  group_opts.high = opts.high
  group_opts.low = opts.low
  group_opts.first = opts.first
  group_opts.last = opts.last
  group_opts.negative = opts.negative
  group_opts.display_x_axis = opts.axis
  group_opts.markers = opts.markers
  group_opts.display_hidden = opts.hidden
  group_opts.right_to_left = opts.reverse
  group_opts.color_axis = Some({
    rgb: Some("FF000000"),
    theme: None,
    tint: None,
  })
  group_opts.color_series = Some(preset.color_series)
  group_opts.color_negative = Some(preset.color_negative)
  group_opts.color_markers = Some(preset.color_markers)
  group_opts.color_first = Some(preset.color_first)
  group_opts.color_last = Some(preset.color_last)
  group_opts.color_high = Some(preset.color_high)
  group_opts.color_low = Some(preset.color_low)
  match opts.series_color {
    Some(value) => group_opts.color_series = Some(SparklineColor::rgb(value))
    None => ()
  }
  match opts.negative_color {
    Some(value) => group_opts.color_negative = Some(SparklineColor::rgb(value))
    None => ()
  }
  match opts.markers_color {
    Some(value) => group_opts.color_markers = Some(SparklineColor::rgb(value))
    None => ()
  }
  match opts.first_color {
    Some(value) => group_opts.color_first = Some(SparklineColor::rgb(value))
    None => ()
  }
  match opts.last_color {
    Some(value) => group_opts.color_last = Some(SparklineColor::rgb(value))
    None => ()
  }
  match opts.high_color {
    Some(value) => group_opts.color_high = Some(SparklineColor::rgb(value))
    None => ()
  }
  match opts.low_color {
    Some(value) => group_opts.color_low = Some(SparklineColor::rgb(value))
    None => ()
  }
  group_opts
}

///|
fn build_sparklines(
  locations : ArrayView[String],
  ranges : ArrayView[String],
) -> Array[Sparkline] raise XlsxError {
  let sparklines : Array[Sparkline] = []
  for i, location in locations {
    let (row, col) = cell_ref_to_rc(location)
    let canonical_loc = cell_ref_from(row, col)
    let normalized_range = normalize_range_ref(ranges[i])
    sparklines.push({ range_ref: normalized_range, location: canonical_loc })
  }
  sparklines
}

///|
fn build_sparkline_group_from_options(
  opts : SparklineOptions,
) -> SparklineGroup raise XlsxError {
  let sparklines = build_sparklines(opts.locations, opts.ranges)
  let options = sparkline_group_options_from_sparkline_options(opts)
  { sparkline_type: opts.sparkline_type, sparklines, options }
}
