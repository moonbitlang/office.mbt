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
    debug_inspect(code, content="0") catch {
      _ => fail(diagnostic)
    }
    let fixtures : ReadOnlyArray[String] = [
      "SmartArt.pptx", "layouts.pptx", "sample.pptx", "shapes.pptx", "table_test.pptx",
      "testPPT.pptx", "with_japanese.pptx",
    ]
    for name in fixtures {
      let (code, diagnostic) = validate_pptx("fixtures/poi/\{name}")
      debug_inspect(code, content="0") catch {
        _ => fail("\{name}: \{diagnostic}")
      }
    }
  }
}

///|
async test "SmartArt baseline does not hide unrelated presentation schema errors" {
  with_sdk_directory() <| directory => {
    let archive = @opc.Package::open(@demos.build_sample_deck())
    let part = archive.require_part("/ppt/presentation.xml")
    let xml = part.text()
    debug_inspect(xml.contains("<p:sldSz "), content="true")
    let invalid = xml.replace(old="<p:sldSz ", new="<p:sldSz invalid=\"true\" ")
    debug_inspect(
      archive.replace_part(
        @opc.Part::new(part.name, part.content_type, @fzip.str_to_u8(invalid)),
      ),
      content="true",
    )
    let path = "\{directory}/invalid.pptx"
    @afs.write_file(
      path,
      Bytes::from_array(archive.to_bytes()),
      create_mode=CreateNew,
    )
    let (code, diagnostic) = validate_pptx(path)
    debug_inspect(code, content="1") catch {
      _ => fail(diagnostic)
    }
    debug_inspect(diagnostic.contains("invalid"), content="true") catch {
      _ => fail(diagnostic)
    }
    debug_inspect(diagnostic.contains("validation failed"), content="true") catch {
      _ => fail(diagnostic)
    }
  }
}
