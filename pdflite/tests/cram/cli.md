# Native PDF CLI

These Moon Cram tests exercise the compiled native `pdflite` wrapper. They focus on
shell-visible behavior that unit tests cannot cover directly: argv, file IO,
stdout, stderr, and process exit codes.

## Version

```mooncram
$ "$PDFLITE_CLI" --version
pdflite 0.1.38
```

## Help

```mooncram
$ "$PDFLITE_CLI" --help | grep -E '^(Usage: pdflite|  info|  rewrite|  validate|  -V, --version)'
Usage: pdflite <command>
  info      Print basic metadata for one PDF file.
  rewrite   Parse, write, and verify a PDF file.
  validate  Parse and round-trip a PDF without writing a file.
  -V, --version  Show version information.
```

## Info Options

```mooncram
$ "$PDFLITE_CLI" info --help | grep -E '^(Usage: pdflite info|  input|  --json)'
Usage: pdflite info [options] <input>
  input  Input PDF path.
  --json      Print metadata as JSON.
```

## PDF Metadata

```mooncram
$ "$PDFLITE_CLI" info "$PDFLITE_LOGO_PDF" | grep -E '^(version|pages|encrypted):'
version: 1.4
pages: 1
encrypted: false
```

## PDF Metadata JSON

```mooncram
$ "$PDFLITE_CLI" info --json "$PDFLITE_LOGO_PDF" | python3 -c 'import json,sys; data=json.load(sys.stdin); print("version=" + data["version"]); print("pages=" + str(data["pages"])); print("encrypted=" + str(data["encrypted"]).lower())'
version=1.4
pages=1
encrypted=false
```

## Validate Round Trip

```mooncram
$ "$PDFLITE_CLI" validate "$PDFLITE_LOGO_PDF" | sed "s#${PDFLITE_LOGO_PDF}#<PDFLITE_LOGO_PDF>#" | grep -E '^(valid|version|pages|encrypted):'
valid: <PDFLITE_LOGO_PDF>
version: 1.4
pages: 1
encrypted: false
```

## Rewrite Round Trip

```mooncram
$ "$PDFLITE_CLI" rewrite "$PDFLITE_LOGO_PDF" roundtrip.pdf && "$PDFLITE_CLI" info roundtrip.pdf | grep -E '^(version|pages|encrypted):'
version: 1.4
pages: 1
encrypted: false
```

## Unknown Option Error

```mooncram
$ set +e; "$PDFLITE_CLI" --bad > unknown.out 2> unknown.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n '1p' unknown.err; test ! -s unknown.out
exit=2
error: unexpected argument '--bad' found
```

## Missing PDF Error

```mooncram
$ set +e; "$PDFLITE_CLI" info missing.pdf > missing.out 2> missing.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n "s/\\(pdflite: cannot read 'missing.pdf':\\).*/\\1/p" missing.err; test ! -s missing.out
exit=1
pdflite: cannot read 'missing.pdf':
```

## Invalid PDF Error

```mooncram
$ set +e; printf 'not a pdf' > bad.pdf; "$PDFLITE_CLI" info bad.pdf > bad.out 2> bad.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n '1p' bad.err; test ! -s bad.out
exit=1
pdflite: cannot parse PDF 'bad.pdf': missing or invalid PDF catalog root (RootExpected)
```
