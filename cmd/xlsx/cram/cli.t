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

List the sheet names:

  $ xlsx.exe sheets book.xlsx
  Data

Export a sheet as CSV:

  $ xlsx.exe rows book.xlsx
  Hello,42

Validate the OOXML package structure (empty problem list prints "valid"):

  $ xlsx.exe validate book.xlsx
  valid
