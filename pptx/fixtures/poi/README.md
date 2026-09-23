# Apache POI PPTX fixtures

Seven real-world PPTX fixtures from the pinned Apache POI revision in
[SOURCES.md](SOURCES.md). Original binary contents are retained; Apache POI's
[LICENSE](LICENSE) and [NOTICE](NOTICE) apply to these files and their embedded
copies in `pptx/integration/`.

From the repository root, validate every fixture with the shared Office SDK tool:

```sh
for file in pptx/fixtures/poi/*.pptx; do
  bash scripts/validate_pptx.sh "$file"
done
```

Selected fixtures are embedded in MoonBit tests for all backends. Regenerate
those sources with `python3 scripts/embed_pptx_corpus.py`, then run
`moon fmt pptx/integration`. The generator records
source byte lengths and SHA-256 hashes. The generated files live in
`pptx/integration/corpus_*_embed_test.mbt`.

Model round-trips cannot detect information discarded on the first parse, and
SDK validity does not establish display fidelity. See
[the validation guide](../../../docs/pptx-validation.md).
