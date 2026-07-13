///|
fn fingerprint_command_for_test(command : CapabilityCommand) -> String {
  let buffer = StringBuilder::new()
  append_fingerprint_command(buffer, command)
  buffer.to_string()
}

///|
fn fingerprint_format_for_test(format : CapabilityFormat) -> String {
  let buffer = StringBuilder::new()
  append_fingerprint_format(buffer, format)
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
    variants: [],
  }
  let moved_format = { ..base, formats: [], aliases: ["shared"] }
  let moved_field = { ..base, inputs: [], outputs: [field] }
  let with_variant = {
    ..base,
    variants: [
      {
        name: "variant",
        usage: "office example variant",
        inputs: [field],
        outputs: [],
        constraints: ["required(value)"],
        output_modes: ["json"],
      },
    ],
  }
  let encoded = fingerprint_command_for_test(base)
  assert_true(encoded != fingerprint_command_for_test(moved_format))
  assert_true(encoded != fingerprint_command_for_test(moved_field))
  assert_true(encoded != fingerprint_command_for_test(with_variant))
}

///|
test "capability fingerprint includes selector boundaries" {
  let base = capability_formats()[0]
  let encoded = fingerprint_format_for_test(base)
  let moved_example = {
    ..base,
    selector: {
      ..base.selector,
      examples: [],
      description: base.selector.examples[0],
    },
  }
  let changed_status = {
    ..base,
    selector: { ..base.selector, status: "resolution" },
  }
  assert_true(encoded != fingerprint_format_for_test(moved_example))
  assert_true(encoded != fingerprint_format_for_test(changed_status))
}
