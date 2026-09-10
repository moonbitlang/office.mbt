name = "moonbitlang/office-lib"

version = "0.5.0"

readme = "README.mbt.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "office", "xlsx", "docx", "ooxml", "cli" ]

description = "Agent-oriented XLSX and DOCX tooling for MoonBit"

import {
  "moonbitlang/mbtexcel@0.1.9",
  "moonbitlang/pagelayout@0.1.1",
  "moonbitlang/docx2html@0.5.0",
  "moonbitlang/async@0.20.2",
  "moonbitlang/x@0.4.50",
  "tonyfettes/unicode@0.3.3",
  "moonbit-community/flate@0.8.0",
}

preferred_target = "native"

warnings = "+result_error_return+prefer_readonly_array+unnecessary_view_op+unnecessary_annotation+test_unqualified_package+implicit_impl_as_method"
