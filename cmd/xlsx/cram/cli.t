The xlsx command-line tool creates, edits, inspects, and validates
spreadsheets. Each command below runs in a fresh temporary directory.

Create a new workbook with a named first sheet:

  $ xlsx.exe create book.xlsx --sheet Data
  created book.xlsx (sheet Data)

Set some cell values (the file is saved in place):

  $ xlsx.exe set book.xlsx Data A1 Hello
  set Data!A1 = Hello
  $ xlsx.exe set book.xlsx Data B1 42
  set Data!B1 = 42

Read a single cell back:

  $ xlsx.exe get book.xlsx Data A1
  Hello

Formulas, styles, and merges (in a separate workbook). A leading `=` is
optional; formulas aren't evaluated, so a formula cell has no cached value and
`get` falls back to showing the formula:

  $ xlsx.exe create calc.xlsx --sheet Data
  created calc.xlsx (sheet Data)
  $ xlsx.exe set calc.xlsx Data B1 10
  set Data!B1 = 10
  $ xlsx.exe set calc.xlsx Data B2 20
  set Data!B2 = 20
  $ xlsx.exe formula calc.xlsx Data B3 "=SUM(B1:B2)"
  set Data!B3 = =SUM(B1:B2)
  $ xlsx.exe get calc.xlsx Data B3
  =SUM(B1:B2)

Style a cell or range (number format, bold/italic, fill color, alignment) and
merge cells; the package stays valid. Each `style` call sets a cell's complete
style, so keep styled ranges from overlapping — here the bold header row and
the number-formatted data cells are disjoint:

  $ xlsx.exe style calc.xlsx Data A1:B1 --bold --fill FFFF00 --align center
  styled 2 cell(s) in Data!A1:B1
  $ xlsx.exe style calc.xlsx Data B2:B3 --number-format "#,##0.00"
  styled 2 cell(s) in Data!B2:B3
  $ xlsx.exe merge calc.xlsx Data A5:B5
  merged Data!A5:B5
  $ xlsx.exe validate calc.xlsx
  valid

List the sheet names:

  $ xlsx.exe sheets book.xlsx
  Data

Export a sheet as CSV:

  $ xlsx.exe rows book.xlsx
  Hello,42

Import a CSV file into a new workbook — `csv` and `rows` are inverses, so both
RFC 4180 quoting (an embedded comma) and empty cells survive the round-trip:

  $ printf 'City,Pop,Note\nOslo,700000,\n"Sao, Paulo",12000000,big\n' > cities.csv
  $ xlsx.exe csv cities.csv cities.xlsx --sheet Cities
  imported 3 row(s) into cities.xlsx (sheet Cities)
  $ xlsx.exe rows cities.xlsx --sheet Cities
  City,Pop,Note
  Oslo,700000,
  "Sao, Paulo",12000000,big
  $ xlsx.exe get cities.xlsx Cities A3
  Sao, Paulo

Add a second row and view the sheet as an ASCII table (the first row is
treated as a header):

  $ xlsx.exe set book.xlsx Data A2 World
  set Data!A2 = World
  $ xlsx.exe set book.xlsx Data B2 7
  set Data!B2 = 7
  $ xlsx.exe view book.xlsx
  +-------+----+
  | Hello | 42 |
  +-------+----+
  | World | 7  |
  +-------+----+

Validate the OOXML package structure (empty problem list prints "valid"):

  $ xlsx.exe validate book.xlsx
  valid

A failing operation prints an `error:` line and exits non-zero, so
scripts can detect it:

  $ xlsx.exe get missing.xlsx Sheet1 A1
  error: * (glob)
  [1]
