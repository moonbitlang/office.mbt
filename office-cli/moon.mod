name = "moonbitlang/office"

version = "0.3.1"

readme = "README.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "office", "xlsx", "docx", "ooxml", "cli" ]

description = "Agent-oriented XLSX and DOCX command-line tooling"

import {
  "moonbitlang/ooxml@0.1.0",
  "moonbitlang/office-lib@0.7.0",
  "moonbitlang/async@0.22.5",
  "moonbitlang/docx2html@0.7.0",
  "moonbitlang/mbtexcel@0.3.0",
  "moonbitlang/pagelayout@0.8.0",
  "moonbitlang/x@0.5.6",
  "moonbit-community/flate@0.9.0",
  "moonbit-community/unicode@0.6.0",
}

preferred_target = "native"

warnings = "+result_error_return+prefer_readonly_array+unnecessary_view_op+unnecessary_annotation+test_unqualified_package+implicit_impl_as_method"
