# Page layout CLI

These Moon Cram tests drive the compiled native `pagelayout` binary against a
real Word-produced `.docx`, covering the shell-visible surface unit tests
cannot: argv, file IO, stdout, stderr, and process exit codes.

`PAGELAYOUT_CLI` is the binary and `PAGELAYOUT_DOCX` the fixture; both come
from the environment so this doc runs from a stub project.

## Version

```mooncram
$ "$PAGELAYOUT_CLI" --version
pagelayout 0.1.0
```

## Help

```mooncram
$ "$PAGELAYOUT_CLI" --help | grep -E '^(Usage: pagelayout|  render|  pdf|  info|  -V, --version)'
Usage: pagelayout <command>
  render  Render a DOCX to one SVG file per page.
  pdf     Render a DOCX to a single PDF file.
  info    Report the page geometry and content a DOCX lays out to.
  -V, --version  Show version information.
```

## Info

The fixture is a single A4 page carrying one text run.

```mooncram
$ "$PAGELAYOUT_CLI" info "$PAGELAYOUT_DOCX"
pages: 1
page size: 595.3 x 841.9 pt
fonts: 1
runs: 1
characters: 23
```

The JSON surface reports the same facts plus the IR's own validity check.

```mooncram
$ "$PAGELAYOUT_CLI" info "$PAGELAYOUT_DOCX" --json
{"pages":1,"page_width_pt":595.3,"page_height_pt":841.9,"fonts":1,"runs":1,"characters":23,"valid":true,"dropped_characters":0,"uncovered_codepoints":0,"unembeddable_images":0}
```

## Render

A single page writes to the given path verbatim.

```mooncram
$ "$PAGELAYOUT_CLI" render "$PAGELAYOUT_DOCX" page.svg; head -2 page.svg
wrote 1 page(s)
<svg xmlns="http://www.w3.org/2000/svg" width="595.3pt" height="841.9pt" viewBox="0 0 595.3 841.9">
  <rect x="0" y="0" width="595.3" height="841.9" fill="#ffffff"/>
```

The document's Calibri resolved to the bundled metric-compatible Carlito, and
the text is positioned per character from the engine's own advances — so the
rendering does not depend on the viewer's fonts.

```mooncram
$ grep -o 'font-family="[^"]*"' page.svg; grep -c 'Walking on imported air' page.svg
font-family="Carlito"
1
```

## PDF

The same document renders to a PDF, which begins with a version header
and ends with the trailer every reader looks for.

```mooncram
$ "$PAGELAYOUT_CLI" pdf "$PAGELAYOUT_DOCX" out.pdf; head -c 8 out.pdf; echo; tail -c 6 out.pdf
wrote 1 page(s)
%PDF-1.7
%%EOF
```

## Errors

A missing input reports on stderr, writes nothing to stdout, and exits 1.

```mooncram
$ set +e; "$PAGELAYOUT_CLI" info missing.docx > missing.out 2> missing.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n "s/\\(pagelayout: cannot read 'missing.docx':\\).*/\\1/p" missing.err; test ! -s missing.out
exit=1
pagelayout: cannot read 'missing.docx':
```

A file that is not a DOCX fails the same way rather than crashing.

```mooncram
$ set +e; printf 'not a zip' > bad.docx; "$PAGELAYOUT_CLI" info bad.docx > bad.out 2> bad.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n "s/\\(pagelayout: cannot lay out 'bad.docx':\\).*/\\1/p" bad.err; test ! -s bad.out
exit=1
pagelayout: cannot lay out 'bad.docx':
```

An unknown argument is a usage error, exit 2.

```mooncram
$ set +e; "$PAGELAYOUT_CLI" --bad > unknown.out 2> unknown.err; code=$?; set -e; printf 'exit=%s\n' "$code"; test ! -s unknown.out
exit=2
```
