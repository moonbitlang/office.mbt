# Upstream provenance and first-stage import

## Original project

- Project: [t-ujiie-g/moon-pptx](https://github.com/t-ujiie-g/moon-pptx)
- Version: `0.10.0`
- Revision: [`085de51852e30edb04a1032bd1cbbede3b60a53f`](https://github.com/t-ujiie-g/moon-pptx/commit/085de51852e30edb04a1032bd1cbbede3b60a53f)
- Imported: 2026-09-23
- License: Apache-2.0; the original `LICENSE` is copied without changes.
- No tracked upstream NOTICE file was present at this revision.

Thank you to t-ujiie-g and the original contributors for the thoughtful
architecture, broad feature coverage, and extensive tests. Their work provides
the foundation for PPTX support in the MoonBit Office workspace.

The MoonBit team owns maintenance, API evolution, and release scheduling of the
official version. Contributions from the original author are welcome. The
original project remains independent; its own priorities and releases need not
follow the official version.

## Import boundary and modifications

Source packages retain the upstream `src/` layout. Tests, binary fixtures,
examples, and supporting tools are retained. No parser, serializer, XML/OPC
architecture, or ZIP implementation was refactored during this import.

Module references were changed from `t-ujiie-g/moon-pptx` to
`moonbitlang/pptx`. The official module starts at `0.1.0`; example/benchmark
manifests resolve that module through their local workspaces. This is a local
version declaration, not a publication announcement. Generated interfaces were
regenerated; their API changes are limited to the module namespace.

The root README was replaced with import-specific documentation. Unchanged
upstream README, roadmap, and changelog snapshots are retained in `upstream/`;
their release policy and plans do not govern the official module. Upstream
agent overlays, hooks, and GitHub workflows were omitted in favor of Office's
existing repository conventions and CI. The README symlink is retained.

The workspace includes PPTX checks and tests. Unified Office commands and the
seven-module release allowlist remain unchanged. Enabling those integrations
requires separate implementation and validation.

Modified imported files (relative to this directory):

- `README.mbt.md`
- `README.md`
- `examples/README.md`
- `examples/sample-deck/README.md`
- `examples/sample-deck/main/build.mbt`
- `examples/sample-deck/main/moon.pkg`
- `examples/sample-deck/main/showcase.mbt`
- `examples/sample-deck/moon.mod`
- `moon.mod`
- `src/chart/moon.pkg`
- `src/chart/pkg.generated.mbti`
- `src/chart_ex/moon.pkg`
- `src/chart_ex/pkg.generated.mbti`
- `src/comments/moon.pkg`
- `src/comments/pkg.generated.mbti`
- `src/integration/bench_test.mbt`
- `src/integration/moon.pkg`
- `src/integration/pkg.generated.mbti`
- `src/notes/moon.pkg`
- `src/notes/pkg.generated.mbti`
- `src/opc/moon.pkg`
- `src/opc/pkg.generated.mbti`
- `src/oxml/moon.pkg`
- `src/oxml/pkg.generated.mbti`
- `src/pkg.generated.mbti`
- `src/presentation/moon.pkg`
- `src/presentation/pkg.generated.mbti`
- `src/slide/moon.pkg`
- `src/slide/pkg.generated.mbti`
- `src/slide_master/moon.pkg`
- `src/slide_master/pkg.generated.mbti`
- `src/smartart/moon.pkg`
- `src/smartart/pkg.generated.mbti`
- `src/theme/moon.pkg`
- `src/theme/pkg.generated.mbti`
- `src/units/pkg.generated.mbti`
- `src/xml/pkg.generated.mbti`
- `tools/bench/moonbit/main/moon.pkg`
- `tools/bench/moonbit/moon.mod`
- `tools/bench/run.sh`
- `tools/pptx-validate/gen-pptx.sh`

`pkg.generated.mbti` files are compiler-generated; their module identity records
the namespace migration. Hand-edited code/configuration files carry modification
notices. Other imported source and fixture contents match the pinned revision.

## Apache POI fixtures

`test_fixtures/corpus/SOURCES.md` is retained unchanged. It pins the original
Apache POI fixtures to `aa268199243921dd0d9e1dc8d96cc06331280c94`. The matching
[LICENSE](test_fixtures/corpus/LICENSE) and
[NOTICE](test_fixtures/corpus/NOTICE) were copied from that revision's `legal/`
directory, without changes. These notices also cover the embedded copies in
`src/integration/corpus_*_embed_test.mbt`.

Source notices:
- https://github.com/apache/poi/blob/aa268199243921dd0d9e1dc8d96cc06331280c94/legal/LICENSE
- https://github.com/apache/poi/blob/aa268199243921dd0d9e1dc8d96cc06331280c94/legal/NOTICE

## Known limits and follow-up

Tracked in [office.mbt #549](https://github.com/moonbitlang/office.mbt/issues/549):
malformed XML panic handling, slide root attribute retention, namespace
references in attribute values, ZIP resource limits, current-toolchain warnings,
and real PowerPoint compatibility checks. The three parser/preservation cases
were reported by the source-project review handed to this import task; they
were not fixed or independently reproduced during the import.

The existing corpus checks compare parsed models, which cannot detect
information lost during the first parse. Neither those tests nor this import
establish arbitrary lossless round-trips, visual fidelity, or a security audit.

## Import validation

With `moon 0.1.20260920`, all 15 source packages were selected explicitly:

- Native: 1231 passed, 0 failed.
- Wasm: 1231 passed, 0 failed.
- JavaScript: 1231 passed, 0 failed.
- Wasm-GC: 1231 passed, 0 failed.
- `moon check`: passed with 660 inherited warnings; warning-free validation is
  still outstanding and tracked in #549.
- Workspace type checks: native, Wasm, and JavaScript passed (same inherited warnings).
- Sample-deck nested workspace: native tests passed, 1233 total (1231 library
  tests plus 2 example tests).
- `moon info` and `moon fmt`: completed; generated interfaces match upstream
  after module namespace replacement.

No actual PowerPoint display/edit/reopen verification was performed.
