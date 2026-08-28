///|
// Inline images. A `w:drawing` wraps a `wp:inline` (or `wp:anchor` for
// floating art) whose `wp:extent` gives the display size in EMU and
// whose `a:blip r:embed` names the relationship holding the media part.
// Only inline images are placed; floating ones need text wrapping, which
// the layout engine does not model.

///|
/// One resolved image: its display size and the bytes to embed.
pub(all) struct ImageRef {
  width : @pagelayout.Emu
  height : @pagelayout.Emu
  relationship : String
} derive(Eq, Debug, ToJson)

///|
/// Read a `w:drawing`, if it holds an inline picture this engine can
/// place. Returns None for floating art and for drawings with no
/// resolvable bitmap (charts, diagrams, shapes).
pub fn read_drawing(drawing : @xml.XmlElement) -> ImageRef? {
  // wp:anchor is a floating drawing: it needs text wrapping, so it is
  // deliberately not placed rather than being placed wrongly
  guard drawing.first("wp:inline") is Some(inline) else { return None }
  let extent = inline.first("wp:extent")
  let width = match extent {
    Some(e) => parse_int(e.attributes.get("cx"))
    None => None
  }
  let height = match extent {
    Some(e) => parse_int(e.attributes.get("cy"))
    None => None
  }
  guard width is Some(cx) && height is Some(cy) else { return None }
  if cx <= 0 || cy <= 0 {
    return None
  }
  // the blip is nested under a:graphic/a:graphicData/pic:pic/pic:blipFill
  let blips = inline.descendants_by_tag_name("a:blip")
  guard blips.get(0) is Some(blip) else { return None }
  guard blip.attributes.get("r:embed") is Some(id) else { return None }
  Some({ width: Emu(cx), height: Emu(cy), relationship: id, })
}

///|
/// The media type of a package part, from its extension. PDF and SVG
/// both need it, and a part whose type this engine cannot embed is
/// skipped rather than emitted as something a reader would reject.
pub fn media_type(path : String) -> String? {
  let lower = path.to_lower()
  if lower.has_suffix(".png") {
    Some("image/png")
  } else if lower.has_suffix(".jpg") || lower.has_suffix(".jpeg") {
    Some("image/jpeg")
  } else {
    None
  }
}
