///|
// `w:numbering` parsing. Abstract definitions carry the levels; `w:num`
// instances point at them. `w:numStyleLink`/`w:styleLink` let one
// abstract definition delegate to another through a style, so resolution
// follows that chain — cycle-safe, like the style cascade.

///|
fn read_level(lvl : @xml.XmlElement) -> (Int, @numbering.Level) {
  let depth = parse_int(attr(lvl, "w:ilvl")).unwrap_or(0)
  let mut level = @numbering.Level::default(depth)
  let mut saw_text = false
  for child in lvl.children {
    guard child is XmlElement(el) else { continue }
    match el.name {
      "w:numFmt" =>
        match attr(el, "w:val") {
          Some(v) => level = { ..level, format: @numbering.number_format(v) }
          None => ()
        }
      "w:lvlText" =>
        match attr(el, "w:val") {
          Some(v) => {
            level = { ..level, text: v }
            saw_text = true
          }
          None => ()
        }
      "w:start" =>
        match parse_int(attr(el, "w:val")) {
          Some(v) => level = { ..level, start: v }
          None => ()
        }
      "w:lvlRestart" =>
        match parse_int(attr(el, "w:val")) {
          Some(v) => level = { ..level, restart: Some(v) }
          None => ()
        }
      "w:isLgl" => level = { ..level, is_legal: parse_toggle(el) }
      // a level's own run properties style its marker. Word's bullets are
      // private-use codepoints that render only in the named face, so the
      // family must travel with the level rather than inherit the body's —
      // and an explicit `w:sz` sizes the marker independently of the text
      // beside it.
      "w:rPr" => {
        match el.first("w:rFonts") {
          Some(fonts) =>
            match attr(fonts, "w:ascii") {
              Some(f) => level = { ..level, font_family: Some(f) }
              None =>
                match attr(fonts, "w:hAnsi") {
                  Some(f) => level = { ..level, font_family: Some(f) }
                  None => ()
                }
            }
          None => ()
        }
        match el.first("w:sz") {
          Some(sz) =>
            match parse_half_points(attr(sz, "w:val")) {
              Some(hp) => level = { ..level, size: Some(HalfPoints(hp)) }
              None => ()
            }
          None => ()
        }
      }
      "w:suff" =>
        level = {
          ..level,
          suffix: match attr(el, "w:val") {
            Some("space") => SuffSpace
            Some("nothing") => SuffNothing
            _ => SuffTab
          },
        }
      // a level's own w:pPr/w:ind supplies the list's indents
      "w:pPr" =>
        match el.first("w:ind") {
          Some(ind) => {
            let left = match attr(ind, "w:left") {
              Some(v) => Some(v)
              None => attr(ind, "w:start")
            }
            match parse_twips(left) {
              Some(v) => level = { ..level, indent_left: Some(Twips(v)) }
              None => ()
            }
            match parse_twips(attr(ind, "w:hanging")) {
              Some(v) => level = { ..level, indent_hanging: Some(Twips(v)) }
              None =>
                match parse_twips(attr(ind, "w:firstLine")) {
                  Some(v) => level = { ..level, indent_first: Some(Twips(v)) }
                  None => ()
                }
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  // a bullet level with no w:lvlText would otherwise keep the numeric
  // placeholder from the default and render "%1." as its glyph
  if level.format is Bullet && !saw_text {
    level = { ..level, text: "\u{2022}" }
  }
  (depth, level)
}

///|
/// Parse a `w:numbering` root element.
pub fn read_numbering(root : @xml.XmlElement) -> @numbering.Numbering {
  let abstracts : Map[Int, @numbering.AbstractNum] = Map([])
  // abstractNumId → the numStyleLink target it delegates to, if any
  let links : Map[Int, String] = Map([])
  // styleLink name → the abstractNumId that defines it
  let defines : Map[String, Int] = Map([])
  for node in root.elements_by_tag_name("w:abstractNum") {
    guard parse_int(node.attributes.get("w:abstractNumId")) is Some(id) else {
      continue
    }
    let levels : Map[Int, @numbering.Level] = Map([])
    for lvl in node.elements_by_tag_name("w:lvl") {
      let (depth, level) = read_level(lvl)
      levels[depth] = level
    }
    abstracts[id] = { levels, }
    match node.first("w:numStyleLink") {
      Some(link) =>
        match link.attributes.get("w:val") {
          Some(target) => links[id] = target
          None => ()
        }
      None => ()
    }
    match node.first("w:styleLink") {
      Some(link) =>
        match link.attributes.get("w:val") {
          Some(name) => if !defines.contains(name) { defines[name] = id }
          None => ()
        }
      None => ()
    }
  }
  // Follow numStyleLink chains so a delegating definition gets the levels
  // it points at. Each id is resolved once and memoized, so a chain of N
  // delegations costs O(N) rather than O(N^2) — a crafted numbering.xml
  // would otherwise hang the reader well inside its own budgets. Cycles
  // stop where they close.
  let resolved : Map[Int, Int] = Map([])
  for id, _ in links {
    if resolved.contains(id) {
      continue
    }
    // walk to the end of this chain, remembering the path
    let path : Array[Int] = []
    let seen : Map[Int, Unit] = Map([])
    let mut current = id
    let mut endpoint = id
    while true {
      if seen.contains(current) {
        break
      }
      seen[current] = ()
      path.push(current)
      match resolved.get(current) {
        // the rest of this chain is already known
        Some(known) => {
          endpoint = known
          break
        }
        None => ()
      }
      match links.get(current) {
        Some(target) =>
          match defines.get(target) {
            Some(next) => {
              endpoint = next
              current = next
            }
            // unresolvable target: stop at the last real definition
            None => break
          }
        None => break
      }
    }
    for node in path {
      resolved[node] = endpoint
    }
  }
  for id, endpoint in resolved {
    if id == endpoint {
      continue
    }
    match abstracts.get(endpoint) {
      Some(source) =>
        // only adopt levels the delegating definition lacks, so a partial
        // definition keeps what it declares
        match abstracts.get(id) {
          Some(own) if own.levels.length() > 0 => ()
          _ => abstracts[id] = source
        }
      None => ()
    }
  }
  let instances : Map[Int, @numbering.NumInstance] = Map([])
  for node in root.elements_by_tag_name("w:num") {
    guard parse_int(node.attributes.get("w:numId")) is Some(num_id) else {
      continue
    }
    let abstract_id = match node.first("w:abstractNumId") {
      Some(el) => parse_int(el.attributes.get("w:val")).unwrap_or(-1)
      None => -1
    }
    let overrides : Map[Int, @numbering.Level] = Map([])
    let start_overrides : Map[Int, Int] = Map([])
    for over in node.elements_by_tag_name("w:lvlOverride") {
      let depth = parse_int(over.attributes.get("w:ilvl")).unwrap_or(0)
      match over.first("w:startOverride") {
        Some(el) =>
          match parse_int(el.attributes.get("w:val")) {
            Some(v) => start_overrides[depth] = v
            None => ()
          }
        None => ()
      }
      match over.first("w:lvl") {
        Some(lvl) => {
          let (_, level) = read_level(lvl)
          overrides[depth] = level
        }
        None => ()
      }
    }
    instances[num_id] = { abstract_id, overrides, start_overrides }
  }
  @numbering.Numbering::new(abstracts, instances)
}
