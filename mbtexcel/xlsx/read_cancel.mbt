///|
/// Raises the stable XLSX cancellation error at synchronous work boundaries.
/// Callers supply a cheap task-state probe; no runtime- or platform-specific
/// stubs are required.
fn check_read_cancelled(cancelled : () -> Bool) -> Unit raise XlsxError {
  if cancelled() {
    raise ReadCancelled
  }
}
