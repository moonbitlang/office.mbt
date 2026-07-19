///|
/// Maximum aggregate XML bytes decoded by one transaction-backed XLSX parse.
/// Together with the token and cell ceilings, this consumes a bounded slice of
/// the shared transaction working reserve.
pub const XLSX_TRANSACTION_MAX_DECODED_XML_BYTES : Int = 16 * 1024 * 1024

///|
/// Maximum XML markup-token starts scanned by one transaction-backed parse.
pub const XLSX_TRANSACTION_MAX_XML_MARKUP_TOKENS : Int = 262_144

///|
/// Maximum concrete worksheet cells retained by a transaction-backed workbook.
pub const XLSX_TRANSACTION_MAX_MATERIALIZED_CELLS : Int = 32_768

///|
/// Maximum aggregate uncompressed bytes retained in a generated XLSX archive
/// before ZIP output sizing and allocation.
pub const XLSX_TRANSACTION_MAX_CANDIDATE_ARCHIVE_BYTES : Int = 24 * 1024 * 1024

///|
/// Maximum uncompressed bytes retained for one generated XLSX archive entry.
pub const XLSX_TRANSACTION_MAX_CANDIDATE_ENTRY_BYTES : Int = 12 * 1024 * 1024

///|
/// Maximum row/column dimension records an Office batch may project before it
/// applies the plan to a workbook.
pub const XLSX_TRANSACTION_MAX_ROW_COLUMN_LINES : Int = 32_768
