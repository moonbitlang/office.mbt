# Office release ordering

Tracking issue: [#155](https://github.com/moonbitlang/office.mbt/issues/155).

The repository is a development workspace, but Mooncakes publishes each module
independently. Workspace resolution can therefore hide a dependency that does
not exist in the registry. A green source CI run is necessary, but it is not
evidence that `bobzhang/office` can be installed from published artifacts.

## Required order

For the transaction release train introduced by A4:

1. merge and validate the source changes without publishing either module;
2. publish `bobzhang/mbtexcel@0.1.9` from the repository root;
3. wait until that exact immutable version resolves from Mooncakes;
4. run `scripts/check_office_registry_release.sh` (or the manual
   `office-registry-release-check` GitHub workflow) and require every native,
   Wasm, transaction, and publish-dry-run check to pass;
5. only then publish `bobzhang/office@0.1.0` from `office/`.

Never publish `office@0.1.0` first. Its manifest intentionally requires
`mbtexcel@0.1.9`, which contains the strict bounded ZIP reader used by the
transaction gate. Repointing it to `0.1.8` would make a workspace build green
while producing a materially weaker registry artifact.

Publishing changes external registry state and remains an explicit maintainer
action. The release check copies `office/` outside the repository and outside
`moon.work`, so dependency resolution cannot silently substitute workspace
members. Some MoonBit versions return a nonzero process status after a
successful publish dry run; the script accepts that status only when the tool
also emits its exact success marker.
