The canonical office command identifies structurally valid XLSX and DOCX
packages in text or JSON mode.

  $ office.exe identify "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx"
  xlsx

  $ office.exe identify "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx"
  docx

  $ office.exe identify "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --json | jq -c '{schema,format}'
  {"schema":"office.identify/1","format":"docx"}

Extension/content mismatches and malformed input fail non-zero.

  $ office.exe identify > missing-file.out 2>&1; echo $?
  1
  $ head -1 missing-file.out
  error: 'file' requires at least 1 values but only 0 were provided

  $ cp "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" report.xlsx
  $ office.exe identify report.xlsx
  office: file extension says xlsx, but package content is docx
  [1]

  $ printf 'not zip' > broken.docx; office.exe identify broken.docx
  office: invalid Office package: archive is not a readable ZIP
  [1]
