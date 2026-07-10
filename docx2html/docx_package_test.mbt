///|
fn header_footer_docx() -> Bytes {
  decode_fixture(
    (
      #|UEsDBBQAAAAIAIut6lwkGTCZDAEAAC4DAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbMWSzU7DMBCE
      #|7zyF5WuVOO0BIZSkB36OwKE8wMreNBax1/K6pX17nKb0gMrPAcTR3pn5xivXy50bxBYjW/KNnJeV
      #|FOg1GevXjXxe3RdXUnACb2Agj43cI8tle1Gv9gFZZLPnRvYphWulWPfogEsK6POko+gg5WNcqwD6
      #|BdaoFlV1qTT5hD4VacyQbX2LHWyGJO52+XoqEnFgKW4m4chqJIQwWA0pz9XWmw+U4kgos/Og4d4G
      #|nmWBVGcJ4+RzwNH3mDcTrUHxBDE9gMsq9UrRKEN647Kz/DrmTE/qOqvx5B/TQiSNzHnlbihPEwfW
      #|z77r0SMYjPPfrzEF/5C/+Dd+R5T+5P1T8DtfHb57+wZQSwMEFAAAAAgAi63qXLmBRHGwAAAAKgEA
      #|AAsAAABfcmVscy8ucmVsc43POw7CMAwG4J1TRN5pWgaEUJMuCKkrKgeIEjeNaB5KwqO3JwMDIAZG
      #|278/y233sDO5YUzGOwZNVQNBJ70yTjM4D8f1DkjKwikxe4cMFkzQ8VV7wlnkspMmExIpiEsMppzD
      #|ntIkJ7QiVT6gK5PRRytyKaOmQciL0Eg3db2l8d0A/mGSXjGIvWqADEvAf2w/jkbiwcurRZd/nPhK
      #|FFlEjZnB3UdF1atdFRYob+nHi/wJUEsDBBQAAAAIAIut6lwE/wfWSgEAAKQCAAARAAAAd29yZC9k
      #|b2N1bWVudC54bWyNUttOwzAMfecroryzbGXANK2dhBASD0gTlw/IGqeN1CaR4zHG1+NexnhAsBc3
      #|Jz7n2LG7Wn+0jXgHTC74XM4mUynAl8E4X+Xy7fXhciFFIu2NboKHXB4gyXVxsdovTSh3LXgS7ODT
      #|cp/LmigulUplDa1OkxDBc84GbDUxxErtA5qIoYSUuEDbqGw6vVGtdl6ONniOTbDWlXA/NjCYIDSa
      #|+BGpdjHJghvcBnPovrEL2AUq7vhOWIeJRNSoK9SxXqku00XsY/xVlKAM3vyjYhJtelUN2gA+gwXk
      #|eYJg8iHy/AxYvWtIClw6k0t8NDOp/hL0zf6gZwPdhkDn+V8Ngli9fDKL1zTLsjmvmUvy+XrB55Hw
      #|pLHzCZHv5wMFXVXTCW4DUWhPuAH7Izs8IZe3WQ+HFr9htaMejuXIUQObSvXDO85NHbemTv9X8QVQ
      #|SwMEFAAAAAgAi63qXFBO9p/CAAAAHAIAABwAAAB3b3JkL19yZWxzL2RvY3VtZW50LnhtbC5yZWxz
      #|tZHNCsIwDIDvPkXJ3XWbICJ2XkTwKvoAoc1+cGtKW0Xf3qIgCiIe9PgR8n2ELJbnoRcn8qFjq6DI
      #|chBkNZvONgr2u/V4BiJEtAZ7tqTgQgGW1WixpR5j2glt54JIEhsUtDG6uZRBtzRgyNiRTZOa/YAx
      #|oW+kQ33AhmSZ51Ppnx1QvTjFxijwG1OA2F0cfePmuu40rVgfB7LxTUK2hIZ8MqJvKCbnjYssiUC+
      #|75f/75ef+pNf9mvm+Ny/8+N++fLU6gpQSwMEFAAAAAgAi63qXG4iLKibAAAAwgAAABAAAAB3b3Jk
      #|L2hlYWRlcjEueG1sHc5BCsIwEAXQvacI2dtUFyKlaTfiCfQAoZk2hWQSJqOttzfp5sHw+Z/pxz14
      #|8QXKa0QtL00rBeAU7YqLlu/X83yXIrNBa3xE0PIHWY7Dqd86Z0mUMuZu09Ixp06pPDkIJjcxAZZs
      #|jhQMl5MWtUWyieIEOZft4NW1bW8qmBXlUNZShSo8PGA2H8/CgbFAgmHnXtWgSofpsLww/AFQSwME
      #|FAAAAAgAi63qXEcxuvWYAAAAwAAAABAAAAB3b3JkL2hlYWRlcjIueG1sHc7BCsIwDAbgu09RctdO
      #|DyJj3W57An2Assa1sKYlKU7f3naXD5Kf/GSYvnFTH2QJiQxcLx0opCW5QKuB13M+P0BJseTslggN
      #|/FBgGk/D3nvHqh6T9LsBX0rutZbFY7RySRmpZu/E0ZY68qr3xC5zWlCkdsdN37rurqMNBGNtyw1u
      #|lHEOLEVlu6LyaB3yoNu6yYf5sD4w/gFQSwMEFAAAAAgAi63qXE+MnP+TAAAAugAAABAAAAB3b3Jk
      #|L2Zvb3RlcjEueG1sHc0xDoMwDAXQvaeIvJfQDlWFCGycoD1ABIYikTiyrUJv34TlSfaXv9v+CJv5
      #|IstK0cGtqsFgHGla4+Lg/RquTzCiPk5+o4gOfijQd5d2b2Zlk4+jNLuDj2pqrJXxg8FLRQljzmbi
      #|4DWPvNideEpMI4rk7rDZe10/bPBrhC63pQIXtBuIFNkoHtrasijyaTrNr7s/UEsBAhQDFAAAAAgA
      #|i63qXCQZMJkMAQAALgMAABMAAAAAAAAAAAAAAIABAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwEC
      #|FAMUAAAACACLrepcuYFEcbAAAAAqAQAACwAAAAAAAAAAAAAAgAE9AQAAX3JlbHMvLnJlbHNQSwEC
      #|FAMUAAAACACLrepcBP8H1koBAACkAgAAEQAAAAAAAAAAAAAAgAEWAgAAd29yZC9kb2N1bWVudC54
      #|bWxQSwECFAMUAAAACACLrepcUE72n8IAAAAcAgAAHAAAAAAAAAAAAAAAgAGPAwAAd29yZC9fcmVs
      #|cy9kb2N1bWVudC54bWwucmVsc1BLAQIUAxQAAAAIAIut6lxuIiyomwAAAMIAAAAQAAAAAAAAAAAA
      #|AACAAYsEAAB3b3JkL2hlYWRlcjEueG1sUEsBAhQDFAAAAAgAi63qXEcxuvWYAAAAwAAAABAAAAAA
      #|AAAAAAAAAIABVAUAAHdvcmQvaGVhZGVyMi54bWxQSwECFAMUAAAACACLrepcT4yc/5MAAAC6AAAA
      #|EAAAAAAAAAAAAAAAgAEaBgAAd29yZC9mb290ZXIxLnhtbFBLBQYAAAAABwAHAL0BAADbBgAAAAA=
    ),
  )
}

///|
test "read_docx_package surfaces sections and header/footer stories" {
  let doc_package = @docx2html.read_docx_package(header_footer_docx())
  // The body is identical to the body-only surface.
  assert_eq(doc_package.document, @docx2html.read_docx(header_footer_docx()))
  debug_inspect(doc_package.messages, content="[]")
  // One body-final section referencing two headers (default + first) and
  // one footer; parts dedup by path, in first-reference order.
  guard doc_package.sections is [section]
  debug_inspect(section.ends_after_paragraph, content="None")
  debug_inspect(
    section.headers,
    content=(
      #|[{ variant: "default", part: 0 }, { variant: "first", part: 1 }]
    ),
  )
  debug_inspect(
    section.footers,
    content=(
      #|[{ variant: "default", part: 0 }]
    ),
  )
  guard doc_package.headers is [default_header, first_header]
  assert_eq(
    @docx2html.extract_raw_text_from_document(
      @docx2html.document(default_header.body),
    ).value,
    "Default header text\n\n",
  )
  assert_eq(
    @docx2html.extract_raw_text_from_document(
      @docx2html.document(first_header.body),
    ).value,
    "First page header\n\n",
  )
  guard doc_package.footers is [footer]
  assert_eq(
    @docx2html.extract_raw_text_from_document(@docx2html.document(footer.body)).value,
    "Footer text\n\n",
  )
}

///|
test "a body-only document yields its empty final section and no parts" {
  // The Mammoth single-paragraph fixture carries a bare body-final sectPr:
  // one section, no header/footer references, no parts.
  let plain = @docx2html.read_docx_package(single_paragraph_docx())
  debug_inspect(
    plain.sections,
    content=(
      #|[{ ends_after_paragraph: None, headers: [], footers: [] }]
    ),
  )
  debug_inspect(plain.headers, content="[]")
  debug_inspect(plain.footers, content="[]")
}
