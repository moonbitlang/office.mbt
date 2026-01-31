///|
fn collect_shared_strings(
  workbook : Workbook,
) -> (Array[SharedStringEntry], Map[String, Int], Map[String, Int], Int) {
  let shared_strings : Array[SharedStringEntry] = []
  let text_map : Map[String, Int] = {}
  let rich_text_map : Map[String, Int] = {}
  let mut total = 0
  for sheet in workbook.sheets() {
    for cell in sheet.cells() {
      if cell.formula is None && cell.value_type == String {
        total = total + 1
        match cell.rich_text {
          Some(runs) => {
            let idx = shared_strings.length()
            shared_strings.push({
              text: rich_text_plain_text(runs),
              runs: Some(runs),
            })
            rich_text_map.set(cell.reference, idx)
          }
          None =>
            match text_map.get(cell.value) {
              Some(_) => ()
              None => {
                let idx = shared_strings.length()
                shared_strings.push({ text: cell.value, runs: None })
                text_map.set(cell.value, idx)
              }
            }
        }
      }
    }
  }
  (shared_strings, text_map, rich_text_map, total)
}
