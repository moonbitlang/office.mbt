# Native PDF CLI

These Scrut tests exercise the compiled native `pdflite` wrapper. They focus on
shell-visible behavior that unit tests cannot cover directly: argv, file IO,
stdout, stderr, and process exit codes.

## Version

```scrut
$ "$PDFLITE_CLI" --version
pdflite 0.1.29
```

## Help

```scrut
$ "$PDFLITE_CLI" --help | grep -E '^(Usage: pdflite|  info|  rewrite|  -V, --version)'
Usage: pdflite <command>
  info     Print basic metadata for one PDF file.
  rewrite  Parse and write a PDF file.
  -V, --version  Show version information.
```

## PDF Metadata

```scrut
$ "$PDFLITE_CLI" info "$PDFLITE_LOGO_PDF" | grep -E '^(version|pages|encrypted):'
version: 1.4
pages: 1
encrypted: false
```

## Rewrite Round Trip

```scrut
$ "$PDFLITE_CLI" rewrite "$PDFLITE_LOGO_PDF" roundtrip.pdf && "$PDFLITE_CLI" info roundtrip.pdf | grep -E '^(version|pages|encrypted):'
version: 1.4
pages: 1
encrypted: false
```

## Unknown Option Error

```scrut
$ set +e; "$PDFLITE_CLI" --bad > unknown.out 2> unknown.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n '1p' unknown.err; test ! -s unknown.out
exit=2
error: unexpected argument '--bad' found
```

## Invalid PDF Error

```scrut
$ set +e; printf 'not a pdf' > bad.pdf; "$PDFLITE_CLI" info bad.pdf > bad.out 2> bad.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n '1p' bad.err; test ! -s bad.out
exit=1
pdflite: RootExpected
```
