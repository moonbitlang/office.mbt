# Verified CLI Documentation

These examples are executed by `moon cram test tests/cram`. The Moon wrapper
builds the native package at `cmd/docx2html` first, then exposes the executable
on `PATH` as `docx2html.exe`.

The fixtures below are small DOCX files copied from Mammoth's upstream test
data and committed beside this document.

## Help

```mooncram
$ docx2html.exe --help | sed -n '1,4p'
Usage: docx2html [options] <input> [output]

Convert DOCX documents to HTML or Markdown.

```

## Convert To HTML On Stdout

```mooncram
$ printf '%s\n' "$(docx2html.exe "$TESTDIR/fixtures/single-paragraph.docx")"
<p>Walking on imported air</p>
```

## Convert To Markdown On Stdout

```mooncram
$ docx2html.exe --output-format=markdown "$TESTDIR/fixtures/single-paragraph.docx" | sed -n '1,2p'
Walking on imported air

```

## Apply A Style Map File

```mooncram
$ printf 'p => h1\n' > style-map; printf '%s\n' "$(docx2html.exe --style-map style-map "$TESTDIR/fixtures/single-paragraph.docx")"
<h1>Walking on imported air</h1>
```

## Write To An Explicit Output File

```mooncram
$ docx2html.exe "$TESTDIR/fixtures/single-paragraph.docx" single.html; printf '%s\n' "$(cat single.html)"
<p>Walking on imported air</p>
```

## Write Images Beside The Converted Document

`--output-dir` writes extracted images into an existing directory and writes the
converted document as `<input-basename>.html`.

```mooncram
$ mkdir out; docx2html.exe --output-dir out "$TESTDIR/fixtures/tiny-picture.docx"; printf '%s\n' "$(cat out/tiny-picture.html)"; test -s out/1.png && echo image-written
<p><img src="1.png" /></p>
image-written
```
