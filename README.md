# Office for MoonBit

This repository contains the Office CLI, its integration library, and the
document engines they use. Each module is published independently; `moon.work`
connects the six modules for local development.

| Directory | Published module | Responsibility |
| --- | --- | --- |
| [mbtexcel](mbtexcel/README.mbt.md) | `moonbitlang/mbtexcel` | Read and write XLSX spreadsheets |
| [docx2html](docx2html/README.mbt.md) | `moonbitlang/docx2html` | Parse, convert, and edit DOCX documents |
| [pdflite](pdflite/README.mbt.md) | `moonbitlang/pdflite` | Read, write, and manipulate PDFs |
| [pagelayout](pagelayout/README.mbt.md) | `moonbitlang/pagelayout` | Document layout and SVG/PDF rendering |
| [office-lib](office-lib/README.mbt.md) | `moonbitlang/office-lib` | Office integration, SDK, and command implementations |
| [office-cli](office-cli/README.md) | `moonbitlang/office` | Executable entry point |

The CLI delegates to `office-lib/cmd/office`, which integrates the document
engines and layout packages. The command implementation currently lives in
`office-lib`; `office-cli` is a thin launcher. The repository root is only a
workspace, not a publishable MoonBit module.

## Use the CLI

```sh
moonx moonbitlang/office help all --json
moonx moonbitlang/office identify report.docx --json
```

See the [Office library documentation](office-lib/README.mbt.md) for SDK usage
and the [input/output schemas](docs/agent-json-schemas.md) for automation.

## Develop

Run these commands from the repository root:

```sh
moon update
moon check
moon test
moon info
moon fmt
moon run office-cli -- help all --json
moon run mbtexcel/cmd/xlsx -- --help
```

Native SDK validity tests use the shared validators under `scripts/` and need
.NET 8. Excel test fixtures live in `mbtexcel/fixtures/excelize/`; each module's
tests resolve their data relative to that module's root.

Shared documentation, CI, scripts, and developer tools remain at the repository
root. Module READMEs describe commands relative to their module directory unless
stated otherwise. Published module names and package import paths are independent
of this directory layout.

## Release

Publish from the relevant module directory, following the
[release process](docs/office-release.md). Validate registry resolution outside
the workspace before publishing dependents; a successful workspace build alone
does not verify published dependencies. The root publish workflow publishes
`mbtexcel` only.

Further module-boundary work is tracked in
[issue #542](https://github.com/moonbitlang/office.mbt/issues/542).
