name = "bobzhang/office"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "office", "xlsx", "docx", "ooxml", "cli" ]

description = "Agent-oriented XLSX and DOCX tooling for MoonBit"

import {
  "bobzhang/mbtexcel@0.1.9",
  "bobzhang/docx2html@0.2.0",
  "moonbitlang/async@0.20.1",
  "moonbitlang/x@0.4.43",
}

preferred_target = "native"

warnings = "+result_error_return+prefer_readonly_array+unnecessary_view_op+unnecessary_annotation+test_unqualified_package+implicit_impl_as_method"
