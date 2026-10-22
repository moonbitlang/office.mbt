name = "moonbitlang/office"

version = "0.3.1"

readme = "README.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "office", "xlsx", "docx", "ooxml", "pdf", "cli" ]

description = "Agent-oriented Office and PDF command-line tooling"

import {
  "moonbitlang/pdflite@0.4.1",
  "moonbitlang/ooxml@0.1.1",
  "moonbitlang/office-lib@0.7.1",
  "moonbitlang/async@0.22.5",
  "moonbitlang/docx2html@0.7.1",
  "moonbitlang/mbtexcel@0.3.1",
  "moonbitlang/pagelayout@0.8.1",
  "moonbitlang/x@0.5.6",
  "moonbit-community/flate@0.10.0",
  "moonbit-community/unicode@0.6.0",
}

preferred_target = "native"

warnings = "+result_error_return+prefer_readonly_array+unnecessary_view_op+unnecessary_annotation+test_unqualified_package+implicit_impl_as_method"
