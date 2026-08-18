# Corpus Fixtures

Real-world DOCX files vendored from [docx-corpus](https://docxcorp.us/) — a
classified corpus of Word documents scraped from the public web via Common
Crawl, listed under the Open Data Commons Attribution License 1.0.

These are not stress fixtures (see `../../stress/fixtures` for those). They are
a **covering subset** chosen by greedy set cover from a 591-document stratified
sample (10 document types × 15 languages, 4 documents per non-empty stratum):
every producer family, script family, WML construct, and refusal class the
sample exhibited is represented by at least one file. The selection labels per
file are recorded in `../labels.tsv`; the pinned behaviour of the `docx` CLI on
each is in `../expectations.tsv`.

## License and provenance

The docx-corpus *dataset* is offered under the
[Open Data Commons Attribution License 1.0](https://opendatacommons.org/licenses/by/1-0/),
and this manifest is the attribution it asks for. ODC-By licenses the database,
not the individual collected documents (§2.4) — each document here was crawled
from the public web and may carry its own rights, the same posture as the three
stress fixtures vendored earlier from the same corpus. They are carried as test
inputs with full provenance so any of them can be dropped and re-derived if a
rights question ever arises; `verify.sh` re-checks every vendored hash against
this manifest.

## Naming and repair

`docxcorp-<type>-<lang>-<12 hex>.docx`, where the hex prefixes the SHA-256 of
the file **as served** by the CDN. The URL's own hash names the *originally
scraped* bytes; the CDN has since repaired the WARC-terminator defect for some
files, so the two can differ. Both are recorded below.

Files whose name ends `.raw.docx` are vendored byte-for-byte as served, because
their brokenness IS the fixture: they pin a refusal class (trailing bytes after
EOCD, a phantom zip64 extra field, a non-canonical OPC entry name, a `w:br`
inside `w:t`). All other files are vendored as served except that trailing
bytes after the end-of-central-directory record, when present, are removed —
the same repair the stress fixtures document, and the same one Word requires.

| file | source URL | size | served sha-256 | vendored sha-256 | note |
|---|---|---:|---|---|---|
| `docxcorp-administrative-ko-bf3556b994d2.docx` | `https://docxcorp.us/documents/0b3859a721fac2e8ed83558d9bcc8126de81f317739c3fb78e7fbe42e26e6284.docx` | 9871 | `bf3556b994d26a52f6f7f7f0e1ac839c39ca13571141a1cd3a652f6ab433d2f4` | `bf3556b994d26a52f6f7f7f0e1ac839c39ca13571141a1cd3a652f6ab433d2f4` |  |
| `docxcorp-administrative-ru-a74c66473b56.raw.docx` | `https://docxcorp.us/documents/000b2ee56f39129227a43af36b4e266cbce158e1d96004a2b931bad08d083796.docx` | 31622 | `a74c66473b5695f7727f78035e8db1c8f5c8dd057aaf6b91ca677b4fdce79387` | `a74c66473b5695f7727f78035e8db1c8f5c8dd057aaf6b91ca677b4fdce79387` | kept raw (refusal fixture) |
| `docxcorp-correspondence-es-6f6a6501c9b1.docx` | `https://docxcorp.us/documents/001c15549f0c8b314b764c6c3dbc459cc5f43335a06621a4ee1b4a87f1daf045.docx` | 208487 | `6f6a6501c9b1d51810f406d3e11d60d1d1e5c4967ceb1c18c7c8a885298c80d8` | `6f6a6501c9b1d51810f406d3e11d60d1d1e5c4967ceb1c18c7c8a885298c80d8` |  |
| `docxcorp-correspondence-hi-001c006fd6cc.docx` | `https://docxcorp.us/documents/284b8dd2dd17e01231c7d297fe208d4d69d5144c113517bc34db09d77299200c.docx` | 27256 | `001c006fd6cca495a36c33c864b1593d703d33180673cc9db9d811e9b434b451` | `001c006fd6cca495a36c33c864b1593d703d33180673cc9db9d811e9b434b451` |  |
| `docxcorp-correspondence-pl-f2b6c8e9ecc3.docx` | `https://docxcorp.us/documents/001a0d13911be11f4fe997cc4991a0b367557b5d675eab510d2cd5f372ee268d.docx` | 12647 | `f2b6c8e9ecc36d3f1a51ceb5d7f984ad756d22189d38edb381c1bfaff91958a0` | `f2b6c8e9ecc36d3f1a51ceb5d7f984ad756d22189d38edb381c1bfaff91958a0` |  |
| `docxcorp-creative-he-090faec9d29c.raw.docx` | `https://docxcorp.us/documents/39a231ce2861f1d6773379cc365bb9f19f94dccc3d583358a9dcb4959093413d.docx` | 101777 | `090faec9d29c9a1ac08452fb2ac907c69e94c6ea6832af2d68a0af2d786c2d6d` | `090faec9d29c9a1ac08452fb2ac907c69e94c6ea6832af2d68a0af2d786c2d6d` | kept raw (refusal fixture) |
| `docxcorp-creative-zh-8ad056616c39.raw.docx` | `https://docxcorp.us/documents/03e6089cb6a33223ebadfaed54ec116738fc75b30f597506defd7274c2afe297.docx` | 23163 | `8ad056616c399c15b33fae0315651a89187c683810d3da72b90138d7df423374` | `8ad056616c399c15b33fae0315651a89187c683810d3da72b90138d7df423374` | kept raw (refusal fixture) |
| `docxcorp-educational-zh-2c8278c5119c.docx` | `https://docxcorp.us/documents/00267d8993494cde9c51edff5cfcd0f54d41ba65399b312a2b23021e3e943dde.docx` | 10730 | `2c8278c5119c76e2cba5f13804721efac41c1ea67ee3382d2fb4707d75fcec73` | `2c8278c5119c76e2cba5f13804721efac41c1ea67ee3382d2fb4707d75fcec73` |  |
| `docxcorp-forms-de-e676c4ec45cc.docx` | `https://docxcorp.us/documents/0032d96309ac70292de1369c7f8f7d30989e836bac6848a8bad4191cea8d90ff.docx` | 45676 | `e676c4ec45cc7de2c3efc18fe4ecd78260cae8c8b5b55a2293fa416fb2a1ce5b` | `e676c4ec45cc7de2c3efc18fe4ecd78260cae8c8b5b55a2293fa416fb2a1ce5b` |  |
| `docxcorp-forms-he-eab0302a1665.docx` | `https://docxcorp.us/documents/0c4bd8ed9ab6731891d23507a25a71c7f7f2d3c000d299288a9d93a3dd7a461c.docx` | 171455 | `eab0302a16659bf34c5a0ac051b7042a93743f028e532c105d6fc6c26da8133e` | `eab0302a16659bf34c5a0ac051b7042a93743f028e532c105d6fc6c26da8133e` |  |
| `docxcorp-forms-ja-3186dce1c998.docx` | `https://docxcorp.us/documents/000af17f67209a4fbaeda7573992d956d66d3eb76a32b275886f824c14024ac6.docx` | 20310 | `3186dce1c998313a5319dbb574bef76e4abd41b2bc89509d8378df0ee3fa56e7` | `3186dce1c998313a5319dbb574bef76e4abd41b2bc89509d8378df0ee3fa56e7` |  |
| `docxcorp-legal-en-b27159649b19.docx` | `https://docxcorp.us/documents/0001482d595c399b4312d0d9a6f7cf097911aed875aaae5a5b888174a98db54c.docx` | 168369 | `b27159649b1938fb0c29f04cf837eb576298d41cf5823ed46e7f8e4048408649` | `b27159649b1938fb0c29f04cf837eb576298d41cf5823ed46e7f8e4048408649` |  |
| `docxcorp-policies-de-86f43e58d8a6.docx` | `https://docxcorp.us/documents/00f38e9380e590078bd896cff2cc71261c136c33bd64e169493c7f2369fee841.docx` | 27137 | `86f43e58d8a653027cd0593e376fcaa9733cb40729484fbb3a662b38579c1328` | `86f43e58d8a653027cd0593e376fcaa9733cb40729484fbb3a662b38579c1328` |  |
| `docxcorp-policies-ru-c417943be184.docx` | `https://docxcorp.us/documents/002b4f4d8976804c283e6f90cc51f02c7fa5ca9027ffe491b141ae79efdb918f.docx` | 18640 | `c417943be184ec22081206cae6047beedeef4ae2971814cb6649a4af50799580` | `c417943be184ec22081206cae6047beedeef4ae2971814cb6649a4af50799580` |  |
| `docxcorp-policies-th-2f3af94f8afa.docx` | `https://docxcorp.us/documents/05495f51877e0102eea061456c7c9f2bc155857f7c60932ea0dbed246b7d0f96.docx` | 523501 | `2f3af94f8afa417a0fff9dd340fea631d048d5e39f011ac1ea112baa5e3993de` | `2f3af94f8afa417a0fff9dd340fea631d048d5e39f011ac1ea112baa5e3993de` |  |
| `docxcorp-policies-zh-2d2bef8d23da.docx` | `https://docxcorp.us/documents/0015b6893eb12d21881ab14cb4982695fb69409ef06d025d83daa4f0bd5f05f1.docx` | 11912 | `2d2bef8d23da568dc70ec8731abe8ffcfce0d23f9cb146d947eeb257df04e722` | `2d2bef8d23da568dc70ec8731abe8ffcfce0d23f9cb146d947eeb257df04e722` |  |
| `docxcorp-reference-ar-2dc29c0624a4.docx` | `https://docxcorp.us/documents/03e674e77e83b0d9b6c93ea2f60d906f4654a0315f20fa63e3ceb49a7f18feee.docx` | 23127 | `2dc29c0624a406d6e76e8c9178148777f0242224d7fb3521ca6d65a3e43d7cc7` | `2dc29c0624a406d6e76e8c9178148777f0242224d7fb3521ca6d65a3e43d7cc7` |  |
| `docxcorp-reference-pl-012c3de280d2.docx` | `https://docxcorp.us/documents/012c3de280d2c58c37aa05581b5b9d914193e17d37eb30218ca8916573c79def.docx` | 11552 | `012c3de280d2c58c37aa05581b5b9d914193e17d37eb30218ca8916573c79def` | `36aa91b97d20df3cef2cb6c99cf4572567170e29a01f0ff10ffddbbe02ad1885` | trailing 2484B repaired |
| `docxcorp-reference-pl-012c3de280d2.raw.docx` | `https://docxcorp.us/documents/012c3de280d2c58c37aa05581b5b9d914193e17d37eb30218ca8916573c79def.docx` | 14036 | `012c3de280d2c58c37aa05581b5b9d914193e17d37eb30218ca8916573c79def` | `012c3de280d2c58c37aa05581b5b9d914193e17d37eb30218ca8916573c79def` | kept raw (refusal fixture) |
| `docxcorp-reference-ru-e143afa7880b.docx` | `https://docxcorp.us/documents/00505c0e0c2a50e50bbdd58afac9478faa9a4ab012667a8f123a7b8daf54cc15.docx` | 100490 | `e143afa7880b2ecaab2343794704be9ab33c79c1c6081dd266812992842d36ab` | `e143afa7880b2ecaab2343794704be9ab33c79c1c6081dd266812992842d36ab` |  |
| `docxcorp-reference-zh-c9ef8f657ed2.docx` | `https://docxcorp.us/documents/01525afbda4e308565d043efa94c2ef627cffd1f16ec283e7ae92abc38ff91e2.docx` | 38364 | `c9ef8f657ed2f5d602b26f61f5a65b7fc174518313a52dfff88eecb633b1e6b8` | `c9ef8f657ed2f5d602b26f61f5a65b7fc174518313a52dfff88eecb633b1e6b8` |  |
| `docxcorp-technical-en-40025988ff1a.docx` | `https://docxcorp.us/documents/00148d71f590d0216936130bdada1427753df69eb8e2d0a527dc0a67f0263b33.docx` | 53371 | `40025988ff1aa58655f75ced4f877ec98e74c0a3e979f21bca09e9f35a6236f2` | `40025988ff1aa58655f75ced4f877ec98e74c0a3e979f21bca09e9f35a6236f2` |  |
| `docxcorp-technical-es-9b6ac87c19f2.docx` | `https://docxcorp.us/documents/008726f798d340e8a479f1f488a0aee583923c4aaf29b0391c272168c8fcac45.docx` | 102060 | `9b6ac87c19f2de73029cb8f6b357c9f59ee0cffe43110da04b868326f2c6d4d8` | `9b6ac87c19f2de73029cb8f6b357c9f59ee0cffe43110da04b868326f2c6d4d8` |  |
| `docxcorp-technical-ja-d6e4e8204ad5.docx` | `https://docxcorp.us/documents/30a3784e0b24ec749348f5ac3de878140566f60314a3b2d65e756cd835f00219.docx` | 938979 | `d6e4e8204ad5f592113b7948521e9a4ac054ac9e8ff3d524806918ae0344d521` | `d6e4e8204ad5f592113b7948521e9a4ac054ac9e8ff3d524806918ae0344d521` |  |
| `docxcorp-technical-vi-9a2efb9f754e.docx` | `https://docxcorp.us/documents/2a3b08aeb2a1fa03231f6707ca130d7654d72ebd0f9cd782c484170dfec33083.docx` | 3258615 | `9a2efb9f754e4e7e2be56d422cea61382212e4d00e5d4e203dec16b6b28f4a28` | `9a2efb9f754e4e7e2be56d422cea61382212e4d00e5d4e203dec16b6b28f4a28` |  |
