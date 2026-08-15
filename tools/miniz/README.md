# miniz differential tooling

`pdflite/flate` is being given a MoonBit compressor that must agree with the
vendored miniz **byte for byte**, not merely produce valid deflate. That makes
the C in `pdflite/vendor/miniz` the specification, and these are the tools for
comparing against it directly rather than against a second reading of it.

Nothing here is part of the build.

## `huffprobe.c`

Prints the code length miniz assigns each symbol, for frequency vectors on
stdin. It `#include`s `miniz.c` because the three functions that matter --
`tdefl_radix_sort_syms`, `tdefl_calculate_minimum_redundancy`,
`tdefl_huffman_enforce_max_code_size` -- are static and unreachable otherwise.

```sh
cc -w -o huffprobe tools/miniz/huffprobe.c -Ipdflite/vendor/miniz
./huffprobe < tools/miniz/huffcases.txt
```

Each input line is `n freq0 freq1 ... freq{n-1}`; each output line is the code
length per symbol, in symbol order.

## `huffcases.txt`

The frequency vectors behind
`pdflite/flate/pdf_tdefl_huffman_wbtest.mbt`. Every vector sums to at most
65535, which is a correctness requirement rather than tidiness: miniz counts
symbols within one block and accumulates in 16-bit fields, so a larger vector
takes the C outside its own domain, where it has no defined answer to compare
against. An earlier corpus ignored that and produced "expectations" that were
really the C's overflow behaviour.

To regenerate the expectations after changing the vendored miniz, rebuild the
probe, rerun it, and paste the results into the test.
