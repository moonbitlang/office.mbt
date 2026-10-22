///|
fn pdf_capability_command() -> CapabilityCommand {
  let variants : Array[CapabilityVariant] = [
    {
      name: "info",
      usage: "office pdf info INPUT.pdf [--detailed] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("detailed", "boolean", false, "detailed"),
      ]),
      outputs: pdf_capability_outputs(
        "Document information; detailed reports retain library field names.",
      ),
      constraints: [
        "format=pdf", "Document information; detailed reports retain library field names.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "pages",
      usage: "office pdf pages INPUT.pdf [--pages SPEC] [--output REPORT] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field(
          "pages", "string", false, "Strict 1-based page specification; default all; order and duplicates preserved",
        ),
        capability_field(
          "output", "path", false, "Optional report/export file; otherwise stdout",
        ),
      ]),
      outputs: pdf_capability_outputs(
        "Physical page boxes, dimensions, rotation and annotations.",
      ),
      constraints: [
        "format=pdf", "Physical page boxes, dimensions, rotation and annotations.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "fonts",
      usage: "office pdf fonts INPUT.pdf [--pages SPEC] [--missing] [--output REPORT] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field(
          "pages", "string", false, "Strict 1-based page specification; default all; order and duplicates preserved",
        ),
        capability_field("missing", "boolean", false, "missing"),
        capability_field(
          "output", "path", false, "Optional report/export file; otherwise stdout",
        ),
      ]),
      outputs: pdf_capability_outputs(
        "Missing means absent embedded font programs; not missing system fonts. Type 3 and fonts inside Form XObjects are outside the missing report.",
      ),
      constraints: [
        "format=pdf", "Missing means absent embedded font programs; not missing system fonts. Type 3 and fonts inside Form XObjects are outside the missing report.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "validate",
      usage: "office pdf validate INPUT.pdf [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
      ]),
      outputs: pdf_capability_outputs(
        "Parse, write, and reparse in memory; not PDF/A, accessibility, or visual validation.",
      ),
      constraints: [
        "format=pdf", "Parse, write, and reparse in memory; not PDF/A, accessibility, or visual validation.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "rewrite",
      usage: "office pdf rewrite INPUT.pdf OUTPUT.pdf [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
      ]),
      outputs: pdf_capability_outputs(
        "Serialize and reparse before publication.",
      ),
      constraints: ["format=pdf", "Serialize and reparse before publication."],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "decrypt",
      usage: "office pdf decrypt INPUT.pdf OUTPUT.pdf [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
      ]),
      outputs: pdf_capability_outputs(
        "Try an empty user password when credentials are omitted; output is unencrypted.",
      ),
      constraints: [
        "format=pdf", "Try an empty user password when credentials are omitted; output is unencrypted.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "extract",
      usage: "office pdf extract INPUT.pdf OUTPUT.pdf --pages SPEC [--retain-numbering] [--process-struct-tree] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
        capability_field(
          "pages", "string", true, "Required strict page selection",
        ),
        capability_field(
          "retain-numbering", "boolean", false, "retain-numbering",
        ),
        capability_field(
          "process-struct-tree", "boolean", false, "process-struct-tree",
        ),
      ]),
      outputs: pdf_capability_outputs(
        "Page selection is required; preserve order and duplicates.",
      ),
      constraints: [
        "format=pdf", "Page selection is required; preserve order and duplicates.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "merge",
      usage: "office pdf merge OUTPUT.pdf INPUT.pdf INPUT.pdf... [--pages SPEC...] [--retain-numbering] [--remove-duplicate-fonts] [--add-toplevel-document] [--drop-*] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("output", "path", true, "Destination PDF path"),
        capability_field(
          "inputs", "array(path)", true, "At least two PDFs, in output order",
        ),
        capability_field(
          "pages", "array(string)", false, "Omit or repeat exactly once per input",
        ),
        capability_field(
          "retain-numbering", "boolean", false, "retain-numbering",
        ),
        capability_field(
          "remove-duplicate-fonts", "boolean", false, "remove-duplicate-fonts",
        ),
        capability_field(
          "add-toplevel-document", "boolean", false, "add-toplevel-document",
        ),
        capability_field("drop-bookmarks", "boolean", false, "drop-bookmarks"),
        capability_field(
          "drop-optional-content", "boolean", false, "drop-optional-content",
        ),
        capability_field("drop-acroforms", "boolean", false, "drop-acroforms"),
        capability_field(
          "drop-named-destinations", "boolean", false, "drop-named-destinations",
        ),
        capability_field(
          "drop-name-dictionary", "boolean", false, "drop-name-dictionary",
        ),
        capability_field(
          "drop-structure-tree", "boolean", false, "drop-structure-tree",
        ),
        capability_field("drop-info", "boolean", false, "drop-info"),
        capability_field(
          "drop-catalog-entries", "boolean", false, "drop-catalog-entries",
        ),
      ]),
      outputs: pdf_capability_outputs(
        "Output comes first; --pages is omitted or repeated exactly once per input. --add-toplevel-document wraps tagged trees, not bookmarks. All library retention controls remain available.",
      ),
      constraints: [
        "format=pdf", "Output comes first; --pages is omitted or repeated exactly once per input. --add-toplevel-document wraps tagged trees, not bookmarks. All library retention controls remain available.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "metadata get",
      usage: "office pdf metadata get INPUT.pdf [--output REPORT.json] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field(
          "output", "path", false, "Optional report/export file; otherwise stdout",
        ),
      ]),
      outputs: pdf_capability_outputs("Read standard Info fields."),
      constraints: ["format=pdf", "Read standard Info fields."],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "metadata set",
      usage: "office pdf metadata set INPUT.pdf OUTPUT.pdf [--title TEXT] [--author TEXT] [--subject TEXT] [--keywords TEXT] [--creator TEXT] [--producer TEXT] [--creation-date DATE] [--modification-date DATE] [--xmp-also] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
        capability_field("title", "string", false, "title"),
        capability_field("author", "string", false, "author"),
        capability_field("subject", "string", false, "subject"),
        capability_field("keywords", "string", false, "keywords"),
        capability_field("creator", "string", false, "creator"),
        capability_field("producer", "string", false, "producer"),
        capability_field("creation-date", "string", false, "creation-date"),
        capability_field(
          "modification-date", "string", false, "modification-date",
        ),
        capability_field("xmp-also", "boolean", false, "xmp-also"),
      ]),
      outputs: pdf_capability_outputs(
        "At least one field is required; empty values clear text. PDF dates use D:YYYYMMDDHHmmSS syntax. --xmp-also creates XMP if needed.",
      ),
      constraints: [
        "format=pdf", "At least one field is required; empty values clear text. PDF dates use D:YYYYMMDDHHmmSS syntax. --xmp-also creates XMP if needed.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "metadata export",
      usage: "office pdf metadata export INPUT.pdf [--output METADATA.xml] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field(
          "output", "path", false, "Optional report/export file; otherwise stdout",
        ),
      ]),
      outputs: pdf_capability_outputs(
        "Export catalog XMP XML; absent metadata is an error.",
      ),
      constraints: [
        "format=pdf", "Export catalog XMP XML; absent metadata is an error.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "metadata import",
      usage: "office pdf metadata import INPUT.pdf OUTPUT.pdf METADATA.xml [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
        capability_field("xml", "path", true, "XML file replacing catalog XMP"),
      ]),
      outputs: pdf_capability_outputs(
        "Validate XML and replace catalog XMP; do not synchronize Info.",
      ),
      constraints: [
        "format=pdf", "Validate XML and replace catalog XMP; do not synchronize Info.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "metadata remove",
      usage: "office pdf metadata remove INPUT.pdf OUTPUT.pdf [--scope info|xmp|all] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
        capability_field(
          "scope", "enum(info|xmp|all)", false, "Defaults to all",
        ),
      ]),
      outputs: pdf_capability_outputs(
        "Scope defaults to all; removal is not secure erasure.",
      ),
      constraints: [
        "format=pdf", "Scope defaults to all; removal is not secure erasure.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "bookmarks export",
      usage: "office pdf bookmarks export INPUT.pdf [--text] [--output BOOKMARKS] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field(
          "output", "path", false, "Optional report/export file; otherwise stdout",
        ),
        capability_field("text", "boolean", false, "text"),
      ]),
      outputs: pdf_capability_outputs(
        "Default JSON preserves actions; cpdf text is less expressive.",
      ),
      constraints: [
        "format=pdf", "Default JSON preserves actions; cpdf text is less expressive.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "bookmarks import",
      usage: "office pdf bookmarks import INPUT.pdf OUTPUT.pdf BOOKMARKS [--text] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
        capability_field("bookmarks", "path", true, "bookmarks"),
        capability_field("text", "boolean", false, "text"),
      ]),
      outputs: pdf_capability_outputs(
        "Replace bookmarks and verify hierarchy/page references.",
      ),
      constraints: [
        "format=pdf", "Replace bookmarks and verify hierarchy/page references.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "bookmarks remove",
      usage: "office pdf bookmarks remove INPUT.pdf OUTPUT.pdf [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
      ]),
      outputs: pdf_capability_outputs("Remove the outline."),
      constraints: ["format=pdf", "Remove the outline."],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "labels export",
      usage: "office pdf labels export INPUT.pdf [--output LABELS.json] [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field(
          "output", "path", false, "Optional report/export file; otherwise stdout",
        ),
      ]),
      outputs: pdf_capability_outputs(
        "Export editable label ranges as a JSON array.",
      ),
      constraints: [
        "format=pdf", "Export editable label ranges as a JSON array.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "labels import",
      usage: "office pdf labels import INPUT.pdf OUTPUT.pdf LABELS.json [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
        capability_field("labels", "path", true, "labels"),
      ]),
      outputs: pdf_capability_outputs(
        "Replace labels; physical start pages must be unique, increasing and in bounds, and start values positive. Empty arrays clear labels.",
      ),
      constraints: [
        "format=pdf", "Replace labels; physical start pages must be unique, increasing and in bounds, and start values positive. Empty arrays clear labels.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "labels remove",
      usage: "office pdf labels remove INPUT.pdf OUTPUT.pdf [--json|--jsonl] [--dry-run] [--overwrite]",
      result_schema: "office.pdf/1",
      registry: None,
      inputs: pdf_capability_inputs([
        capability_field("input", "path", true, "Input PDF path"),
        capability_field("output", "path", true, "Destination PDF path"),
      ]),
      outputs: pdf_capability_outputs(
        "Remove viewer page labels; these are not printed page text.",
      ),
      constraints: [
        "format=pdf", "Remove viewer page labels; these are not printed page text.",
      ],
      actions: [],
      output_modes: ["human", "json", "jsonl"],
    },
  ]
  {
    name: "pdf",
    summary: "Inspect and manipulate existing PDFs",
    usage: "office pdf <operation> [arguments] [--json|--jsonl] [--dry-run] [--overwrite]",
    // PDF operations form their own command family. They do not extend the
    // OOXML DocumentFormat or imply PDF support for top-level selectors.
    formats: [],
    aliases: [],
    inputs: pdf_capability_inputs([
      capability_field(
        "operation", "string", true, "info, pages, fonts, validate, rewrite, decrypt, extract, merge, metadata, bookmarks, or labels",
      ),
    ]),
    outputs: pdf_capability_outputs(
      "Operation-specific report data or a verified PDF page count",
    ),
    output_modes: ["human", "json", "jsonl"],
    variants,
  }
}

///|
fn pdf_capability_inputs(
  specific : Array[CapabilityField],
) -> Array[CapabilityField] {
  [
    ..specific,
    capability_field(
      "json", "boolean", false, "Emit office.output/1 JSON; conflicts with --jsonl",
    ),
    capability_field(
      "jsonl", "boolean", false, "Emit one office.output/1 line; conflicts with --json",
    ),
    capability_field(
      "dry-run", "boolean", false, "Build and validate without writing; existing destinations still require --overwrite",
    ),
    capability_field(
      "overwrite", "boolean", false, "Replace an existing destination; remove then stage, not an atomic swap",
    ),
    capability_field(
      "password", "string", false, "UTF-8 user password; conflicts with --password-file",
    ),
    capability_field(
      "password-file", "path", false, "Exact user password bytes; no newline trimming",
    ),
    capability_field(
      "owner-password", "string", false, "UTF-8 owner password; conflicts with --owner-password-file",
    ),
    capability_field(
      "owner-password-file", "path", false, "Exact owner password bytes",
    ),
  ]
}

///|
fn pdf_capability_outputs(description : String) -> Array[CapabilityField] {
  [
    capability_field(
      "schema", "literal(office.pdf/1)", true, "Versioned PDF operation result",
    ),
    capability_field(
      "operation", "string", true, "Operation including any nested action",
    ),
    capability_field("result", "json", true, description),
    capability_field(
      "dry_run", "boolean", true, "Whether file publication was disabled",
    ),
    capability_field(
      "committed", "boolean", true, "True only after an output file was published",
    ),
    capability_field(
      "output", "path", false, "Destination for file-producing operations",
    ),
    capability_field(
      "result_size", "integer", false, "Candidate file size in bytes",
    ),
  ]
}
