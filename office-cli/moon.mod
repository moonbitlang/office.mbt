name = "moonbitlang/office"

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "office", "xlsx", "docx", "ooxml", "cli" ]

description = "Agent-oriented XLSX and DOCX command-line tooling"

import {
  "moonbitlang/office-lib@0.6.1",
  "moonbitlang/async@0.22.1",
  "moonbitlang/docx2html@0.6.1",
  "moonbitlang/mbtexcel@0.2.0",
  "moonbitlang/pagelayout@0.2.0",
  "moonbitlang/x@0.4.50",
  "moonbit-community/flate@0.8.1",
  "tonyfettes/unicode@0.3.3",
}

preferred_target = "native"

warnings = "+result_error_return+prefer_readonly_array+unnecessary_view_op+unnecessary_annotation+test_unqualified_package+implicit_impl_as_method"
