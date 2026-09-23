<!-- Modified for office.mbt: replace upstream README with import documentation. -->
# PPTX for MoonBit Office

A MoonBit library for reading, building, and writing PowerPoint (`.pptx`)
presentations, imported from [t-ujiie-g/moon-pptx](https://github.com/t-ujiie-g/moon-pptx)
version **0.10.0**. Thank you to **t-ujiie-g and the original contributors** for
the architecture, implementation, documentation, and extensive test suite.
The original Apache-2.0 [LICENSE](LICENSE) is retained.

## Status and ownership

This is a first-stage source import, with local module identity `moonbitlang/pptx`
and initial official version `0.1.0`. It is included in workspace checks and
tests, but is not integrated into the unified Office CLI or automated release
workflow. This document does not claim a registry release.

The MoonBit team maintains the official version's roadmap, API evolution, and
release schedule. Contributions from the original author are welcome. The
original project can continue independently, and improvements may be shared
between the projects.

## Scope

The imported packages cover presentations, slides, themes, masters, notes,
comments, charts, SmartArt, typed units, XML, and OPC/ZIP containers. The only
external module dependency remains `hustcer/fzip@0.8.2`.

Unknown XML element preservation is supported, but arbitrary PPTX input is
**not guaranteed to round-trip without loss**. Known attribute/namespace
preservation and malformed-input issues remain. Package decompression has no
configured resource limits. Test success does not establish PowerPoint display
or editing compatibility. See [UPSTREAM.md](UPSTREAM.md) for provenance,
modifications, and the hardening backlog.

## Develop

From the office.mbt repository root, select the source package directories
(the imported module retains `source = "src"`):

```sh
moon check pptx/src/presentation
moon test --target native pptx/src/presentation
```

From `pptx/`, `moon test --target native` runs this module's tests. Workspace-wide
commands from the repository root also include this module. Examples and
validation tools remain under `examples/` and `tools/`; their nested workspaces
resolve the local `moonbitlang/pptx` module.

The original [README](upstream/README.mbt.md), [roadmap](upstream/ROADMAP.md), and
[changelog](upstream/CHANGELOG.md) are historical upstream snapshots. Their
package names, release claims, and roadmap describe the original project.
