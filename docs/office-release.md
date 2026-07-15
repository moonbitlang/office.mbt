# Office release ordering

Tracking issue: [#155](https://github.com/moonbitlang/office.mbt/issues/155).

The repository is a development workspace, but Mooncakes publishes each module
independently. Workspace resolution can therefore hide a dependency that does
not exist in the registry. A green source CI run is necessary, but it is not
evidence that `bobzhang/office` can be installed from published artifacts.

## Required order

For the transaction and bounded-DOCX release train introduced by A4 and D2:

1. merge and validate the source changes without publishing Office;
2. publish `bobzhang/mbtexcel@0.1.9` from the repository root;
3. wait until that exact immutable version resolves from Mooncakes;
4. run `scripts/check_docx2html_registry_release.sh` (or the manual
   `docx2html-registry-release-check` GitHub workflow) outside `moon.work` and
   require its native, Wasm, and publish-dry-run checks to pass;
5. publish `bobzhang/docx2html@0.1.45` from `docx2html/`;
6. wait until that exact immutable version resolves from Mooncakes;
7. with Office's source manifest already staged to require
   `docx2html@0.1.45`, run `scripts/check_office_registry_release.sh` (or the manual
   `office-registry-release-check` GitHub workflow) and require every native,
   Wasm, transaction, raw, DOCX, SDK-validation, and publish-dry-run check to
   pass;
8. only then publish `bobzhang/office@0.1.0` from `office/`.

Never publish `office@0.1.0` first. Its manifest intentionally requires
`mbtexcel@0.1.9`, which contains the strict bounded ZIP reader used by the
transaction gate, and `docx2html@0.1.45`, which contains the bounded annotated
reader used by DOCX commands. Repointing either dependency to its previous
version would make a workspace build green while producing a broken or
materially weaker registry artifact.

Publishing changes external registry state and remains an explicit maintainer
action. The release checks copy each module outside the repository and outside
`moon.work`, so dependency resolution cannot silently substitute workspace
members. MoonBit versions disagree about the process status of both successful
and failed publish dry runs, so the scripts require the tool's exact success
marker regardless of exit status.
