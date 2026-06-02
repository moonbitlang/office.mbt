// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "bobzhang/docx2html"

version = "0.1.40"

readme = "README.mbt.md"

repository = "https://github.com/bobzhang/docx2html"

license = "Apache-2.0"

keywords = [ "docx", "html", "markdown", "mammoth" ]

description = "Native MoonBit DOCX to HTML/Markdown converter ported from Mammoth"

import {
  "hustcer/fzip@0.5.8",
  "moonbitlang/x@0.4.43",
  "moonbitlang/async@0.19.1",
}

preferred_target = "native"

// Warning policy:
// - Enabled: all optional compiler warnings, so new warning categories surface by default.
// - Active baseline for review: unnecessary_view_op (75), 119 warnings.
// - Ignored for now:
//   missing_doc (74), 219 warnings; public API docs need a separate documentation pass.
//   unused_optional_argument (31), 17 warnings; optional facade/helper defaults need API review.
//   unused_default_value (32), 30 warnings; same optional-argument API review bucket.
//   prefer_readonly_array (65), 2 warnings; low-priority test style suggestions.
//   missing_invariant (38) and missing_reasoning (39); proof-loop warnings are not relevant here.

warnings = "+a-unused_optional_argument-unused_default_value-missing_invariant-missing_reasoning-prefer_readonly_array-missing_doc"
