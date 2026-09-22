# Office release ordering

Current workspace and release-check follow-ups:
[#542](https://github.com/moonbitlang/office.mbt/issues/542) and
[#285](https://github.com/moonbitlang/office.mbt/issues/285). The historical
release train below was tracked in
[#155](https://github.com/moonbitlang/office.mbt/issues/155).

The repository is a development workspace, but Mooncakes publishes each module
independently. Workspace resolution can therefore hide a dependency that does
not exist in the registry. A green source CI run is necessary, but it is not
evidence that `moonx moonbitlang/office` can be installed from published
artifacts.

## Workspace layout

The repository root contains `moon.work`, not a publishable module. Publish
from the appropriate module directory. The seven modules and their dependencies
on other modules in this workspace are:

| Directory | Published module | Direct workspace dependencies |
| --- | --- | --- |
| `mbtexcel/` | `moonbitlang/mbtexcel` | None |
| `docx2html/` | `moonbitlang/docx2html` | None |
| `pdflite/` | `moonbitlang/pdflite` | None |
| `pdf2md/` | `moonbitlang/pdf2md` | pdflite |
| `pagelayout/` | `moonbitlang/pagelayout` | docx2html, pdflite |
| `office-lib/` | `moonbitlang/office-lib` | mbtexcel, docx2html |
| `office-cli/` | `moonbitlang/office` | office-lib, docx2html, mbtexcel, pagelayout |

`office-cli` contains the CLI implementation; `office-lib` contains the reusable
SDK. `pdf2md` is an independent CLI module depending on the PDF library.
Directory names do not change the published module coordinates. See
[CHANGELOG.md](../CHANGELOG.md) for public package relocations and API changes.

## Current publishing workflow

The [Publish Mooncakes packages workflow](../.github/workflows/publish.yml)
publishes all seven modules when a GitHub Release is released. Its full order
is `mbtexcel`, `docx2html`, `pdflite`, `pdf2md`, `pagelayout`, `office-lib`, then
`office-cli`. This places each workspace dependency before its consumers.
Every module uses the same `MOONCAKES_MOONBITLANG_TOKEN` repository secret.

For a partial release or retry, manually dispatch the workflow and select a
single module using the `module` input; its default, `all`, publishes the whole
workspace in that order. Single-module publishing requires its dependencies
to already be available in Mooncakes. Bump the versions of modules being
published beforehand: published versions are immutable. If a release fails
partway through, retry only the remaining modules rather than republishing
versions that already succeeded.

Use each module's current `moon.mod` for its version and dependency requirements;
the versions in the historical section below are not current release targets.
The workflow runs source checks, tests, interface generation, and formatting
checks in the workspace before publishing. It does not run the isolated
registry-check scripts: validate registry resolution separately before
publishing each dependent module.

## Current isolated registry checks

Run the applicable script from the repository root after its internal dependency
versions are available in Mooncakes:

```sh
scripts/check_docx2html_registry_release.sh
scripts/check_office_registry_release.sh
scripts/check_office_cli_registry_release.sh
```

These scripts check `docx2html`, `office-lib`, and `office-cli`, respectively.
They require Git, Python 3, and the MoonBit toolchain; native SDK tests also use
.NET 8, which the validator harness installs if it is unavailable. Each script
stages source files in a fresh temporary directory outside `moon.work`, with
the required test fixtures and SDK validators. Fixture staging does not copy
sibling module implementations, so dependencies must resolve from the registry.

The scripts refresh the registry index and run an initial non-frozen native
check to install dependencies. They then print `moon tree` and verify all
selected occurrences of the Office modules' direct internal dependencies
against the exact versions declared in the candidate's `moon.mod`. Subsequent
native/Wasm checks and full-module tests use `--frozen`; the CLI also runs
native/Wasm builds and a JSON help smoke check.

Packaging uses `moon package --frozen`. The scripts inspect the actual ZIP and
reject build/cache entries such as `_build`, `.mooncakes`, and `target` before
the server dry run. They then run `moon publish --dry-run` without `--frozen`:
on Moon 0.1.20260920, publish verifies a freshly extracted copy whose dependencies
must first be installed. The dependency tree must remain unchanged across the
dry run. Success requires the server marker `Dry run completed successfully`,
including when Moon exits 255; exit code zero alone is insufficient.

The manual [docx2html registry workflow](../.github/workflows/docx2html-registry-release-check.yml)
runs the first script. The manual [Office registry workflow](../.github/workflows/office-registry-release-check.yml)
runs separate jobs for both Office modules. These workflows use the organization
secret above and remove the temporary credentials when finished. Local server
dry runs also require credentials authorized for `moonbitlang`; an account
mismatch returns HTTP 403 even if tests and extracted-package checks pass.
The scripts perform dry runs only and do not publish a version.

These three scripts do not cover all seven modules. Isolated validation of
`mbtexcel`, `pdflite`, `pdf2md`, and `pagelayout` must also be arranged when
releasing those modules; broader coverage remains tracked in #542. Record the
toolchain version and distinguish local test/package results from authenticated
server success. Publishing remains an explicit maintainer action.

## Historical release train: Office 0.1.0 and DOCX 0.2.0

The following records the original A4/D2 release order and pinned versions.
Script paths identify the gates used for that release; today's scripts read
current manifests and do not reproduce those historical pins automatically.

For the transaction and bounded-DOCX release train introduced by A4 and D2:

1. merge and validate the source changes without publishing Office;
2. publish `moonbitlang/mbtexcel@0.1.9` from `mbtexcel/`;
3. wait until that exact immutable version resolves from Mooncakes;
4. run `scripts/check_docx2html_registry_release.sh` (or the manual
   `docx2html-registry-release-check` GitHub workflow) outside `moon.work` and
   require its native, Wasm, and publish-dry-run checks to pass;
5. publish `moonbitlang/docx2html@0.2.0` from `docx2html/`;
6. wait until that exact immutable version resolves from Mooncakes;
7. with the Office implementation manifest already staged to require
   `docx2html@0.2.0`, run `scripts/check_office_registry_release.sh` (or the manual
   `office-registry-release-check` GitHub workflow) and require every native,
   Wasm, transaction, raw, DOCX, SDK-validation, and publish-dry-run check to
   pass. Both test commands are unfiltered full-module runs, so the Office root
   integration suite cannot be hidden by green child-package checks;
8. publish `moonbitlang/office-lib@0.1.0` from `office-lib/` and wait until that exact
   immutable version resolves from Mooncakes;
9. run `scripts/check_office_cli_registry_release.sh` outside `moon.work` and
   require its native, Wasm, smoke, and publish-dry-run checks to pass;
10. publish `moonbitlang/office@0.1.0` from `office-cli/`;
11. wait for registry propagation, then verify the public entry point without
    an argument separator: `moonx moonbitlang/office help all --json`.

Never publish `office@0.1.0` first. The executable intentionally requires
`office-lib@0.1.0`; that implementation in turn requires `mbtexcel@0.1.9`,
which contains the strict bounded ZIP reader used by the transaction gate, and
`docx2html@0.2.0`, which contains the bounded annotated reader used by DOCX
commands. Repointing any dependency to a previous version would make a
workspace build green while producing a broken or materially weaker registry
artifact.

### Historical source-breaking boundary

`docx2html@0.2.0` is a deliberate pre-1.0 source-breaking release. Bounded XML
processing adds the machine-readable `ResourceLimit` constructor to the public
`DocxError` cases, so exhaustive matches written for `0.1.x` must handle the new
case. The project has no third-party compatibility obligation yet; making the
break explicit in the version is preferable to hiding it behind a patch release
or weakening typed resource-limit reporting.
