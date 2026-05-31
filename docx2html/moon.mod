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

version = "0.1.7"

readme = "README.mbt.md"

repository = ""

license = "Apache-2.0"

keywords = [ "docx", "html", "markdown", "mammoth" ]

description = "Native MoonBit DOCX to HTML/Markdown converter ported from Mammoth"

import {
  "hustcer/fzip@0.5.8",
  "moonbitlang/x@0.4.43",
}
