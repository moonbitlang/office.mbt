///|
fn little_u32(bytes : Bytes, at : Int32) -> Int64 {
  bytes[at].to_int64() |
  (bytes[at + 1].to_int64() << 8) |
  (bytes[at + 2].to_int64() << 16) |
  (bytes[at + 3].to_int64() << 24)
}

///|
/// EOT font programs (W3C EOT submission, version 1/2 headers).
/// The format records the program size independently of its variable name fields.
fn eot_program(bytes : Bytes) -> Bytes raise {
  guard bytes.length() >= 82 &&
    little_u32(bytes, 0) == bytes.length().to_int64() else {
    raise InvalidPresentation("invalid embedded font header")
  }
  guard bytes[34] == 0x4c && bytes[35] == 0x50 else {
    raise InvalidPresentation("invalid embedded font signature")
  }
  let version = little_u32(bytes, 8)
  guard version == 0x00010000L ||
    version == 0x00020001L ||
    version == 0x00020002L else {
    raise Unsupported("EOT version \{version}")
  }
  let flags = little_u32(bytes, 12)
  guard (flags & 0x20L) == 0 else {
    raise Unsupported("EOT with an additional EUDC font")
  }
  let size = little_u32(bytes, 4)
  guard size >= 12 && size <= (bytes.length() - 82).to_int64() else {
    raise InvalidPresentation("invalid embedded font length")
  }
  let program = bytes[bytes.length() - size.to_int():]
  let program = if (flags & 0x10000000L) != 0 {
    Bytes::from_array(
      FixedArray::makei(program.length(), index => {
        (program[index].to_int() ^ 0x50).to_byte()
      }),
    )
  } else {
    program.to_owned()
  }
  if (flags & 0x4L) != 0 {
    @mtx.decompress(program)
  } else {
    program
  }
}

///|
fn register_embedded_fonts(
  pkg : @opc.Package,
  main : String,
  root : @xml.XmlElement,
  fonts : @fonts.FontRegistry,
) -> Unit raise {
  guard child(root, "embeddedFontLst") is Some(list) else { return }
  // Consult a sealed snapshot so checking caller-owned overrides does not
  // seal the catalog that is still receiving embedded faces.
  let supplied = fonts.clone()
  let rels = relationships(pkg, main)
  for entry in element_children(list) {
    guard child(entry, "font").bind(font => attribute(font, "typeface"))
      is Some(family) else {
      raise InvalidPresentation("embedded font has no family")
    }
    for variant in element_children(entry) {
      if variant.name.local_name == "font" {
        continue
      }
      let style = variant.name.local_name
      guard style == "regular" ||
        style == "bold" ||
        style == "italic" ||
        style == "boldItalic" else {
        raise InvalidPresentation("unknown embedded font style \{style}")
      }
      let bold = style == "bold" || style == "boldItalic"
      let italic = style == "italic" || style == "boldItalic"
      if supplied.registered_face(family, bold~, italic~) is Some(face) &&
        face.metrics.bold == bold &&
        face.metrics.italic == italic {
        continue
      }
      let id = attribute(variant, "id").unwrap_or("")
      guard rels.by_id(id) is Some(rel) &&
        rel.target_mode == Internal &&
        rel.rel_type == @oxml.office_relationships_ns + "/font" else {
        raise InvalidPresentation("embedded font relationship \{id} is missing")
      }
      let part = @opc.resolve_target(main, rel.target, Internal)
      let raw = Bytes::from_array(pkg.require_part(part).bytes())
      let sfnt = if raw.length() >= 4 &&
        (raw[:4] == b"\x00\x01\x00\x00" || raw[:4] == b"OTTO") {
        raw
      } else {
        eot_program(raw)
      }
      (fonts.register(family, sfnt, bold~, italic~) |> ignore) catch {
        @fonts.FontRegistryError::Duplicate(_) => ()
        error => raise error
      }
    }
  }
}
