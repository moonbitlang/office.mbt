///|
/// Creates a new empty workbook without any sheets.
///
/// Use `add_sheet` on the returned workbook to add worksheets.
///
/// # Example
/// ```mbt nocheck
/// let wb = new_workbook()
/// let sheet = wb.add_sheet("Data")
/// ```
pub fn new_workbook(
  options? : @xlsx.Options = @xlsx.Options::new(),
) -> @xlsx.Workbook {
  @xlsx.Workbook::new(options~)
}

///|
/// Creates a new workbook with a default sheet named "Sheet1".
///
/// This is a convenience function for the common case of creating
/// a workbook with one initial worksheet.
///
/// # Example
/// ```mbt nocheck
/// let wb = new_file()
/// wb.set_cell("Sheet1", "A1", "Hello")
/// ```
pub fn new_file(
  options? : @xlsx.Options = @xlsx.Options::new(),
) -> @xlsx.Workbook {
  let workbook = @xlsx.Workbook::new(options~)
  ignore(try! workbook.add_sheet("Sheet1"))
  workbook
}

///|
/// Creates a new data validation object.
///
/// Data validations restrict what users can enter in cells.
///
/// # Parameters
/// - `allow_blank`: Whether empty cells are considered valid
///
/// # Example
/// ```mbt nocheck
/// let dv = new_data_validation(true)
/// dv.set_drop_list(["Option1", "Option2", "Option3"])
/// dv.set_sqref("A1:A100")
/// sheet.add_data_validation(dv)
/// ```
pub fn new_data_validation(allow_blank : Bool) -> @xlsx.DataValidation {
  @xlsx.DataValidation::new(allow_blank)
}

///|
/// Splits a cell reference into column name and row number.
///
/// # Parameters
/// - `cell`: Cell reference like "A1", "AB123", "$C$5"
///
/// # Returns
/// Tuple of (column_name, row_number) where row is 1-indexed
///
/// # Example
/// ```mbt nocheck
/// let (col, row) = split_cell_name("AB123")
/// // col = "AB", row = 123
/// ```
pub fn split_cell_name(
  cell : StringView,
) -> (String, Int) raise @xlsx.XlsxError {
  @xlsx.split_cell_name(cell)
}

///|
/// Joins column name and row number into a cell reference.
///
/// # Parameters
/// - `col`: Column name like "A", "AB", "XFD"
/// - `row`: Row number (1-indexed)
///
/// # Returns
/// Cell reference string like "A1", "AB123"
///
/// # Example
/// ```mbt nocheck
/// let ref = join_cell_name("AB", 123)
/// // ref = "AB123"
/// ```
pub fn join_cell_name(
  col : StringView,
  row : Int,
) -> String raise @xlsx.XlsxError {
  @xlsx.join_cell_name(col, row)
}

///|
/// Converts a cell reference to column and row coordinates.
///
/// # Parameters
/// - `cell`: Cell reference like "A1", "B3", "$C$5"
///
/// # Returns
/// Tuple of (column, row) where both are 1-indexed
///
/// # Example
/// ```mbt nocheck
/// let (col, row) = cell_name_to_coordinates("B3")
/// // col = 2, row = 3
/// ```
pub fn cell_name_to_coordinates(
  cell : StringView,
) -> (Int, Int) raise @xlsx.XlsxError {
  @xlsx.cell_name_to_coordinates(cell)
}

///|
/// Converts column and row coordinates to a cell reference.
///
/// # Parameters
/// - `col`: Column number (1-indexed, where 1 = "A")
/// - `row`: Row number (1-indexed)
/// - `abs`: If true, creates absolute reference with $ signs (default: false)
///
/// # Returns
/// Cell reference string like "B3" or "$B$3" if abs=true
///
/// # Example
/// ```mbt nocheck
/// let ref = coordinates_to_cell_name(2, 3)
/// // ref = "B3"
/// let abs_ref = coordinates_to_cell_name(2, 3, abs=true)
/// // abs_ref = "$B$3"
/// ```
pub fn coordinates_to_cell_name(
  col : Int,
  row : Int,
  abs? : Bool = false,
) -> String raise @xlsx.XlsxError {
  @xlsx.coordinates_to_cell_name(col, row, abs~)
}

///|
/// Converts a column name to a column number.
///
/// # Parameters
/// - `name`: Column name like "A", "Z", "AA", "XFD"
///
/// # Returns
/// Column number (1-indexed, where "A" = 1)
///
/// # Example
/// ```mbt nocheck
/// let num = column_name_to_number("AA")
/// // num = 27
/// ```
pub fn column_name_to_number(name : StringView) -> Int raise @xlsx.XlsxError {
  @xlsx.column_name_to_number(name)
}

///|
/// Converts a column number to a column name.
///
/// # Parameters
/// - `col`: Column number (1-indexed, where 1 = "A")
///
/// # Returns
/// Column name like "A", "Z", "AA", "XFD"
///
/// # Example
/// ```mbt nocheck
/// let name = column_number_to_name(27)
/// // name = "AA"
/// ```
pub fn column_number_to_name(col : Int) -> String raise @xlsx.XlsxError {
  @xlsx.column_number_to_name(col)
}

///|
/// Reads an XLSX file from bytes into a Workbook.
///
/// # Parameters
/// - `bytes`: Raw XLSX file content
/// - `options`: Optional read options
/// - `transcoder`: Optional function for charset transcoding (for non-UTF8 files)
///
/// # Returns
/// Parsed Workbook object
///
/// # Example
/// ```mbt nocheck
/// let bytes = read_file("report.xlsx")
/// let wb = read(bytes)
/// let value = wb.get_cell("Sheet1", "A1")
/// ```
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
/// Reads a password-protected XLSX file from bytes.
///
/// # Parameters
/// - `bytes`: Raw encrypted XLSX file content
/// - `password`: Password used to encrypt the file
/// - `options`: Optional read options
/// - `transcoder`: Optional charset transcoder
///
/// # Returns
/// Parsed Workbook object
///
/// # Errors
/// - `InvalidPassword`: If the password is incorrect
/// - `EncryptedPackage`: If decryption fails
///
/// # Example
/// ```mbt nocheck
/// let bytes = read_file("protected.xlsx")
/// let wb = read_with_password(bytes, "secret123")
/// ```
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
/// Writes a Workbook to XLSX bytes.
///
/// # Parameters
/// - `workbook`: The workbook to serialize
///
/// # Returns
/// XLSX file content as bytes
///
/// # Example
/// ```mbt nocheck
/// let wb = new_file()
/// wb.set_cell("Sheet1", "A1", "Hello")
/// let bytes = write(wb)
/// write_file("output.xlsx", bytes)
/// ```
pub fn write(workbook : @xlsx.Workbook) -> Bytes raise @xlsx.XlsxError {
  @xlsx.write(workbook)
}

///|
/// Writes a Workbook to password-protected XLSX bytes.
///
/// The file will be encrypted using the ECMA-376 encryption standard.
///
/// # Parameters
/// - `workbook`: The workbook to serialize
/// - `password`: Password to protect the file with
///
/// # Returns
/// Encrypted XLSX file content as bytes
///
/// # Example
/// ```mbt nocheck
/// let wb = new_file()
/// wb.set_cell("Sheet1", "A1", "Confidential")
/// let bytes = write_with_password(wb, "secret123")
/// ```
pub fn write_with_password(
  workbook : @xlsx.Workbook,
  password : String,
) -> Bytes raise @xlsx.XlsxError {
  @xlsx.write_with_password(workbook, password)
}

///|
/// Encrypts raw XLSX bytes with a password.
///
/// # Parameters
/// - `raw`: Unencrypted XLSX file content
/// - `options`: Options containing the password
///
/// # Returns
/// Encrypted file content
pub fn encrypt(
  raw : BytesView,
  options? : @xlsx.Options = @xlsx.Options::new(),
) -> Bytes raise @xlsx.XlsxError {
  @xlsx.encrypt(raw, options~)
}

///|
/// Decrypts encrypted XLSX bytes.
///
/// # Parameters
/// - `raw`: Encrypted XLSX file content
/// - `options`: Options containing the password
///
/// # Returns
/// Decrypted XLSX file content
pub fn decrypt(
  raw : BytesView,
  options? : @xlsx.Options = @xlsx.Options::new(),
) -> Bytes raise @xlsx.XlsxError {
  @xlsx.decrypt(raw, options~)
}

///|
/// Converts RGB color values to HSL (Hue, Saturation, Lightness).
///
/// # Parameters
/// - `r`: Red component (0-255)
/// - `g`: Green component (0-255)
/// - `b`: Blue component (0-255)
///
/// # Returns
/// Tuple of (hue, saturation, lightness) where:
/// - hue: 0.0 to 1.0 (representing 0-360 degrees)
/// - saturation: 0.0 to 1.0
/// - lightness: 0.0 to 1.0
///
/// # Example
/// ```mbt nocheck
/// let (h, s, l) = rgb_to_hsl(255, 0, 0) // Red
/// // h ≈ 0, s = 1.0, l = 0.5
/// ```
pub fn rgb_to_hsl(r : Byte, g : Byte, b : Byte) -> (Double, Double, Double) {
  @xlsx.rgb_to_hsl(r, g, b)
}

///|
/// Converts RGB to HSL. Alias for `rgb_to_hsl`.
/// @deprecated Use `rgb_to_hsl` instead
pub fn rgbto_hsl(r : Byte, g : Byte, b : Byte) -> (Double, Double, Double) {
  @xlsx.rgb_to_hsl(r, g, b)
}

///|
/// Converts HSL (Hue, Saturation, Lightness) color values to RGB.
///
/// # Parameters
/// - `h`: Hue (0.0 to 1.0, representing 0-360 degrees)
/// - `s`: Saturation (0.0 to 1.0)
/// - `l`: Lightness (0.0 to 1.0)
///
/// # Returns
/// Tuple of (red, green, blue) where each is 0-255
///
/// # Example
/// ```mbt nocheck
/// let (r, g, b) = hsl_to_rgb(0.0, 1.0, 0.5) // Red
/// // r = 255, g = 0, b = 0
/// ```
pub fn hsl_to_rgb(h : Double, s : Double, l : Double) -> (Byte, Byte, Byte) {
  @xlsx.hsl_to_rgb(h, s, l)
}

///|
/// Converts HSL to RGB. Alias for `hsl_to_rgb`.
/// @deprecated Use `hsl_to_rgb` instead
pub fn hslto_rgb(h : Double, s : Double, l : Double) -> (Byte, Byte, Byte) {
  @xlsx.hsl_to_rgb(h, s, l)
}

///|
/// Applies a tint to a base color.
///
/// Theme colors in Excel can have tint values that lighten or darken
/// the base color.
///
/// # Parameters
/// - `base_color`: Hex color string like "FF0000"
/// - `tint`: Tint value from -1.0 (darken) to 1.0 (lighten)
///
/// # Returns
/// Tinted hex color string
///
/// # Example
/// ```mbt nocheck
/// let lighter = theme_color("FF0000", 0.5) // Lighter red
/// let darker = theme_color("FF0000", -0.5) // Darker red
/// ```
pub fn theme_color(base_color : String, tint : Double) -> String {
  @xlsx.theme_color(base_color, tint)
}

///|
/// Converts an Excel date serial number to a ZonedDateTime.
///
/// Excel stores dates as floating-point numbers where:
/// - The integer part is days since the epoch
/// - The fractional part is the time of day
///
/// # Parameters
/// - `excel_date`: Excel date serial number
/// - `use_1904_format`: If true, use Mac Excel's 1904 date system (default: false)
///
/// # Returns
/// ZonedDateTime representing the date and time
///
/// # Example
/// ```mbt nocheck
/// let dt = excel_date_to_time(44197.5) // 2021-01-01 12:00:00
/// ```
pub fn excel_date_to_time(
  excel_date : Double,
  use_1904_format? : Bool = false,
) -> @time.ZonedDateTime raise @xlsx.XlsxError {
  @xlsx.excel_date_to_time(excel_date, use_1904_format~)
}

///|
/// Opens an XLSX file from a file path asynchronously.
///
/// # Parameters
/// - `path`: Path to the XLSX file
/// - `password`: Password if the file is encrypted (default: empty)
/// - `options`: Optional read options
/// - `transcoder`: Optional charset transcoder
///
/// # Returns
/// Parsed Workbook object
///
/// # Example
/// ```mbt nocheck
/// let wb = open_file("report.xlsx")
/// let wb_protected = open_file("secret.xlsx", password="pass123")
/// ```
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
/// Opens an XLSX file from a Reader asynchronously.
///
/// # Parameters
/// - `reader`: Any type implementing the Reader trait
/// - `password`: Password if the file is encrypted (default: empty)
/// - `options`: Optional read options
/// - `transcoder`: Optional charset transcoder
///
/// # Returns
/// Parsed Workbook object
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
/// Reads an XLSX from a ZIP reader asynchronously.
///
/// This is a lower-level function that allows reading from a ZIP stream
/// that's already being read.
///
/// # Parameters
/// - `reader`: Any type implementing the Reader trait
/// - `password`: Password if the file is encrypted (default: empty)
/// - `options`: Optional read options
/// - `transcoder`: Optional charset transcoder
///
/// # Returns
/// Parsed Workbook object
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
