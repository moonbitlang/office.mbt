# PPTX validation

PPTX uses the Office workspace's shared OpenXML SDK validator in
`tools/openxml-validator`, with the same .NET setup and serialized build cache
as DOCX and XLSX. Run from the repository root:

```sh
bash scripts/generate_pptx_demos.sh
bash scripts/validate_pptx.sh demos_out_pptx/sample.pptx
for file in pptx/fixtures/poi/*.pptx; do
  bash scripts/validate_pptx.sh "$file"
done
```

The native `pptx/sdk_validity` tests validate the demo and seven Apache POI
fixtures, and check that unrelated schema errors still fail with the SmartArt
baseline enabled. The CI CLI smoke job also generates and validates the demo
through the executable. The validator uses Office2021 for PPTX; DOCX/XLSX retain Office2013.

`tools/openxml-validator/pptx-baseline.txt` retains the upstream SDK exception
for the SmartArt cached-drawing relationship. Matching diagnostics are printed
with `baseline:` rather than hidden. All other SDK errors fail the command.
Do not expand the baseline to hide a regression; document and track any new
exception explicitly. The baseline applies only when passed by the PPTX wrapper.

The MoonBit corpus tests embed selected fixture bytes and exercise parsed-model
round-trips across backends. Regenerate their sources with:

```sh
python3 scripts/embed_pptx_corpus.py
moon fmt pptx/integration
```

Neither model equality nor SDK validation establishes preservation of every
source attribute or PowerPoint display/edit compatibility. See
[PPTX limits](../pptx/README.mbt.md#limits) and the
[fixture provenance](../pptx/fixtures/poi/SOURCES.md).
