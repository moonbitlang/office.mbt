///|
fn demo_rel_attr_values(xml : String, attr : String) -> Array[String] {
  let values : Array[String] = []
  let marker = "\{attr}=\""
  let mut first = true
  for chunk in xml.split("<Relationship ") {
    if first {
      first = false
      continue
    }
    let part = chunk.to_string()
    match part.find(marker) {
      Some(start) => {
        let rest = part[start + marker.length():]
        match rest.find("\"") {
          Some(end) => {
            let value = rest[:end].to_string()
            values.push(value)
          }
          None => ()
        }
      }
      None => ()
    }
  }
  values
}

///|
fn demo_has_value(values : ArrayView[String], expected : String) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}

///|
fn demo_unique(values : ArrayView[String]) -> Bool {
  let seen : Map[String, Bool] = {}
  for value in values {
    if seen.get(value) is Some(_) {
      return false
    }
    seen[value] = true
  }
  true
}

///|
fn demo_count_tag(xml : String, tag : String) -> Int {
  let mut count = 0
  let mut first = true
  for _ in xml.split(tag) {
    if first {
      first = false
      continue
    }
    count = count + 1
  }
  count
}
