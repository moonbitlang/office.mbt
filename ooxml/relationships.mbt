///|
priv struct Relationship {
  id : String
  rel_type : String
  target : String
  target_mode : String?
}

///|
priv struct Relationships {
  items : Array[Relationship]
  mut next_id : Int
}

///|
fn Relationships::new() -> Relationships {
  { items: [], next_id: 1 }
}

///|
fn Relationships::add_auto(
  self : Relationships,
  rel_type~ : String,
  target~ : String,
  target_mode? : String,
) -> String {
  let id = "rId\{self.next_id}"
  self.next_id = self.next_id + 1
  self.items.push({ id, rel_type, target, target_mode })
  id
}

///|
fn Relationships::to_xml(self : Relationships) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n",
  )
  for item in self.items {
    sb.write_view("  <Relationship Id=\"")
    sb.write_view(escape_xml_attr(item.id))
    sb.write_view("\" Type=\"")
    sb.write_view(escape_xml_attr(item.rel_type))
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(item.target))
    match item.target_mode {
      Some(mode) => {
        sb.write_view("\" TargetMode=\"")
        sb.write_view(escape_xml_attr(mode))
        sb.write_view("\"/>")
      }
      None => sb.write_view("\"/>")
    }
    sb.write_view("\n")
  }
  sb.write_view("</Relationships>")
  sb.to_string()
}
