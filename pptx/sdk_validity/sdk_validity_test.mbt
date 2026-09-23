///|
async fn with_sdk_directory(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-pptx-sdk-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
async fn validate_pptx(path : String) -> (Int, String) {
  let (code, _, stderr) = @process.collect_output("bash", [
    "../scripts/validate_pptx.sh", path,
  ])
  (code, stderr.text())
}

///|
async test "demo and Apache POI corpus pass the shared OpenXML SDK gate" {
  with_sdk_directory() <| directory => {
    let path = "\{directory}/demo.pptx"
    @afs.write_file(
      path,
      Bytes::from_array(@demos.build_sample_deck()),
      create_mode=CreateNew,
    )
    let (code, diagnostic) = validate_pptx(path)
    assert_eq(code, 0, msg=diagnostic)
    let fixtures : ReadOnlyArray[String] = [
      "SmartArt.pptx", "layouts.pptx", "sample.pptx", "shapes.pptx", "table_test.pptx",
      "testPPT.pptx", "with_japanese.pptx",
    ]
    for name in fixtures {
      let (code, diagnostic) = validate_pptx("fixtures/poi/\{name}")
      assert_eq(code, 0, msg="\{name}: \{diagnostic}")
    }
  }
}

///|
async test "SmartArt baseline does not hide unrelated presentation schema errors" {
  with_sdk_directory() <| directory => {
    let archive = @opc.Package::open(@demos.build_sample_deck())
    let part = archive.require_part("/ppt/presentation.xml")
    let xml = part.text()
    assert_true(xml.contains("<p:sldSz "))
    let invalid = xml.replace(old="<p:sldSz ", new="<p:sldSz invalid=\"true\" ")
    assert_true(
      archive.replace_part(
        @opc.Part::new(part.name, part.content_type, @fzip.str_to_u8(invalid)),
      ),
    )
    let path = "\{directory}/invalid.pptx"
    @afs.write_file(
      path,
      Bytes::from_array(archive.to_bytes()),
      create_mode=CreateNew,
    )
    let (code, diagnostic) = validate_pptx(path)
    assert_eq(code, 1, msg=diagnostic)
    assert_true(diagnostic.contains("invalid"), msg=diagnostic)
    assert_true(diagnostic.contains("validation failed"), msg=diagnostic)
  }
}
