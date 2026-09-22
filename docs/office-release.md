# Office release ordering

Workspace follow-ups: [#542](https://github.com/moonbitlang/office.mbt/issues/542).

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
checks in the workspace before publishing. `moon publish` packages each module
and checks a freshly extracted copy against registry dependencies. Use this
built-in validation rather than maintaining a separate copy-and-test pipeline.

## Publish validation

Run `moon publish` from the selected module directory after its required internal
dependency versions are available in Mooncakes. The publishing workflow handles
this in the order above; it uses the organization's registry credentials.

For a manual preflight without publishing a version, run `moon publish --dry-run`
from that directory. The extracted package needs to install its dependencies,
so do not pass `--frozen` to this command. A server dry run requires credentials
for the module owner. Some Moon versions return exit 255 despite the server
marker `Dry run completed successfully`; read the result rather than interpreting
that exit code alone as a failure.

Source behavior is tested by normal CI. Packaged-module validation is performed
by Moon's publish command. There are no additional isolated registry-check
scripts or dedicated workflows to run.

## Historical release train: Office 0.1.0 and DOCX 0.2.0

The A4/D2 release published mbtexcel 0.1.9, docx2html 0.2.0, office-lib 0.1.0,
then office 0.1.0. Its completion record and validation results are in
[#155](https://github.com/moonbitlang/office.mbt/issues/155#issuecomment-5114580054).
Those versions are historical, not current release targets. The old isolated
release-harness problems were tracked in
[#285](https://github.com/moonbitlang/office.mbt/issues/285); that harness has been
removed in favor of the built-in publish checks.

`docx2html@0.2.0` introduced the `ResourceLimit` constructor in `DocxError`;
exhaustive matches written against 0.1.x needed to handle it. See
[CHANGELOG.md](../CHANGELOG.md) for subsequent module and API changes.
