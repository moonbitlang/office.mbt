# Stress DOCX Fixtures

These larger DOCX fixtures are vendored for deterministic stress comparison
against the upstream Mammoth JavaScript CLI. They are sourced from docx-corpus:

https://docxcorp.us/

docx-corpus lists the dataset under the Open Data Commons Attribution License
1.0. Keep the original source URLs and SHA-256 hashes with the files so future
fixture refreshes are auditable.

## Vendoring repair

Each file as served by docx-corpus carries **four trailing bytes (`\r\n\r\n`)
after the end-of-central-directory record**. Those bytes sit outside the ZIP
structure: the EOCD declares a zero-length comment, so everything past it is
trailing garbage.

Microsoft Word refuses to open the files in that state, and so do this
repository's readers — `docx2html` rejects them with
`invalid ZIP archive: MissingEndOfCentral`, and the unified `office` CLI with
`archive is not a readable bounded ZIP`. Some readers (Python's `zipfile`, and
Mammoth) scan backwards for the EOCD signature and tolerate the garbage, which
is why the run recorded in `../../../StressTesting.md` predates this repair.

The vendored copies therefore have those four bytes removed and nothing else
changed. Every entry still passes a CRC check, and each file converts to the
HTML sizes `StressTesting.md` records.

`upstream sha-256` is the hash as downloaded — it is what the filename encodes,
so provenance stays auditable. `vendored sha-256` is the hash of the repaired
file actually committed here. To re-derive a vendored file from a fresh
download:

```bash
python3 - <<'PY'
raw = open("downloaded.docx", "rb").read()
e = raw.rfind(b"PK\x05\x06")
end = e + 22 + (raw[e + 20] | (raw[e + 21] << 8))
open("vendored.docx", "wb").write(raw[:end])
PY
```

| file | source URL | size | upstream sha-256 | vendored sha-256 |
|---|---|---:|---|---|
| `docxcorp-reports-en-004f20c73314.docx` | `https://docxcorp.us/documents/004f20c733147e38eda02ebcc052e4649682e7416d315d7764f5feef4ee74f66.docx` | 4.60 MB | `004f20c733147e38eda02ebcc052e4649682e7416d315d7764f5feef4ee74f66` | `3135ed673b36fbc27c7e40365c05b63d8774fd5fcc21fd276109c9d19aaf3fce` |
| `docxcorp-reports-en-015012bf8890.docx` | `https://docxcorp.us/documents/015012bf8890aa22cd2c16558d341e488894e95baf99850f714dff8cdb5629fc.docx` | 4.58 MB | `015012bf8890aa22cd2c16558d341e488894e95baf99850f714dff8cdb5629fc` | `835b0b8d18db7cf1d0c6b45b5534df7f0cfb6640cf4b18b1b8c48da92537cb61` |
| `docxcorp-technical-en-028db84b4b91.docx` | `https://docxcorp.us/documents/028db84b4b91867f1fcce8b7a5bcad1403ed47fc143e566b4040c47d90c85346.docx` | 3.95 MB | `028db84b4b91867f1fcce8b7a5bcad1403ed47fc143e566b4040c47d90c85346` | `192ba26a335b4c135a2b3feab5a174be30fbe2e4b37ff3c9c37e0b5ec1aa6447` |
