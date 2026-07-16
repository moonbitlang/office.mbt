///|
let office_read_max_package_bytes : Int = 64 * 1024 * 1024

///|
let office_read_max_zip_entries : Int = 4096

///|
let office_read_max_zip_entry_bytes : Int = 32 * 1024 * 1024

///|
let office_read_max_zip_total_bytes : Int = 128 * 1024 * 1024

///|
let office_read_max_preserved_source_bytes : Int = 64 * 1024 * 1024 + 65_535

///|
let office_read_max_xml_part_bytes : Int = 16 * 1024 * 1024

///|
struct OfficeReadPackage {
  file : String
  format : @lib.DocumentFormat
  archive : @zip.Archive
}

///|
fn office_read_format_hint(
  file : String,
) -> @lib.DocumentFormat raise CliFailure {
  let lower = file.to_lower()
  if lower.has_suffix(".xlsx") {
    Xlsx
  } else if lower.has_suffix(".docx") {
    Docx
  } else {
    raise CliFailure(identify_error(@lib.UnsupportedFileExtension(file), file))
  }
}

///|
fn office_zip_read_failure(
  error : @zip.ZipError,
  file : String,
  expected : @lib.DocumentFormat,
) -> CliFailure {
  match error {
    @zip.ResourceLimitExceeded(kind~, limit~, actual~) =>
      CliFailure(
        @lib.protocol_error(
          "office.\{expected.name()}.resource_limit",
          "\{expected.name().to_upper()} ZIP \{bounded_text(kind, 80)} exceeds the configured limit",
          details=Json::object({
            "file": Json::string(bounded_text(file, 160)),
            "resource": Json::string(bounded_text(kind, 80)),
            "limit": Json::number(limit.to_double()),
            "actual": Json::number(actual.to_double()),
          }),
        ),
      )
    @zip.OutputLimitExceeded(limit~) =>
      format_resource_failure(expected.name(), "ZIP output", limit)
    _ =>
      CliFailure(
        @lib.protocol_error(
          "office.invalid_package",
          "invalid Office package: archive is not a readable bounded ZIP",
          details=Json::object({ "file": Json::string(bounded_text(file, 160)) }),
        ),
      )
  }
}

///|
fn office_xlsx_read_limits() -> @xlsx.ReadLimits raise @xlsx.XlsxError {
  @xlsx.ReadLimits::with_values(
    max_package_bytes=office_read_max_package_bytes,
    max_archive_entries=office_read_max_zip_entries,
    max_entry_uncompressed_bytes=office_read_max_zip_entry_bytes,
    max_total_uncompressed_bytes=office_read_max_zip_total_bytes,
    max_total_preserved_source_bytes=office_read_max_preserved_source_bytes,
    max_xml_part_bytes=office_read_max_xml_part_bytes,
  )
}

///|
async fn read_office_package(file : String) -> OfficeReadPackage {
  let expected = office_read_format_hint(file)
  let data = read_bounded_file(
    file,
    office_read_max_package_bytes,
    "office.file_read_failed",
    "input package",
    limit_code="office.\{expected.name()}.resource_limit",
  )
  let archive = @zip.read_limited(
    data,
    max_package_bytes=office_read_max_package_bytes,
    max_entries=office_read_max_zip_entries,
    max_entry_uncompressed_bytes=office_read_max_zip_entry_bytes,
    max_total_uncompressed_bytes=office_read_max_zip_total_bytes,
    max_total_preserved_source_bytes=office_read_max_preserved_source_bytes,
  ) catch {
    error => raise office_zip_read_failure(error, file, expected)
  }
  let format = @lib.detect_archive_format(file, archive) catch {
    error => raise CliFailure(identify_error(error, file))
  }
  { file, format, archive }
}

///|
fn xlsx_read_failure(error : @xlsx.XlsxError, file : String) -> CliFailure {
  match error {
    @xlsx.ResourceLimitExceeded(kind~, limit~, actual~) =>
      CliFailure(
        @lib.protocol_error(
          "office.xlsx.resource_limit",
          "XLSX \{bounded_text(kind, 80)} exceeds the configured limit",
          details=Json::object({
            "file": Json::string(bounded_text(file, 160)),
            "resource": Json::string(bounded_text(kind, 80)),
            "limit": Json::number(limit.to_double()),
            "actual": Json::number(actual.to_double()),
          }),
        ),
      )
    @xlsx.InvalidPackage(msg~) | @xlsx.InvalidXml(msg~) =>
      CliFailure(
        @lib.protocol_error(
          "office.invalid_package",
          "invalid XLSX package: " + bounded_text(msg, 320),
          details=Json::object({ "file": Json::string(bounded_text(file, 160)) }),
        ),
      )
    _ =>
      CliFailure(
        @lib.protocol_error(
          "office.xlsx.read_failed",
          "could not read XLSX workbook",
          details=Json::object({ "file": Json::string(bounded_text(file, 160)) }),
        ),
      )
  }
}

///|
fn open_xlsx_read_package(
  source : OfficeReadPackage,
) -> @xlsx.Workbook raise CliFailure {
  if source.format is Docx {
    raise CliFailure(
      @lib.protocol_error(
        "office.xlsx.format_mismatch", "XLSX reader received a validated DOCX package",
      ),
    )
  }
  let limits = office_xlsx_read_limits() catch {
    error => raise xlsx_read_failure(error, source.file)
  }
  @xlsx.read_bounded_archive(source.archive, limits~) catch {
    error => raise xlsx_read_failure(error, source.file)
  }
}
