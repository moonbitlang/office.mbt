///|
fn fingerprint_command_for_test(command : CapabilityCommand) -> String {
  let buffer = StringBuilder::new()
  append_fingerprint_command(buffer, command)
  buffer.to_string()
}

///|
test "capability fingerprint distinguishes collection boundaries" {
  let field : CapabilityField = {
    name: "value",
    type_name: "string",
    required: true,
    description: "test field",
  }
  let base : CapabilityCommand = {
    name: "example",
    summary: "example",
    usage: "office example",
    formats: ["shared"],
    aliases: [],
    inputs: [field],
    outputs: [],
    output_modes: ["json"],
  }
  let moved_format = { ..base, formats: [], aliases: ["shared"] }
  let moved_field = { ..base, inputs: [], outputs: [field] }
  let encoded = fingerprint_command_for_test(base)
  assert_true(encoded != fingerprint_command_for_test(moved_format))
  assert_true(encoded != fingerprint_command_for_test(moved_field))
}
