///|
test "raw OPC replacements invalidate slide order while byte snapshots cannot" {
  let prs = @presentation.Presentation::new()
  ignore(prs.add_slide_mut(0))
  ignore(prs.add_slide_mut(0))
  stamp_slide(prs, 0, "first")
  stamp_slide(prs, 1, "second")
  debug_inspect(marker_of(prs.slide_at(0)), content="\"first\"")

  let pkg = prs.opc_package()
  let part = pkg.require_part("/ppt/presentation.xml")
  let bytes = part.bytes()
  bytes[0] = b'!'
  debug_inspect(marker_of(prs.slide_at(0)), content="\"first\"")

  let presentation = prs.presentation_part().unwrap()
  let ids = presentation.sld_ids
  let reordered = { ..presentation, sld_ids: [ids[1], ids[0]], }
  debug_inspect(
    pkg.replace_part(
      @opc.Part::new(part.name, part.content_type, reordered.serialize()),
    ),
    content="true",
  )
  debug_inspect(marker_of(prs.slide_at(0)), content="\"second\"")

  let rels_part = pkg.require_part("/ppt/_rels/presentation.xml.rels")
  let rels = pkg.relationships_for(part.name)
  let first = rels.by_id(ids[0].r_id).unwrap()
  let second = rels.by_id(ids[1].r_id).unwrap()
  let mut swapped = @opc.Relationships::new(part.name)
  for rel in rels.items() {
    let target = if rel.id == first.id {
      second.target
    } else if rel.id == second.id {
      first.target
    } else {
      rel.target
    }
    swapped = swapped.with_relationship({ ..rel, target, })
  }
  debug_inspect(
    pkg.replace_part(
      @opc.Part::new(
        rels_part.name,
        rels_part.content_type,
        swapped.serialize(),
      ),
    ),
    content="true",
  )
  debug_inspect(marker_of(prs.slide_at(0)), content="\"first\"")
  debug_inspect(
    marker_of(@presentation.Presentation::open(prs.save()).slide_at(0)),
    content="\"first\"",
  )
}

///|
test "save wraps ZIP write errors in PptxError" {
  let presentation = @presentation.Presentation::new()
  presentation
  .opc_package()
  .add_part(@opc.Part::new("/" + "a".repeat(65536), "", []))
  let rejected = try {
    ignore(presentation.save())
    false
  } catch {
    OpcFailure(_) => true
    _ => false
  }
  debug_inspect(rejected, content="true")
}
