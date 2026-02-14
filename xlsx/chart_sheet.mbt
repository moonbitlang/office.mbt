///|
pub struct ChartSheet {
  mut name : String
  mut state : SheetState
  chart_xml : String
}

///|
fn ChartSheet::new(name : String, chart_xml : String) -> ChartSheet {
  { name, state: Visible, chart_xml }
}

///|
pub fn ChartSheet::name(self : ChartSheet) -> String {
  self.name
}

///|
pub fn ChartSheet::state(self : ChartSheet) -> SheetState {
  self.state
}

///|
pub fn ChartSheet::set_state(self : ChartSheet, state : SheetState) -> Unit {
  self.state = state
}

///|
pub fn ChartSheet::chart_xml(self : ChartSheet) -> String {
  self.chart_xml
}
