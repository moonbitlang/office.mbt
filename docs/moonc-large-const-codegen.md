# moonc native codegen: large `.mbt` constant data expands to an 87 MB C file (~1 h compile)

Draft upstream report — measured in this repo (`moonbitlang/mbtexcel` monorepo).
File as a moonc issue, or use internally; the repro is self-contained.

## Summary

The native backend lowers large in-source constant data into generated C
**code** rather than static data arrays. In this repo, a main package whose
transitive imports include ~7 MB of constant tables produces a single
generated `cmd.c` of **87 MB / 1.93 million lines**, which Apple clang
(`-Og -g`, dwarf-5) compiles for **~1 hour** at 100 % CPU, and gcc on a
GitHub-Actions runner did not finish within 55 minutes. The same module's
other CLI, which does not import the data-heavy packages, generates an
8.8 MB `main.c` and compiles in about a minute.

## Reproducer

```
git clone https://github.com/moonbitlang/mbtexcel
cd mbtexcel
moon build --target native pdflite/markdown/cmd   # generates + compiles cmd.c
ls -lh _build/native/debug/build/bobzhang/pdflite/markdown/cmd/cmd.c   # ~87 MB
```

The data lives in ordinary `.mbt` sources:

| Source | Size |
| --- | --- |
| `pdflite/text/cmapdata/pdf_text_cmap_japan1_data.mbt` | 1.5 MB |
| `pdflite/text/unicodedata/pdf_unicode_data_source.mbt` | 1.1 MB |
| `pdflite/text/cmapdata/pdf_text_cmap_gbk_data.mbt` | 936 KB |
| …seven more cmapdata files | 400–730 KB each |

`pdflite/markdown/cmd` (a markdown→PDF CLI) transitively imports the full
text stack, so its generated translation unit contains the expanded tables;
`pdflite/cmd/main` does not, hence 8.8 MB.

## Measurements

- `cmd.c`: 87 MB, 1,932,746 lines. Content is generated *code*, not data:
  only 94 pure-data literal lines and 2 top-level array initializers in the
  whole file.
- Apple clang 21 (`-Og -g`, arm64): ≈ 1 hour, single core pegged; produces
  an 18 MB `cmd.exe`.
- gcc (ubuntu-latest, 4 cores): killed after 55+ minutes (CI job cap).
- Knock-on effect: `moon cram test <dir>` builds **every** workspace
  executable first, so any cram invocation in the workspace stalls on this
  one compile until it is cached. (Our CI now builds only the needed CLIs
  and runs cram docs from a stub project to avoid it.)

## Suggested directions

1. Lower large constant arrays/tables to C static data (`static const`
   byte/word arrays) instead of constructor code, at least beyond some size
   threshold.
2. Alternatively (or additionally), split giant generated translation units
   so the C compiler's super-linear passes don't see millions of lines at
   once.

## Workaround options on the library side

- Restructure `cmapdata`/`unicodedata` as compact `Bytes` blobs parsed at
  first use (also shrinks the source tree); tracked as a follow-up in this
  repo's quality roadmap.
