///|
// Document font families → bundled metric-compatible families. The layout
// engine never sees a family it does not bundle: unknown names resolve by
// this table, then by default to Carlito (Word's default Calibri).

///|
/// Map a document-authored family name to a bundled family. Matching is
/// case-insensitive. Metric-compatible pairs: Calibri→Carlito,
/// Arial→Liberation Sans, Times New Roman→Liberation Serif,
/// Courier New→Liberation Mono. CJK families map to Noto Sans SC.
pub fn resolve_family(name : String) -> String {
  match name.to_lower() {
    "carlito" | "calibri" | "calibri light" => "Carlito"
    "liberation sans" | "arial" | "helvetica" | "helvetica neue" | "segoe ui" =>
      "Liberation Sans"
    "liberation serif"
    | "times new roman"
    | "times"
    | "cambria"
    | "georgia"
    | "garamond"
    | "book antiqua"
    | "palatino linotype" => "Liberation Serif"
    "liberation mono"
    | "courier new"
    | "courier"
    | "consolas"
    | "cascadia code"
    | "menlo"
    | "monaco" => "Liberation Mono"
    "noto sans sc"
    | "simsun"
    | "simhei"
    | "kaiti"
    | "fangsong"
    | "microsoft yahei"
    | "dengxian"
    | "songti sc"
    | "pingfang sc"
    | "pmingliu"
    | "mingliu"
    | "microsoft jhenghei"
    | "ms mincho"
    | "ms gothic"
    | "ms pmincho"
    | "ms pgothic"
    | "yu mincho"
    | "yu gothic"
    | "meiryo"
    | "hiragino sans"
    | "hiragino mincho pro"
    | "malgun gothic"
    | "batang"
    | "gulim" => "Noto Sans SC"
    _ => "Carlito"
  }
}
