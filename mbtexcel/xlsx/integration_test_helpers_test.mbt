///|
fn integration_rel_attr_values(xml : String, attr : String) -> Array[String] {
  let values : Array[String] = []
  let marker = "\{attr}=\""
  let mut first = true
  for chunk in xml.split("<Relationship ") {
    if first {
      first = false
      continue
    }
    let part = chunk.to_owned()
    match part.find(marker) {
      Some(start) => {
        let rest = part[start + marker.length():]
        match rest.find("\"") {
          Some(end) => values.push(rest[:end].to_owned())
          None => ()
        }
      }
      None => ()
    }
  }
  values
}

///|
fn integration_unique_values(values : ArrayView[String]) -> Bool {
  for i in 0..<values.length() {
    for j in (i + 1)..<values.length() {
      if values[i] == values[j] {
        return false
      }
    }
  }
  true
}

///|
fn integration_has_value(values : ArrayView[String], expected : String) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}

///|
fn integration_rel_target_to_part_path(target : String) -> String {
  if target.has_prefix("/") {
    target[1:].to_owned()
  } else if target.has_prefix("../") {
    let rest = target[3:].to_owned()
    "xl/\{rest}"
  } else {
    "xl/\{target}"
  }
}
