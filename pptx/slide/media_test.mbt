// Modified for office.mbt: follow the workspace warning conventions.
// Tests for media pictures.
// Reuses `slide_of_picture` (svg_picture_test.mbt)
// (background_test.mbt) from this blackbox test package.

///|
test "Picture::of_media: builds a video reference + poster blip" {
  let pic = @slide.Picture::of_media(
    id=5,
    name="clip.mp4",
    Video,
    link_id="rId3", // <a:videoFile r:link>
    media_embed_id="rId4", // <p14:media r:embed>
    poster_embed_id="rId2", // poster <a:blip r:embed>
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914_400L),
    cy=Emu(914_400L),
  )
  // Poster is the blipFill embed.
  debug_inspect(pic.blip_fill.embed_id, content="\"rId2\"")
  match pic.media {
    Some(m) => {
      debug_inspect(m.kind is Video, content="true")
      debug_inspect(m.link_id, content="\"rId3\"")
      debug_inspect(m.embed_id, content="\"rId4\"")
    }
    None => fail("expected media info")
  }
}

///|
test "media picture serialises videoFile + p14:media + media action" {
  let pic = @slide.Picture::of_media(
    id=7,
    name="clip.mp4",
    Video,
    link_id="rId3",
    media_embed_id="rId4",
    poster_embed_id="rId2",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let xml = @oxml.bytes_to_string(slide_of_picture(pic).serialize())
  debug_inspect(xml.contains("<a:videoFile"), content="true")
  debug_inspect(xml.contains("media"), content="true") // p14:media
  debug_inspect(xml.contains("ppaction://media"), content="true")
  debug_inspect(xml.contains(@oxml.media_ext_uri), content="true")
  debug_inspect(xml.contains(@oxml.powerpoint_2010_ns), content="true")
}

///|
test "audio media emits audioFile" {
  let pic = @slide.Picture::of_media(
    id=8,
    name="clip.mp3",
    Audio,
    link_id="rId3",
    media_embed_id="rId4",
    poster_embed_id="rId2",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let xml = @oxml.bytes_to_string(slide_of_picture(pic).serialize())
  debug_inspect(xml.contains("<a:audioFile"), content="true")
}

///|
test "media XML round-trips losslessly (re-serialise is stable)" {
  let pic = @slide.Picture::of_media(
    id=9,
    name="clip.mp4",
    Video,
    link_id="rId3",
    media_embed_id="rId4",
    poster_embed_id="rId2",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  // First serialise (typed media path), then parse — the parser captures the
  // media nv-children into `extension` (media stays None) — then serialise
  // again. The media elements must survive that second pass verbatim.
  let bytes1 = slide_of_picture(pic).serialize()
  let reparsed = @slide.Slide::parse(bytes1)
  let xml2 = @oxml.bytes_to_string(reparsed.serialize())
  debug_inspect(xml2.contains("<a:videoFile"), content="true")
  debug_inspect(xml2.contains("ppaction://media"), content="true")
  debug_inspect(xml2.contains(@oxml.media_ext_uri), content="true")
}

///|
/// Issue #11 regression: after a parse→serialise round-trip (where the media
/// reference is captured into `extension`, not the typed `media` field), the
/// `<a:videoFile>` and the media `<p:extLst>` must still sit *inside* `<p:nvPr>`
/// — not as direct children of `<p:pic>`, which is invalid `CT_Picture` content
/// and made PowerPoint repair the deck. The pre-fix code mis-classified the
/// drawing-ml `<a:videoFile>` to the shape body. Presence-only checks (above)
/// missed it; this asserts *placement*.
test "issue #11: media nv-children stay inside <p:nvPr> after round-trip" {
  let pic = @slide.Picture::of_media(
    id=9,
    name="clip.mp4",
    Video,
    link_id="rId3",
    media_embed_id="rId4",
    poster_embed_id="rId2",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let xml = @oxml.bytes_to_string(
    @slide.Slide::parse(slide_of_picture(pic).serialize()).serialize(),
  )
  // A non-empty `<p:nvPr>…</p:nvPr>` (the buggy form emitted a self-closed
  // `<p:nvPr/>`, so `<p:nvPr>` with a `>` would be absent).
  let nvpr_open = xml.find("<p:nvPr>").unwrap()
  let nvpr_close = xml.find("</p:nvPr>").unwrap()
  debug_inspect(nvpr_open >= 0, content="true")
  debug_inspect(nvpr_close > nvpr_open, content="true")
  // Both the media reference and the p14:media extLst live between them.
  let video = xml.find("<a:videoFile").unwrap()
  let media_ext = xml.find(@oxml.media_ext_uri).unwrap()
  debug_inspect(video > nvpr_open && video < nvpr_close, content="true")
  debug_inspect(media_ext > nvpr_open && media_ext < nvpr_close, content="true")
}
