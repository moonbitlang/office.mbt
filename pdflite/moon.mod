name = "bobzhang/pdflite"

version = "0.1.39"

import {
  "moonbitlang/async@0.20.1",
  "moonbitlang/x@0.4.43",
  "illusory0x0/rijndael@0.1.0",
}

readme = "README.mbt.md"

repository = "https://github.com/bobzhang/pdflite"

license = "Apache-2.0"

keywords = [ "pdf", "document", "parser", "writer" ]

description = "Byte-oriented PDF reading, writing, and manipulation toolkit for MoonBit."

// All warnings are expected to stay clean except these intentional buckets:
// unused_optional_argument (31), unused_default_value (32),
// missing_invariant (38), and missing_reasoning (39).

warnings = "+a-unused_optional_argument-unused_default_value-missing_invariant-missing_reasoning"
