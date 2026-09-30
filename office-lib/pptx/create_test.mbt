///|
async test "PPTX creation publishes atomically and respects dry-run and overwrite" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-pptx-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let path = directory + "/deck.pptx"
    let dry = @pptx.create_presentation(
      @transaction.create_transaction_options(path, dry_run=true),
      title="Dry",
    )
    debug_inspect(
      (dry.dry_run, dry.committed, @afs.exists(path)),
      content="(true, false, false)",
    )
    let created = @pptx.create_presentation(
      @transaction.create_transaction_options(path),
      title="Hello 世界",
    )
    debug_inspect(created.committed, content="true")
    let original = @afs.read_file(path).binary()
    debug_inspect(
      @pptx.read_presentation(original).slides[0].text,
      content="\"Hello 世界\"",
    )
    debug_inspect(
      try {
        @pptx.create_presentation(
          @transaction.create_transaction_options(path),
          title="Replace",
        )
        |> ignore
        false
      } catch {
        _ => true
      },
      content="true",
    )
    debug_inspect(@afs.read_file(path).binary() == original, content="true")
    let replacement = @pptx.create_presentation(
      @transaction.create_transaction_options(path, overwrite=true),
      title="Replace",
    )
    debug_inspect(replacement.committed, content="true")
    debug_inspect(
      @pptx.read_presentation(@afs.read_file(path).binary()).slides[0].text,
      content="\"Replace\"",
    )
    let invalid = directory + "/invalid.pptx"
    debug_inspect(
      try {
        @pptx.create_presentation(
          @transaction.create_transaction_options(invalid),
          title="bad\u0000text",
        )
        |> ignore
        false
      } catch {
        _ => true
      },
      content="true",
    )
    debug_inspect(@afs.exists(invalid), content="false")
  }
}
