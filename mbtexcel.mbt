///|
pub fn new_workbook(
  options? : @xlsx.Options = @xlsx.Options::new(),
) -> @xlsx.Workbook {
  @xlsx.Workbook::new(options~)
}

///|
pub fn new_file(
  options? : @xlsx.Options = @xlsx.Options::new(),
) -> @xlsx.Workbook {
  let workbook = @xlsx.Workbook::new(options~)
  ignore(try! workbook.add_sheet("Sheet1"))
  workbook
}

///|
pub fn new_data_validation(allow_blank : Bool) -> @xlsx.DataValidation {
  @xlsx.DataValidation::new(allow_blank)
}

///|
pub fn split_cell_name(
  cell : StringView,
) -> (String, Int) raise @xlsx.XlsxError {
  @xlsx.split_cell_name(cell)
}

///|
pub fn join_cell_name(
  col : StringView,
  row : Int,
) -> String raise @xlsx.XlsxError {
  @xlsx.join_cell_name(col, row)
}

///|
pub fn cell_name_to_coordinates(
  cell : StringView,
) -> (Int, Int) raise @xlsx.XlsxError {
  @xlsx.cell_name_to_coordinates(cell)
}

///|
pub fn coordinates_to_cell_name(
  col : Int,
  row : Int,
  abs? : Bool = false,
) -> String raise @xlsx.XlsxError {
  @xlsx.coordinates_to_cell_name(col, row, abs~)
}

///|
pub fn read(
  bytes : BytesView,
  options? : @xlsx.Options = @xlsx.Options::new(),
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) => @xlsx.read(bytes, options~, transcoder=value)
    None => @xlsx.read(bytes, options~)
  }
}

///|
pub fn read_with_password(
  bytes : BytesView,
  password : String,
  options? : @xlsx.Options = @xlsx.Options::new(),
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) =>
      @xlsx.read_with_password(bytes, password, options~, transcoder=value)
    None => @xlsx.read_with_password(bytes, password, options~)
  }
}

///|
pub fn write(workbook : @xlsx.Workbook) -> Bytes raise @xlsx.XlsxError {
  @xlsx.write(workbook)
}

///|
pub fn write_with_password(
  workbook : @xlsx.Workbook,
  password : String,
) -> Bytes raise @xlsx.XlsxError {
  @xlsx.write_with_password(workbook, password)
}

///|
pub fn encrypt(
  raw : BytesView,
  options? : @xlsx.Options = @xlsx.Options::new(),
) -> Bytes raise @xlsx.XlsxError {
  @xlsx.encrypt(raw, options~)
}

///|
pub fn decrypt(
  raw : BytesView,
  options? : @xlsx.Options = @xlsx.Options::new(),
) -> Bytes raise @xlsx.XlsxError {
  @xlsx.decrypt(raw, options~)
}

///|
pub fn rgb_to_hsl(r : Byte, g : Byte, b : Byte) -> (Double, Double, Double) {
  @xlsx.rgb_to_hsl(r, g, b)
}

///|
pub fn hsl_to_rgb(h : Double, s : Double, l : Double) -> (Byte, Byte, Byte) {
  @xlsx.hsl_to_rgb(h, s, l)
}

///|
pub fn theme_color(base_color : String, tint : Double) -> String {
  @xlsx.theme_color(base_color, tint)
}

///|
pub fn excel_date_to_time(
  excel_date : Double,
  use_1904_format? : Bool = false,
) -> @time.ZonedDateTime raise @xlsx.XlsxError {
  @xlsx.excel_date_to_time(excel_date, use_1904_format~)
}

///|
pub async fn open_file(
  path : String,
  password? : String = "",
  options? : @xlsx.Options = @xlsx.Options::new(),
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) => @xlsx.open_file(path, password~, options~, transcoder=value)
    None => @xlsx.open_file(path, password~, options~)
  }
}

///|
pub async fn[R : @async/io.Reader] open_reader(
  reader : R,
  password? : String = "",
  options? : @xlsx.Options = @xlsx.Options::new(),
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) =>
      @xlsx.open_reader(reader, password~, options~, transcoder=value)
    None => @xlsx.open_reader(reader, password~, options~)
  }
}

///|
pub async fn[R : @async/io.Reader] read_zip_reader(
  reader : R,
  password? : String = "",
  options? : @xlsx.Options = @xlsx.Options::new(),
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) =>
      @xlsx.read_zip_reader(reader, password~, options~, transcoder=value)
    None => @xlsx.read_zip_reader(reader, password~, options~)
  }
}
