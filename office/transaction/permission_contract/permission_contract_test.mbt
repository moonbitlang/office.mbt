///|
async fn with_permission_contract_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-permission-contract-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
async test "POSIX final permission is exact despite a restrictive umask" {
  if @path.sep == '\\' {
    return
  }
  match @env.get_env_var("OFFICE_TRANSACTION_PERMISSION_PROBE") {
    Some(directory) => {
      let input = "\{directory}/input.docx"
      let output = "\{directory}/output.docx"
      @afs.write_file(
        input,
        @word.new_blank_docx(),
        create_mode=CreateNew,
        permission=0o600,
      )
      let report = @transaction.transact(
        @transaction.transaction_options(
          input,
          output_path=output,
          permission=0o666,
        ),
        (_format, _bytes, _archive, _budget) => {
          @transaction.transaction_reuse_original()
        },
      )
      assert_true(report.committed)
    }
    None =>
      with_permission_contract_dir(directory => {
        let script =
          #|umask 077
          #|test_file=office/transaction/permission_contract/permission_contract_test.mbt
          #|if [ ! -f "$test_file" ]; then
          #|  test_file=transaction/permission_contract/permission_contract_test.mbt
          #|fi
          #|moon test --quiet --frozen --target native \
          #|  --target-dir "$1/moon-build" --no-parallelize \
          #|  "$test_file" --index 0
          #|status=$?
          #|if [ "$status" -ne 0 ]; then exit "$status"; fi
          #|if mode=$(stat -c '%a' "$1/output.docx" 2>/dev/null); then
          #|  :
          #|else
          #|  mode=$(stat -f '%Lp' "$1/output.docx")
          #|fi
          #|if [ "$mode" != 666 ]; then
          #|  echo "expected output mode 666, got $mode" >&2
          #|  exit 1
          #|fi

        let (code, stdout, stderr) = @process.collect_output(
          "/bin/sh",
          ["-c", script, "office-permission-probe", directory],
          extra_env={ "OFFICE_TRANSACTION_PERMISSION_PROBE": directory },
          inherit_env=true,
        )
        if code != 0 {
          let out = stdout.text() catch { _ => "<non-UTF-8 stdout>" }
          let err = stderr.text() catch { _ => "<non-UTF-8 stderr>" }
          fail(
            "restrictive-umask subprocess failed (exit=\{code})\nstdout:\n\{out}\nstderr:\n\{err}",
          )
        }
      })
  }
}
