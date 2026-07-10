# Verified `docx` CLI Documentation

These examples are executed by `moon cram test tests/cram`. The Moon wrapper
builds the native package at `cmd/docx` first, then exposes the executable on
`PATH` as `docx.exe`.

`docx` is the subcommand-structured agent CLI; its `convert` subcommand shares
one implementation with the flag-only `docx2html` binary documented in
`cli.md`, with identical conversion and output semantics (argument parsing,
help text, and diagnostic prefixes intentionally differ).

## Help

```mooncram
$ docx.exe --help | sed -n '1,3p'
Usage: docx <command>

Read, inspect, and convert docx documents
```

## Convert To HTML On Stdout

```mooncram
$ printf '%s\n' "$(docx.exe convert "$TESTDIR/fixtures/single-paragraph.docx")"
<p>Walking on imported air</p>
```

## Convert To Markdown On Stdout

```mooncram
$ docx.exe convert --output-format=markdown "$TESTDIR/fixtures/single-paragraph.docx" | sed -n '1,2p'
Walking on imported air

```

## Apply A Style Map File

```mooncram
$ printf 'p => h1\n' > style-map; printf '%s\n' "$(docx.exe convert --style-map style-map "$TESTDIR/fixtures/single-paragraph.docx")"
<h1>Walking on imported air</h1>
```

## Write To An Explicit Output File

```mooncram
$ docx.exe convert "$TESTDIR/fixtures/single-paragraph.docx" single.html; printf '%s\n' "$(cat single.html)"
<p>Walking on imported air</p>
```

## Write Images Beside The Converted Document

`--output-dir` writes extracted images into a directory (created if missing)
and writes the converted document as `<input-basename>.html`.

```mooncram
$ docx.exe convert --output-dir out "$TESTDIR/fixtures/tiny-picture.docx"; printf '%s\n' "$(cat out/tiny-picture.html)"; test -s out/1.png && echo image-written
<p><img src="1.png" /></p>
image-written
```

## Errors Exit Non-Zero With A Diagnostic On Stdout

An unknown subcommand is an argument error:

```mooncram
$ docx.exe wat > wat.txt; echo "exit=$?"; sed -n '1p' wat.txt
exit=1
error: unexpected value 'wat' found; no more were expected
```

A missing input file is a conversion error, prefixed with the program name:

The OS error's human-readable tail is locale/platform-dependent, so the
assertion pins only the stable prefix and path:

```mooncram
$ docx.exe convert no-such-file.docx > missing.txt; echo "exit=$?"; grep -Fc 'docx: OSError("@fs.open(): \"no-such-file.docx\"' missing.txt
exit=1
1
```

An output path and `--output-dir` are mutually exclusive:

```mooncram
$ docx.exe convert --output-dir out "$TESTDIR/fixtures/single-paragraph.docx" out.html
error: output path and --output-dir are mutually exclusive
[1]
```
