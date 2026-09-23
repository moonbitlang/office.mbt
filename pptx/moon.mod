// Modified for office.mbt: official module namespace and workspace integration.
name = "moonbitlang/pptx"

version = "0.1.0"

import {
  "moonbitlang/async@0.22.1",
  "moonbit-community/flate@0.8.1",
  "moonbitlang/office-ooxml@0.1.0",
}

readme = "README.mbt.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "pptx", "powerpoint", "ooxml", "office", "presentation" ]

description = "Pure-MoonBit library for reading, building, and writing PPTX (OOXML) presentations with a type-safe builder API."

preferred_target = "native"

warnings = "+result_error_return+prefer_readonly_array+unnecessary_view_op+unnecessary_annotation+test_unqualified_package+implicit_impl_as_method"
