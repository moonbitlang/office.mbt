name = "bobzhang/mbtexcel"

version = "0.1.7"

import {
  "moonbitlang/async@0.20.1",
  "moonbitlang/x@0.4.43",
}

readme = "README.mbt.md"

preferred_target = "native"

repository = "https://github.com/moonbitlang/mbtexcel"

license = "Apache-2.0"

keywords = [ "excel", "xlsx", "spreadsheet", "ooxml", "office" ]

description = "A MoonBit port of the Go excelize library for reading and writing XLSX (Excel) spreadsheets."

warnings = "+result_error_return+prefer_readonly_array+unnecessary_view_op+unnecessary_annotation+test_unqualified_package"
