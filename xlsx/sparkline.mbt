///|
pub(all) enum SparklineType {
  Line
  Column
  WinLoss
}

///|
pub struct Sparkline {
  range_ref : String
  location : String
}

///|
pub struct SparklineGroup {
  sparkline_type : SparklineType
  sparklines : Array[Sparkline]
}

///|
let sparkline_ext_uri = "{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"

///|
let sparkline_ns_x14 = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"

///|
let sparkline_ns_xm = "http://schemas.microsoft.com/office/excel/2006/main"

///|
fn sparkline_type_to_string(kind : SparklineType) -> String {
  match kind {
    SparklineType::Column => "column"
    SparklineType::WinLoss => "winLoss"
    SparklineType::Line => "line"
  }
}

///|
fn sparkline_type_from_string(value : StringView) -> SparklineType {
  match value.to_string() {
    "column" => SparklineType::Column
    "winLoss" => SparklineType::WinLoss
    _ => SparklineType::Line
  }
}

///|
fn write_sparkline_ext_xml(groups : ArrayView[SparklineGroup]) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <extLst>\n")
  sb.write_view("    <ext uri=\"")
  sb.write_view(sparkline_ext_uri)
  sb.write_view("\">\n")
  sb.write_view("      <x14:sparklineGroups xmlns:x14=\"")
  sb.write_view(sparkline_ns_x14)
  sb.write_view("\" xmlns:xm=\"")
  sb.write_view(sparkline_ns_xm)
  sb.write_view("\">\n")
  for group in groups {
    sb.write_view("        <x14:sparklineGroup type=\"")
    sb.write_view(sparkline_type_to_string(group.sparkline_type))
    sb.write_view("\">\n")
    sb.write_view("          <x14:sparklines>\n")
    for sparkline in group.sparklines {
      sb.write_view("            <x14:sparkline>\n")
      sb.write_view("              <xm:f>")
      sb.write_view(escape_xml_text(sparkline.range_ref))
      sb.write_view("</xm:f>\n")
      sb.write_view("              <xm:sqref>")
      sb.write_view(escape_xml_text(sparkline.location))
      sb.write_view("</xm:sqref>\n")
      sb.write_view("            </x14:sparkline>\n")
    }
    sb.write_view("          </x14:sparklines>\n")
    sb.write_view("        </x14:sparklineGroup>\n")
  }
  sb.write_view("      </x14:sparklineGroups>\n")
  sb.write_view("    </ext>\n")
  sb.write_view("  </extLst>\n")
  sb.to_string()
}

///|
fn parse_sparkline_groups(
  xml : StringView,
) -> Array[SparklineGroup] raise XlsxError {
  let groups : Array[SparklineGroup] = []
  let mut first = true
  for chunk in xml.to_string().split("<x14:sparklineGroup") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    if text.has_prefix("s") {
      continue
    }
    let tag_end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="sparklineGroup tag not closed")
    }
    let tag = text[:tag_end] catch {
        _ => raise XlsxError::InvalidXml(msg="sparklineGroup tag invalid")
      }
    let group_end = match text.find("</x14:sparklineGroup>") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="sparklineGroup end missing")
    }
    let body = text[tag_end + 1:group_end] catch {
        _ => raise XlsxError::InvalidXml(msg="sparklineGroup body invalid")
      }
    let kind = match attr_value(tag, "type") {
      Some(value) => sparkline_type_from_string(value)
      None => SparklineType::Line
    }
    let sparklines : Array[Sparkline] = []
    let mut sparkline_first = true
    for spark_chunk in body.split("<x14:sparkline>") {
      if sparkline_first {
        sparkline_first = false
        continue
      }
      let spark_text = spark_chunk.to_string()
      let spark_end = match spark_text.find("</x14:sparkline>") {
        Some(pos) => pos
        None => raise XlsxError::InvalidXml(msg="sparkline end missing")
      }
      let spark_body = spark_text[:spark_end] catch {
          _ => raise XlsxError::InvalidXml(msg="sparkline body invalid")
        }
      let range = match spark_body.find("<xm:f>") {
        Some(pos) => {
          let rest = spark_body[pos + 6:] catch {
              _ => raise XlsxError::InvalidXml(msg="sparkline range invalid")
            }
          let end = match rest.find("</xm:f>") {
            Some(value) => value
            None =>
              raise XlsxError::InvalidXml(msg="sparkline range end missing")
          }
          unescape_xml_text(try! rest[:end])
        }
        None => raise XlsxError::InvalidXml(msg="sparkline range missing")
      }
      let location = match spark_body.find("<xm:sqref>") {
        Some(pos) => {
          let rest = spark_body[pos + 10:] catch {
              _ => raise XlsxError::InvalidXml(msg="sparkline location invalid")
            }
          let end = match rest.find("</xm:sqref>") {
            Some(value) => value
            None =>
              raise XlsxError::InvalidXml(msg="sparkline location end missing")
          }
          unescape_xml_text(try! rest[:end])
        }
        None => raise XlsxError::InvalidXml(msg="sparkline location missing")
      }
      let (row, col) = cell_ref_to_rc(location)
      let canonical_loc = cell_ref_from(row, col)
      let normalized_range = normalize_range_ref(range)
      sparklines.push({ range_ref: normalized_range, location: canonical_loc })
    }
    if sparklines.length() > 0 {
      groups.push({ sparkline_type: kind, sparklines })
    }
  }
  groups
}
