///|
fn pptx_capability_variant(command : String) -> CapabilityVariant {
  let inputs = [
    capability_field(
      if command == "create" {
        "output"
      } else {
        "file"
      },
      "path",
      true,
      "PPTX file path",
    ),
  ]
  if command == "create" {
    inputs.push(
      capability_field(
        "title", "string", false, "optional slide title; at most 4096 UTF-16 code units",
      ),
    )
    inputs.push(
      capability_field(
        "dry-run", "boolean", false, "validate without publishing",
      ),
    )
    inputs.push(
      capability_field(
        "overwrite", "boolean", false, "replace an existing regular-file destination",
      ),
    )
  } else {
    inputs.push(
      capability_field(
        "max-elements", "integer(1..200000)", false, "shared XML token and projection ceilings; default 50000",
      ),
    )
    inputs.push(
      capability_field(
        "max-output-chars", "integer(1..4194304)", false, "successful stdout ceiling including trailing LF; also caps aggregate PPTX text extraction before pagination; default 1048576",
      ),
    )
    if command == "text" {
      inputs.push(
        capability_field(
          "offset", "integer(0..200000)", false, "zero-based slide offset; default 0",
        ),
      )
      inputs.push(
        capability_field(
          "limit", "integer(0..10000)", false, "maximum returned slides; default 2000",
        ),
      )
    }
  }
  inputs.push(
    capability_field("json", "boolean", false, "emit office.output/1 JSON"),
  )
  let schema = "office.pptx.\{command}/1"
  let outputs = [
    capability_field(
      "schema",
      "literal(\{schema})",
      true,
      "versioned result schema",
    ),
    capability_field("format", "literal(pptx)", true, "document format"),
    capability_field(
      "slide_count", "integer", true, "total slides in presentation order",
    ),
  ]
  if command == "text" {
    for name in ["offset", "limit", "returned"] {
      outputs.push(
        capability_field(name, "integer", true, "slide pagination metadata"),
      )
    }
    outputs.push(
      capability_field(
        "truncated", "boolean", true, "whether later slides were omitted",
      ),
    )
  }
  if command == "create" {
    outputs.push(
      capability_field("output", "path", true, "bounded output path"),
    )
    outputs.push(
      capability_field(
        "transaction",
        SCHEMA_TRANSACTION,
        true,
        "shared atomic publication report",
      ),
    )
  } else {
    outputs.push(
      capability_field("file", "path", true, "input path as supplied"),
    )
    outputs.push(
      capability_field(
        "width_emu", "integer", true, "slide width in English Metric Units",
      ),
    )
    outputs.push(
      capability_field(
        "height_emu", "integer", true, "slide height in English Metric Units",
      ),
    )
    outputs.push(
      capability_field(
        "slides",
        if command == "text" {
          "array(object{index,part,text,notes})"
        } else {
          "array(object{index,part,shape_count})"
        },
        true,
        "one-based positional slide indices; text includes direct shape/table text and associated notes, excluding inherited layout/master text, chart labels, SmartArt, and embedded documents",
      ),
    )
  }
  {
    name: "pptx",
    usage: if command == "create" {
      "office create pptx OUTPUT [--title TEXT] [--dry-run] [--overwrite] [--json]"
    } else if command == "text" {
      "office text FILE.pptx [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]"
    } else {
      "office outline FILE.pptx [--max-elements N] [--max-output-chars N] [--json]"
    },
    result_schema: schema,
    registry: None,
    inputs,
    outputs,
    constraints: if command == "create" {
      [
        "format=pptx", "output-extension=.pptx", "fresh-one-slide-presentation",
        "transactional-publication",
      ]
    } else {
      [
        "format=pptx", "transitional-ooxml-only", "no-selectors", "read-only", "positional-slide-indices",
      ]
    },
    actions: [],
    output_modes: ["human", "json"],
  }
}
