name = "bobzhang/pagelayout"

version = "0.1.1"

readme = "README.mbt.md"

repository = "https://github.com/moonbitlang/office.mbt"

license = "Apache-2.0"

keywords = [ "layout", "pagination", "docx", "svg", "pdf", "typesetting" ]

description = "Paginated document layout engine: format-neutral page-model IR with SVG/PDF backends."

import {
  "moonbitlang/async@0.20.2",
  "moonbitlang/x@0.4.50",
  "bobzhang/docx2html@0.5.0",
  "bobzhang/mbtexcel@0.1.9",
  "bobzhang/pdflite@0.1.41",
  "moonbit-community/flate@0.7.3",
}

warnings = "+a-unused_optional_argument-unused_default_value-missing_invariant-missing_reasoning"
