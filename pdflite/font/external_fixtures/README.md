# External Font Fixtures

This directory tracks download metadata for font-focused PDFs used in native
font acceptance. The PDFs themselves are not checked in.

Run:

```sh
./font/external_fixtures/download.py
```

The downloader stores PDFs under `font/external_fixtures/downloads/` and
updates `manifest.lock.json` with file sizes and SHA-256 hashes.

The native fixture tests in `font/fixture_acceptance` are network-free. They
skip when the downloaded PDFs are absent and validate extraction when the files
are present.
