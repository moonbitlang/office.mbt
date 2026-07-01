///|
pub fn demo_secure_bytes(
  password? : String = "moonbit",
) -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let sheet = workbook.add_sheet("Secure")
  workbook.set_core_properties(
    @xlsx.CoreProperties::with_values(
      title="mbtexcel secure demo",
      creator="mbtexcel (MoonBit)",
      description="Generated on 2026-01-31. This file is encrypted with a password.",
      created="2026-01-31T00:00:00Z",
      modified="2026-01-31T00:00:00Z",
    ),
  )
  sheet.set_cell("A1", "This workbook is password-protected.")
  sheet.set_cell("A2", "Try opening it in Excel and enter the password.")
  sheet.set_cell("A4", "Password hint:")
  sheet.set_cell("B4", "moonbit")
  @excel.write_with_password(workbook, password)
}
