# PDF CLI password fixtures

The two password files are generated from `pdflite/fixtures/camlpdf/logo.pdf` with qpdf
compatible syntax (the exact encrypted bytes contain random salts):

```sh
qpdf --encrypt user-secret owner-secret 256 -- pdflite/fixtures/camlpdf/logo.pdf office-cli/tests/fixtures/password.pdf
qpdf --encrypt '' owner-secret 256 -- pdflite/fixtures/camlpdf/logo.pdf office-cli/tests/fixtures/empty-password.pdf
```

The CLI acceptance test reads these committed fixtures directly; qpdf is only
needed when regenerating them. It verifies user/owner authentication, wrong
password refusal, exact password-file bytes, and implicit empty-password
handling. Both fixtures contain the same one-page document as the source.

`two-pages.pdf` distinguishes page order by rotation (0 then 90 degrees):

```sh
qpdf pdflite/fixtures/camlpdf/logo.pdf --rotate=+90:1 /tmp/office-pdf-rotated.pdf
qpdf --object-streams=generate --empty --pages pdflite/fixtures/camlpdf/logo.pdf /tmp/office-pdf-rotated.pdf -- office-cli/tests/fixtures/two-pages.pdf
```
