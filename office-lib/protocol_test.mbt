///|
test "output_success emits the versioned envelope without empty warnings" {
  let output = @office.output_success(
    Json::object({ "format": Json::string("xlsx") }),
  )
  inspect(
    output.stringify(),
    content=(
      #|{"schema":"office.output/1","success":true,"data":{"format":"xlsx"}}
    ),
  )
  let reparsed = @json.parse(output.stringify())
  assert_eq(reparsed, output)
}

///|
test "output_success preserves structured warning order" {
  inspect(
    @office.output_success(Json::object({ "changed": Json::boolean(false) }), warnings=[
      @office.protocol_warning("office.first", "first warning"),
      @office.protocol_warning("office.second", "second warning"),
    ]).stringify(),
    content=(
      #|{"schema":"office.output/1","success":true,"data":{"changed":false},"warnings":[{"code":"office.first","message":"first warning"},{"code":"office.second","message":"second warning"}]}
    ),
  )
}

///|
test "output_failure emits error details without success data" {
  inspect(
    @office.output_failure(
      @office.protocol_error(
        "office.format_mismatch",
        "file extension and package content disagree",
        details=Json::object({
          "expected": Json::string("xlsx"),
          "actual": Json::string("docx"),
        }),
      ),
    ).stringify(),
    content=(
      #|{"schema":"office.output/1","success":false,"error":{"code":"office.format_mismatch","message":"file extension and package content disagree","details":{"expected":"xlsx","actual":"docx"}}}
    ),
  )
}
