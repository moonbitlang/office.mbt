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
/// Builds an in-memory pivot table. `cache_id` stays 0 for pivots whose XML the
/// caller supplied, meaning "the writer picks a free id"; generated pivots pass
/// the id that is already baked into `table_xml` as `cacheId`.
fn PivotTable::new(
  table_xml : String,
  cache_definition_xml : String,
  cache_records_xml? : String = "",
  name? : String = "",
  cache_id? : Int = 0,
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
    cache_id,
    table_xml,
    cache_definition_xml,
    cache_records_xml: records,
  }
}
