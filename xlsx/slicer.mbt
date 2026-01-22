///|
pub struct Slicer {
  name : String
} derive(Eq, Show)

///|
pub fn Slicer::new(name : String) -> Slicer raise XlsxError {
  if name == "" {
    raise XlsxError::InvalidSheetOperation(msg="slicer name empty")
  }
  { name, }
}

///|
fn write_slicer_xml(slicer : Slicer, cache_id : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<slicer xmlns=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" name=\"",
  )
  sb.write_view(escape_xml_attr(slicer.name))
  sb.write_view("\" cacheId=\"\{cache_id}\"/>")
  sb.to_string()
}

///|
fn write_slicer_cache_xml(slicer : Slicer, cache_id : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<slicerCacheDefinition xmlns=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" name=\"",
  )
  sb.write_view(escape_xml_attr(slicer.name))
  sb.write_view("\" cacheId=\"\{cache_id}\"/>")
  sb.to_string()
}
