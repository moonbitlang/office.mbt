// A small scanner over retained chart XML. The reader keeps a chart's
// `c:chart` markup verbatim (there is no structured chart read-back), so the
// outline extracts just enough metadata for an agent to know what the chart
// is: its plot kinds and the cell ranges each series draws from.

///|
/// The closed set of DrawingML plot-kind element names the scanner looks
/// for. One `c:plotArea` may hold several (a combo chart).
let chart_kind_tags : Array[String] = [
  "areaChart", "area3DChart", "barChart", "bar3DChart", "bubbleChart", "doughnutChart",
  "lineChart", "line3DChart", "ofPieChart", "pieChart", "pie3DChart", "radarChart",
  "scatterChart", "stockChart", "surfaceChart", "surface3DChart",
]

///|
/// Series metadata scanned from one `c:ser` block: the `c:f` cell-range
/// references of its name, categories, and values, when present.
pub struct ChartSeriesMeta {
  name : String?
  categories : String?
  values : String?
} derive(Eq, @debug.Debug)

///|
/// The plot-kind element names present in the chart XML (e.g. `barChart`),
/// in `chart_kind_tags` order, each at most once.
pub fn chart_kinds(xml : String) -> Array[String] {
  let kinds = []
  for tag in chart_kind_tags {
    // Match both `<c:barChart>` and `<c:barChart ...>`.
    if xml.contains("<c:" + tag + ">") || xml.contains("<c:" + tag + " ") {
      kinds.push(tag)
    }
  }
  kinds
}

///|
/// The per-series range references scanned from every `c:ser` block, in
/// document order. Category/value roles follow the classic chart layout
/// (`c:cat`/`c:val`); scatter and bubble charts use `c:xVal`/`c:yVal`,
/// which map to categories/values respectively.
pub fn chart_series(xml : String) -> Array[ChartSeriesMeta] {
  let series = []
  let view = xml[:]
  for from = 0 {
    match find_from(view, "<c:ser>", from) {
      None => break
      Some(start) => {
        let end = match find_from(view, "</c:ser>", start) {
          Some(end) => end
          // Unclosed block in malformed XML: scan to the end, then stop.
          None => view.length()
        }
        let block = view[start:end]
        series.push({
          name: element_ref(block, "c:tx"),
          categories: first_present(block, "c:cat", "c:xVal"),
          values: first_present(block, "c:val", "c:yVal"),
        })
        continue end
      }
    }
  }
  series
}

///|
/// Position of `needle` in `view` at or after `from`, as an offset into
/// `view` itself.
fn find_from(view : StringView, needle : StringView, from : Int) -> Int? {
  if from >= view.length() {
    return None
  }
  match view[from:].find(needle) {
    Some(offset) => Some(from + offset)
    None => None
  }
}

///|
/// The first of two element names that yields a `c:f` reference.
fn first_present(block : StringView, tag : String, alt : String) -> String? {
  match element_ref(block, tag) {
    Some(reference) => Some(reference)
    None => element_ref(block, alt)
  }
}

///|
/// The text of the first `<c:f>…</c:f>` inside the first `<tag>…</tag>`
/// element of `block`, or `None` when either is absent or empty.
fn element_ref(block : StringView, tag : String) -> String? {
  let open = "<" + tag + ">"
  let start = match block.find(open[:]) {
    Some(start) => start + open.length()
    None => return None
  }
  let end = match find_from(block, ("</" + tag + ">")[:], start) {
    Some(end) => end
    None => return None
  }
  let element = block[start:end]
  let ref_start = match element.find("<c:f>") {
    Some(offset) => offset + "<c:f>".length()
    None => return None
  }
  let ref_end = match find_from(element, "</c:f>", ref_start) {
    Some(end) => end
    None => return None
  }
  let reference = element[ref_start:ref_end].to_owned()
  if reference == "" {
    None
  } else {
    Some(reference)
  }
}
