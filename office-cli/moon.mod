name = "bobzhang/office"

version = "0.4.0"

readme = "README.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "office", "xlsx", "docx", "ooxml", "cli" ]

description = "Agent-oriented XLSX and DOCX command-line tooling"

import {
  "bobzhang/office-lib@0.3.0",
  "moonbitlang/async@0.20.2",
}

preferred_target = "native"

warnings = "+result_error_return+prefer_readonly_array+unnecessary_view_op+unnecessary_annotation+test_unqualified_package+implicit_impl_as_method"
