///|
fn wb_fresh_xlsx(sheet : String) -> Bytes raise {
  let workbook = @excel.new_workbook()
  ignore(workbook.add_sheet(sheet))
  @excel.write(workbook)
}

///|
fn wb_create_faults(
  fail_write? : Bool = false,
  fail_write_after_bytes? : Int,
  fail_rename? : Bool = false,
  stall_write_after_bytes? : Int,
  concurrent_destination? : Bytes,
) -> TransactionFaults {
  {
    fail_write,
    fail_write_after_bytes,
    stall_write_after_bytes,
    fail_rename,
    stall_after_temp: false,
    post_rename_release: None,
    concurrent_replacement: None,
    concurrent_destination,
    relocate_parent_to: None,
    deny_cleanup: false,
  }
}

///|
async test "fresh creation write and rename failures clean private staging" {
  wb_with_transaction_dir(directory => {
    let candidate = wb_fresh_xlsx("Sheet1")
    let write_output = "\{directory}/write.xlsx"
    let write_code = wb_error_code(() => {
      transact_create_with_faults(
        create_transaction_options(write_output),
        Xlsx,
        _budget => transaction_mutation(candidate),
        [],
        None,
        wb_create_faults(fail_write=true),
      )
    })
    assert_eq(write_code, "office.transaction.write_failed")
    assert_false(@afs.exists(write_output))
    wb_assert_no_temp(directory)
    let rename_output = "\{directory}/rename.xlsx"
    let rename_code = wb_error_code(() => {
      transact_create_with_faults(
        create_transaction_options(rename_output),
        Xlsx,
        _budget => transaction_mutation(candidate),
        [],
        None,
        wb_create_faults(fail_rename=true),
      )
    })
    assert_eq(rename_code, "office.transaction.commit_failed")
    assert_false(@afs.exists(rename_output))
    wb_assert_no_temp(directory)
  })
}

///|
async test "fresh creation no-replace loses safely to a concurrent destination" {
  wb_with_transaction_dir(directory => {
    let output = "\{directory}/race.xlsx"
    let candidate = wb_fresh_xlsx("Sheet1")
    let concurrent = b"concurrent writer"
    let code = wb_error_code(() => {
      transact_create_with_faults(
        create_transaction_options(output),
        Xlsx,
        _budget => transaction_mutation(candidate),
        [],
        None,
        wb_create_faults(concurrent_destination=concurrent),
      )
    })
    assert_eq(code, "office.transaction.output_exists")
    assert_eq(@afs.read_file(output).binary(), concurrent)
    wb_assert_no_temp(directory)
  })
}

///|
async test "fresh creation cancellation waits for staging cleanup" {
  wb_with_transaction_dir(directory => {
    let output = "\{directory}/cancel.xlsx"
    let candidate = wb_fresh_xlsx("Sheet1")
    @async.with_task_group() <| group => {
      let task = group.spawn(() => {
        transact_create_with_faults(
          create_transaction_options(output),
          Xlsx,
          _budget => transaction_mutation(candidate),
          [],
          None,
          wb_create_faults(stall_write_after_bytes=1),
        )
      })
      let mut observed_staging = false
      for _ in 0..<1_000 {
        for name in @afs.readdir(directory) {
          if name.contains(".office-tmp-") {
            observed_staging = true
          }
        }
        if observed_staging {
          break
        }
        @async.pause()
      }
      assert_true(observed_staging)
      task.cancel()
      let propagated = try {
        ignore(task.wait())
        false
      } catch {
        error => @async.is_cancellation_error(error)
      }
      assert_true(propagated)
    }
    assert_false(@afs.exists(output))
    wb_assert_no_temp(directory)
  })
}

///|
async test "fresh creation rejects source-reuse mutation contracts" {
  wb_with_transaction_dir(directory => {
    let output = "\{directory}/reuse.xlsx"
    let code = wb_error_code(() => {
      transact_create_with_faults(
        create_transaction_options(output),
        Xlsx,
        _budget => transaction_reuse_original(),
        [],
        None,
        no_transaction_faults(),
      )
    })
    assert_eq(code, "office.transaction.invalid_contract")
    assert_false(@afs.exists(output))
    wb_assert_no_temp(directory)
  })
}
