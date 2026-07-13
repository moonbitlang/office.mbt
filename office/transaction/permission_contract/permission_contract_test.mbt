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
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      )
      assert_true(report.committed)
    }
    None =>
      with_permission_contract_dir(directory => {
        let args = @env.args()
        guard args is [executable, ..] else {
          fail("permission probe could not locate its test executable")
        }
        let script =
          #|umask 077
          #|probe="$1"
          #|# Moon may deliberately set argv[0] to the generated C source path.
          #|# On Linux, resolve the actual running test image without a custom
          #|# native stub; macOS runners expose the executable through argv[0].
          #|if [ -x "/proc/$PPID/exe" ]; then
          #|  probe="/proc/$PPID/exe"
          #|else
          #|  chmod u+x "$probe"
          #|fi
          #|"$probe" 'permission_contract_test.mbt:0-1'
          #|status=$?
          #|if [ "$status" -ne 0 ]; then exit "$status"; fi
          #|mode=$(stat -f '%Lp' "$2/output.docx" 2>/dev/null || stat -c '%a' "$2/output.docx")
          #|test "$mode" = 666

        let (code, stdout, stderr) = @process.collect_output(
          "/bin/sh",
          ["-c", script, "office-permission-probe", executable, directory],
          extra_env={
            "OFFICE_TRANSACTION_PERMISSION_PROBE": directory,
            "PATH": "/usr/bin:/bin",
          },
          inherit_env=false,
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
