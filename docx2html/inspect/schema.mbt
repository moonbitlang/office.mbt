// Versioned schema identifiers for the docx CLI's agent-facing JSON
// payloads. docx identifiers are declared here, in the docx2html module;
// xlsx identifiers live in the root module's `inspect/schema.mbt`.
//
// Contract: evolution is additive-only — new optional keys may appear under
// an existing identifier, keys are never renamed or removed, and `null` is
// never emitted (an absent key means "unset"). A breaking change mints a new
// identifier with a bumped major (e.g. "docx.outline/2"). Consumers must
// ignore keys they do not recognize. The normative field-by-field spec lives
// in docs/agent-json-schemas.md.

///|
/// Schema identifier of the `outline` payload (document structure map).
pub const SCHEMA_OUTLINE : String = "docx.outline/1"

///|
/// Schema identifier of the `element` payload (`get <path> --json`).
pub const SCHEMA_ELEMENT : String = "docx.element/1"
