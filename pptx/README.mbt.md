# PPTX for MoonBit Office

`moonbitlang/pptx` reads, builds, and writes PowerPoint (`.pptx`) presentations.
It is a module of the [Office workspace](../README.md), managed by the root
`moon.work` and the repository's shared CI, tooling, and release workflow.

Derived from [t-ujiie-g/moon-pptx](https://github.com/t-ujiie-g/moon-pptx).
Thank you to t-ujiie-g and the original contributors for the architecture,
implementation, documentation, and extensive tests. See [UPSTREAM.md](UPSTREAM.md)
for the pinned revision and attribution; the Apache-2.0 [LICENSE](LICENSE) is
retained. The MoonBit team maintains the official module's API and releases.
Contributions from the original author are welcome, and the original project
can continue independently.

## Packages

| Package | Responsibility |
| --- | --- |
| `presentation` | Presentation model, building, editing, loading, and saving |
| `slide`, `slide_master`, `theme` | Slides, layouts, masters, and themes |
| `chart`, `chart_ex`, `smartart` | Charts and diagrams |
| `notes`, `comments` | Speaker notes and comments |
| `oxml`, `xml`, `opc`, `units` | OOXML models, XML, ZIP packages, and typed units |
| `demos` | Shared sample-deck builders with public-API tests |
| `cmd/demos`, `cmd/bench` | Demo generation and benchmark executables |
| `integration` | Cross-package tests, embedded fixtures, and benchmarks |
| `sdk_validity` | Native tests against the shared OpenXML SDK validator |

Source packages live directly under this module, matching the other Office
modules. Examples and benchmarks are packages of `moonbitlang/pptx`, not
separate modules or workspaces. Import paths such as
`moonbitlang/pptx/presentation` are unchanged by the directory organization.

## API boundaries

Parser and writer state, package storage and indexes, presentation caches,
and staged construction handles have private fields. Construct and edit them
through their methods. OOXML value models retain the fields needed to inspect,
construct, and preserve document content, including unknown XML extensions.

Use `Presentation::opc_package()` for low-level edits that the typed APIs do
not cover. `Package::parts()`, `Part::bytes()`, `ContentTypes::defaults()` and
`overrides()`, and `Relationships::items()` return independent buffers or
arrays. Editing these snapshots does not edit the document: replace a part
with `Package::replace_part`, or build and install an updated catalog.
`Part::new` also copies its input buffer. Slide-order caches refresh when the
presentation or relationship part is replaced.

## Develop

Run all commands from the **repository root**:

```sh
moon check --deny-warn
moon test --target native
moon info
moon fmt
```

For focused work, select the relevant package:

```sh
moon test --deny-warn --target native pptx/presentation pptx/demos pptx/integration
moon run --target native pptx/cmd/bench -- 10
bash scripts/generate_pptx_demos.sh
bash scripts/validate_pptx.sh demos_out_pptx/sample.pptx
python3 scripts/embed_pptx_corpus.py
moon fmt pptx/integration
```

See the [cookbook](docs/pptx-examples.md), [demo guide](docs/pptx-demos.md),
[validation guide](docs/pptx-validation.md), and
[benchmark guide](docs/pptx-benchmarks.md). The shared validator needs .NET 8;
the wrapper uses Office's existing .NET setup and build cache.

Publishing follows the common [release process](../docs/office-release.md).
The local module version is not evidence of a registry release. The unified
`office` CLI currently supports DOCX and XLSX; PPTX uses its library packages
and dedicated development commands.

## Limits

Unknown XML element preservation is supported, but arbitrary PPTX input is not
guaranteed to round-trip without loss. Parser robustness, attribute/namespace
preservation, ZIP resource limits, and PowerPoint display/edit compatibility
remain tracked in [#549](https://github.com/moonbitlang/office.mbt/issues/549).
SDK schema validation and parsed-model equality do not establish visual fidelity.
