// @oxml media-format detection tests.
// Reuses `bytes_of` from image_test.mbt (same blackbox package).

///|
test "detect_media_format: ISO-BMFF brands (mp4 / mov / m4a)" {
  // ...ftyp at offset 4, brand at 8.
  let mp4 = bytes_of([
    0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D,
  ])
  debug_inspect(@oxml.detect_media_format(mp4) is Some(Mp4), content="true")
  let mov = bytes_of([
    0, 0, 0, 0x14, 0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20,
  ])
  debug_inspect(@oxml.detect_media_format(mov) is Some(Mov), content="true")
  let m4a = bytes_of([
    0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20,
  ])
  debug_inspect(@oxml.detect_media_format(m4a) is Some(M4a), content="true")
}

///|
test "detect_media_format: RIFF (avi / wav)" {
  let avi = bytes_of([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x41, 0x56, 0x49, 0x20,
  ])
  debug_inspect(@oxml.detect_media_format(avi) is Some(Avi), content="true")
  let wav = bytes_of([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45,
  ])
  debug_inspect(@oxml.detect_media_format(wav) is Some(Wav), content="true")
}

///|
test "detect_media_format: aiff / wmv / mp3" {
  let aiff = bytes_of([
    0x46, 0x4F, 0x52, 0x4D, 0, 0, 0, 0, 0x41, 0x49, 0x46, 0x46,
  ])
  debug_inspect(@oxml.detect_media_format(aiff) is Some(Aiff), content="true")
  let wmv = bytes_of([0x30, 0x26, 0xB2, 0x75, 0, 0, 0, 0])
  debug_inspect(@oxml.detect_media_format(wmv) is Some(Wmv), content="true")
  let mp3_id3 = bytes_of([0x49, 0x44, 0x33, 0x03, 0x00])
  debug_inspect(@oxml.detect_media_format(mp3_id3) is Some(Mp3), content="true")
  let mp3_sync = bytes_of([0xFF, 0xFB, 0x90, 0x00])
  debug_inspect(
    @oxml.detect_media_format(mp3_sync) is Some(Mp3),
    content="true",
  )
}

///|
test "detect_media_format: unknown bytes → None" {
  debug_inspect(
    @oxml.detect_media_format(bytes_of([0, 1, 2, 3, 4, 5])) is None,
    content="true",
  )
}

///|
test "MediaFormat: content_type / extension / is_video" {
  debug_inspect(
    (Mp4 : @oxml.MediaFormat).content_type(),
    content="\"video/mp4\"",
  )
  debug_inspect((Mp4 : @oxml.MediaFormat).extension(), content="\"mp4\"")
  debug_inspect((Mp4 : @oxml.MediaFormat).is_video(), content="true")
  debug_inspect(
    (Mp3 : @oxml.MediaFormat).content_type(),
    content="\"audio/mpeg\"",
  )
  debug_inspect((Mp3 : @oxml.MediaFormat).is_video(), content="false")
  debug_inspect(
    (M4a : @oxml.MediaFormat).content_type(),
    content="\"audio/mp4\"",
  )
}
