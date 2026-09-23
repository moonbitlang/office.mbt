# PPTX provenance

The Office PPTX module is derived from
[t-ujiie-g/moon-pptx](https://github.com/t-ujiie-g/moon-pptx), version `0.10.0`,
revision [`085de51852e30edb04a1032bd1cbbede3b60a53f`](https://github.com/t-ujiie-g/moon-pptx/commit/085de51852e30edb04a1032bd1cbbede3b60a53f),
imported on 2026-09-23. Thank you to t-ujiie-g and the original contributors.

The original Apache-2.0 [LICENSE](LICENSE) is retained without changes.
No tracked NOTICE file was present in that upstream revision. Imported code,
samples, corpus-generation code, and comparative benchmark tools retain this
provenance even where moved to Office's root `scripts/` and `tools/`, or the
module's `pptx/docs/` and shared `ooxml/` foundations.

The MoonBit team owns the official module's maintenance, API evolution, and
release schedule. Contributions from the original author are welcome. The
original project remains independent and may follow its own priorities.

## Office integration changes

- Rename module references to `moonbitlang/pptx` and set the official module's
  initial version to `0.1.0`.
- Use Office's root `moon.work`; remove nested example/benchmark modules.
- Place source packages directly under `pptx/`; organize shared demos under
  `demos/`, executables under `cmd/`, and Apache POI fixtures under `fixtures/poi/`.
- Use root scripts, the shared OpenXML SDK validator, and the normal Office CI
  and release workflow. Keep project documentation in root `docs/`, PPTX guides
  in `pptx/docs/`, and release notes in the root changelog.
- Preserve existing trait-method calls with explicit extensions, use current
  array constructors, and adopt the same warning policy as `mbtexcel` and
  `office-lib`. Qualify test symbols where needed and remove redundant type
  qualifiers where inferred.
- Make execution state, caches, storage, and construction handles private;
  remove internal copy, name-conversion, and validation helpers from the API.
  Expose low-level package access through `opc_package()` and return independent
  OPC collection and payload snapshots. Cache slide order by part identity.

- Extract OPC/XML into `ooxml`, replace ZIP with flate, and adopt
  `Milky2018/xml@0.4.1` for XML reading. Keep the namespace-aware Office writer
  to preserve attribute whitespace.

The original repository's agent overlays, hooks, workflows, roadmap, release
policy, and benchmark workspace do not govern this module. Historical design
notes and release history remain available at the pinned
[upstream tree](https://github.com/t-ujiie-g/moon-pptx/tree/085de51852e30edb04a1032bd1cbbede3b60a53f).
Current changes are recorded in Office's [changelog](../CHANGELOG.md); current
hardening work is tracked in [#549](https://github.com/moonbitlang/office.mbt/issues/549).

## Apache POI fixtures

The fixture files and their embedded copies in `integration/` come from Apache
POI revision `aa268199243921dd0d9e1dc8d96cc06331280c94`. See
[SOURCES.md](fixtures/poi/SOURCES.md), [LICENSE](fixtures/poi/LICENSE), and
[NOTICE](fixtures/poi/NOTICE). The license and notice are copied unchanged from
that revision's `legal/` directory; fixture bytes are unchanged.
