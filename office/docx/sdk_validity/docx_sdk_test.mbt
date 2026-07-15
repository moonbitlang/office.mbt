///|
async fn sdk_write_docx(path : String, bytes : Bytes) -> Unit {
  @afs.write_file(path, bytes, create_mode=CreateNew, permission=0o600)
}

///|
async fn validate_docx_with_sdk(path : String) -> Unit {
  let (code, stdout, stderr) = @process.collect_output("bash", [
    "../scripts/validate_docx.sh", path,
  ])
  if code != 0 {
    let out = stdout.text() catch { _ => "<non-UTF-8 stdout>" }
    let err = stderr.text() catch { _ => "<non-UTF-8 stderr>" }
    fail(
      "OpenXML SDK validation failed (exit=\{code}) for \{path}\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
}

///|
fn sdk_comment(
  author : String,
  text : String,
) -> @word_impl.CommentSpec raise @word.DocxError {
  @word.comment_spec(author~, from=0, to=0, [
    @word.paragraph([@word.run([@word.text(text)])]),
  ])
}

///|
async test "transact_docx add, reply, and resolve outputs pass Microsoft OpenXML validation" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-sdk-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = "\{directory}/input.docx"
    let added = "\{directory}/added.docx"
    let replied = "\{directory}/replied.docx"
    let resolved = "\{directory}/resolved.docx"
    let original = @word.new_blank_docx()
    sdk_write_docx(input, original)

    let added_id = Ref("")
    let add_report = @docx.transact_docx(
      @transaction.transaction_options(input, output_path=added),
      session => {
        added_id.val = session.queue_comment_addition(
          at_relative="p[1]",
          to_relative="p[1]",
          sdk_comment("SDK author", "SDK-valid root comment"),
        )
      },
    )
    assert_true(add_report.committed)
    assert_eq(added_id.val, "0")
    validate_docx_with_sdk(added)
    let after_add = @word.read_docx_annotated(@afs.read_file(added).binary())
    assert_eq(after_add.annotations().comments().length(), 1)
    assert_eq(after_add.annotations().comments()[0].id(), "0")

    let reply_id = Ref("")
    let reply_report = @docx.transact_docx(
      @transaction.transaction_options(added, output_path=replied),
      session => {
        reply_id.val = session.queue_comment_reply(
          parent_id="0",
          sdk_comment("SDK reviewer", "SDK-valid reply"),
        )
      },
    )
    assert_true(reply_report.committed)
    assert_eq(reply_id.val, "1")
    validate_docx_with_sdk(replied)
    let after_reply = @word.read_docx_annotated(
      @afs.read_file(replied).binary(),
    )
    assert_eq(after_reply.annotations().comments().length(), 2)
    assert_eq(after_reply.annotations().comments()[1].parent_id(), Some("0"))

    let resolve_report = @docx.transact_docx(
      @transaction.transaction_options(replied, output_path=resolved),
      session => session.queue_comment_resolution(comment_id="0", done=true),
    )
    assert_true(resolve_report.committed)
    validate_docx_with_sdk(resolved)
    let after_resolve = @word.read_docx_annotated(
      @afs.read_file(resolved).binary(),
    )
    assert_eq(after_resolve.annotations().comments().length(), 2)
    assert_eq(after_resolve.annotations().comments()[0].done(), Some(true))
    assert_eq(after_resolve.annotations().comments()[1].done(), Some(false))
    assert_eq(@afs.read_file(input).binary(), original)
  }
}
