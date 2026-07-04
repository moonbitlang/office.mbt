# DOCX Stress Testing

The stress harness compares this native MoonBit port against the vendored
`.repos/mammoth` JavaScript CLI on larger public DOCX files. It uses the
vendored fixtures under `tests/stress/fixtures`, writes converted HTML outputs
under `_build/stress/outputs`, and emits `_build/stress/report.md`.

The committed fixtures are listed with source URLs and SHA-256 hashes in
`tests/stress/fixtures/MANIFEST.md`.

## Command

```bash
node scripts/stress_compare.mjs
```

To discover and download a fresh corpus sample into ignored `_build` storage:

```bash
node scripts/stress_compare.mjs --refresh-corpus --count 5 --max-probe 160 --timeout-ms 180000
```

The refresh mode probes URLs from each English docx-corpus manifest below,
chooses the largest downloadable DOCX files, builds `cmd/docx2html`, and then
runs both converters:

- `https://api.docxcorp.us/manifest?type=legal&lang=en&min_confidence=0.8`
- `https://api.docxcorp.us/manifest?type=reports&lang=en&min_confidence=0.8`
- `https://api.docxcorp.us/manifest?type=technical&lang=en&min_confidence=0.8`

## Latest Local Run

Generated on 2026-06-02 from the default harness settings.

| fixture | docx size | moon exit | moon ms | moon html | mammoth exit | mammoth ms | mammoth html | exact hash match | stderr match |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| docxcorp-reports-en-004f20c73314 | 4.60 MB | 0 | 108 | 4.9 KB | 0 | 158 | 4.9 KB | yes | yes |
| docxcorp-reports-en-015012bf8890 | 4.58 MB | 0 | 121 | 8.12 MB | 0 | 202 | 8.12 MB | yes | yes |
| docxcorp-technical-en-028db84b4b91 | 3.95 MB | 0 | 131 | 5.23 MB | 0 | 271 | 5.23 MB | yes | yes |

The first stress run exposed two MoonBit XML string-scanning bugs on the
technical fixture:

- `XmlParser::starts_with` sliced the source string while probing delimiters at
  every index, which can hit the low half of a surrogate pair.
- `decode_xml_entities` advanced by one UTF-16 code unit after `get_char`,
  then could slice from the low half of a surrogate pair on the next entity
  probe.

Both are now covered by focused XML tests, and the large technical fixture
converts to an HTML file with the same SHA-256 hash and stderr diagnostics as
Mammoth.
