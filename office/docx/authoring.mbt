// D3 — fresh DOCX creation and strict semantic authoring through the office
// transaction boundary. `create_blank_document` publishes a minimal valid
// package; `author_document` folds a parsed docx.batch/2 script (paragraphs,
// runs, headings, lists, tables, links, images, notes, comments) into a fresh
// package via the shared bounded assembler. Both serialize under the create
// transaction's candidate budget BEFORE allocation, validate the OPC package +
// annotation identity state, and publish atomically (no existing-document
// mutation — that is out of scope, #95).

///|
/// Errors parsing a fresh-authoring `docx.batch/2` script.
pub suberror DocxAuthorParseError {
  DocxAuthorParseError(String)
} derive(@debug.Debug)

///|
/// Per-document authoring counts for the result record.
pub(all) struct DocxAuthorReport {
  ops : Int
  comments : Int
  footnotes : Int
  endnotes : Int
} derive(Eq, @debug.Debug)

///|
/// Result of one fresh-authoring transaction.
pub struct DocxAuthorResult {
  report : DocxAuthorReport
  transaction : @transaction.TransactionReport
}

///|
/// Result of one blank-document creation transaction.
pub struct DocxCreateResult {
  transaction : @transaction.TransactionReport
}

///|
/// Parses and validates a fresh-authoring script. Accepts `docx.batch/1` and
/// `docx.batch/2`; comment and note ops require `/2` (the engine enforces
/// this). Maps the engine's `BatchError` (which carries the offending op's
/// JSON address) to a typed parse error.
pub fn parse_docx_authoring_script(
  text : String,
) -> @docxbatch.BatchScript raise DocxAuthorParseError {
  @docxbatch.check_script_text(text) catch {
    @docxbatch.BatchError(message) => raise DocxAuthorParseError(message)
  }
  let document = @json.parse(text) catch {
    _ => raise DocxAuthorParseError("the authoring script is not valid JSON")
  }
  @docxbatch.parse_batch(document) catch {
    @docxbatch.BatchError(message) => raise DocxAuthorParseError(message)
  }
}

///|
/// Derives the OPC package ceilings from the create transaction budget,
/// mirroring how XLSX maps the same four dimensions onto its bounded writer.
fn author_package_limits(
  budget : @transaction.TransactionBudget,
) -> @opc.PackageLimits raise @transaction.TransactionError {
  let maximum = budget.max_candidate_package_bytes()
  if maximum <= 0 {
    raise docx_failure(
      "office.docx.resource_limit",
      "no live-memory allowance remains for a DOCX candidate package",
      details=Json::object({
        "phase": Json::string("candidate package"),
        "kind": Json::string("output_bytes"),
        "limit": Json::number(0.0),
        "actual": Json::number(1.0),
      }),
    )
  }
  {
    max_output_bytes: maximum,
    max_entries: budget.max_archive_entries(),
    max_entry_uncompressed_bytes: budget.max_entry_uncompressed_bytes(),
    max_total_uncompressed_bytes: budget.max_total_uncompressed_bytes(),
  }
}

///|
/// Maps a writer-side `DocxError` to a typed office transaction failure: a
/// bounded serialization ceiling becomes `office.docx.resource_limit` with the
/// machine-readable kind/limit/actual; every other writer refusal (an
/// unsupported feature, a rejected style/anchor/date) becomes
/// `office.docx.unsupported`. Nothing is published in either case.
fn author_docx_failure(
  error : @docxcore.DocxError,
) -> @transaction.TransactionError raise @transaction.TransactionError {
  match error {
    @docxcore.WriteResourceLimit(kind~, limit~, actual~, ..) =>
      docx_failure(
        "office.docx.resource_limit",
        "the authored DOCX exceeded its bounded construction policy",
        details=Json::object({
          "phase": Json::string("candidate serialization"),
          "kind": Json::string(kind),
          "limit": Json::number(limit.to_double()),
          "actual": Json::number(actual.to_double()),
        }),
      )
    _ =>
      docx_failure(
        "office.docx.unsupported",
        "the authoring script requested content the DOCX writer does not support: " +
        error.description(),
      )
  }
}

///|
/// Publishes a fresh blank DOCX (one empty paragraph, Normal style, Letter
/// section) atomically unless this is a dry run.
pub async fn create_blank_document(
  options : @transaction.CreateTransactionOptions,
) -> DocxCreateResult {
  let report = @transaction.transact_create(
    options,
    Docx,
    budget => {
      let limits = author_package_limits(budget)
      let bytes = @word.new_blank_docx_limited(limits) catch {
        error => raise author_docx_failure(error)
      }
      @transaction.transaction_mutation(bytes)
    },
    validators=[package_validator()],
    identifier=package_identifier(),
  )
  { transaction: report }
}

///|
/// Publishes a fresh DOCX authored from a parsed `docx.batch/2` script and its
/// preloaded image bytes, atomically unless this is a dry run. The candidate
/// is serialized under the transaction budget BEFORE allocation, then validated
/// (OPC structure + annotation identity) before publication.
pub async fn author_document(
  options : @transaction.CreateTransactionOptions,
  script : @docxbatch.BatchScript,
  images : Map[String, Bytes],
) -> DocxAuthorResult {
  let (footnotes, endnotes) = script.note_counts()
  let report = @transaction.transact_create(
    options,
    Docx,
    budget => {
      let limits = author_package_limits(budget)
      let bytes = @word.author_docx_bytes(script, images, limits~) catch {
        error => raise author_docx_failure(error)
      }
      @transaction.transaction_mutation(bytes)
    },
    validators=[package_validator()],
    identifier=package_identifier(),
  )
  {
    report: {
      ops: script.op_count(),
      comments: script.comment_count(),
      footnotes,
      endnotes,
    },
    transaction: report,
  }
}
