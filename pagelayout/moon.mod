name = "moonbitlang/pagelayout"

version = "0.2.0"

readme = "README.mbt.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "layout", "pagination", "docx", "svg", "pdf", "typesetting" ]

description = "Paginated document layout engine: format-neutral page-model IR with SVG/PDF backends."

import {
  "moonbitlang/async@0.22.1",
  "moonbitlang/x@0.4.50",
  "moonbitlang/docx2html@0.6.1",
  "moonbitlang/pdflite@0.2.0",
  "moonbit-community/flate@0.8.1",
}

warnings = "+a-unused_optional_argument-unused_default_value-missing_invariant-missing_reasoning"
