///|
pub struct PivotTable {
  name : String
  table_id : Int
  cache_id : Int
  table_xml : String
  cache_definition_xml : String
  cache_records_xml : String?
}

///|
pub fn PivotTable::new(
  table_xml : String,
  cache_definition_xml : String,
  cache_records_xml? : String = "",
  name? : String = "",
) -> PivotTable raise XlsxError {
  if table_xml == "" {
    raise InvalidPivotTable(msg="pivot table xml empty")
  }
  if cache_definition_xml == "" {
    raise InvalidPivotTable(msg="pivot cache definition empty")
  }
  let records = if cache_records_xml == "" {
    None
  } else {
    Some(cache_records_xml)
  }
  {
    name,
    table_id: 0,
    cache_id: 0,
    table_xml,
    cache_definition_xml,
    cache_records_xml: records,
  }
}
