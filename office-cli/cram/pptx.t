PPTX identification, bounded reading, and atomic creation use the unified CLI.

  $ office.exe create pptx deck.pptx --title 'Hello MoonBit' --json | jq -c '{success,format:.data.format,slides:.data.slide_count,committed:.data.transaction.committed}'
  {"success":true,"format":"pptx","slides":1,"committed":true}

  $ office.exe identify deck.pptx --json | jq -c '.data'
  {"schema":"office.identify/1","file":"deck.pptx","format":"pptx"}

  $ office.exe outline deck.pptx --json | jq -c '.data | {schema,format,slide_count,slides}'
  {"schema":"office.pptx.outline/1","format":"pptx","slide_count":1,"slides":[{"index":1,"part":"/ppt/slides/slide1.xml","shape_count":1}]}

  $ office.exe text deck.pptx --json | jq -c '.data | {schema,returned,truncated,slides}'
  {"schema":"office.pptx.text/1","returned":1,"truncated":false,"slides":[{"index":1,"part":"/ppt/slides/slide1.xml","text":"Hello MoonBit","notes":""}]}

  $ office.exe text deck.pptx --offset 1 --limit 0 --json | jq -c '.data | {returned,truncated,slides}'
  {"returned":0,"truncated":false,"slides":[]}

  $ office.exe create pptx dry.pptx --dry-run --json | jq -c '.data.transaction | {dry_run,committed}'
  {"dry_run":true,"committed":false}

  $ test ! -e dry.pptx

  $ office.exe create pptx deck.pptx --title Changed --json > refusal.json 2>&1
  [1]

  $ jq -c '{success,code:.error.code}' refusal.json
  {"success":false,"code":"office.transaction.output_exists"}

  $ office.exe text deck.pptx --under /pptx/slide[1] --json > refusal.json 2>&1
  [1]

  $ jq -c '{success,code:.error.code}' refusal.json
  {"success":false,"code":"office.invalid_arguments"}

  $ office.exe preview deck.pptx --output preview.html --json > refusal.json 2>&1
  [1]

  $ jq -c '{success,code:.error.code}' refusal.json
  {"success":false,"code":"office.unsupported_format"}

  $ office.exe outline deck.pptx --max-output-chars 100 --json > refusal.json 2>&1
  [1]

  $ jq -c '{success,code:.error.code}' refusal.json
  {"success":false,"code":"office.pptx.resource_limit"}

  $ cp deck.pptx mismatch.docx

  $ office.exe identify mismatch.docx --json > refusal.json 2>&1
  [1]

  $ jq -c '{success,code:.error.code}' refusal.json
  {"success":false,"code":"office.format_mismatch"}

  $ office.exe help pptx --json | jq -c '[.data.records[].name]'
  ["pptx","identify","outline","text","create"]
