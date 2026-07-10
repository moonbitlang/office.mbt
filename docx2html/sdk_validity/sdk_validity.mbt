// A native-only test package: docx schema validation through the Microsoft
// DocumentFormat.OpenXml SDK (scripts/validate_docx.sh). It lives in its own
// package rather than the module root so its async/process test imports
// never reach the wasm/js checks (they would be pruned there and trip the
// zero-warning baseline as unused_package).
//
// The package intentionally exports nothing; the test file carries the
// actual coverage.
