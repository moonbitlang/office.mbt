// Versioned schema identifiers for the agent-facing JSON payloads.
//
// Contract: evolution is additive-only — new optional keys may appear under
// an existing identifier, keys are never renamed or removed, and `null` is
// never emitted (an absent key means "unset"). A breaking change mints a new
// identifier with a bumped major (e.g. "xlsx.outline/2"). Consumers must
// ignore keys they do not recognize. The normative field-by-field spec lives
// in docs/agent-json-schemas.md.

///|
/// Schema identifier of the `outline` payload (workbook structure map).
pub const SCHEMA_OUTLINE : String = "xlsx.outline/1"

///|
/// Schema identifier of the `cells` payload (`get --json` range read).
pub const SCHEMA_CELLS : String = "xlsx.cells/1"

///|
/// Schema identifier accepted by the `batch` op-script format.
pub const SCHEMA_BATCH : String = "xlsx.batch/1"

///|
/// Schema identifier of the `query` payload (content-selector cell search).
pub const SCHEMA_QUERY : String = "xlsx.query/1"

///|
/// Schema identifier of the `calc` payload (a cell's typed computed value).
pub const SCHEMA_CALC : String = "xlsx.calc/1"

///|
/// Schema identifier of the `lint` payload (formula problems found by
/// recomputing).
pub const SCHEMA_LINT : String = "xlsx.lint/1"
