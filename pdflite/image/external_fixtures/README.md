# External Image Fixtures

This directory tracks download metadata for larger image-heavy PDFs used in
native image acceptance. The PDFs themselves are not checked in.

Run:

```sh
./image/external_fixtures/download.py
```

The downloader stores PDFs under `image/external_fixtures/downloads/` and
updates `manifest.lock.json` with file sizes and SHA-256 hashes.

The native fixture tests in `image/fixture_acceptance` are network-free. They
skip when the downloaded PDFs are absent and validate extraction when the files
are present.
