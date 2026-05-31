#include <moonbit.h>
#include <stdio.h>
#include <stdlib.h>

MOONBIT_FFI_EXPORT
int docx2html_write_stdout(moonbit_bytes_t content) {
  size_t len = Moonbit_array_length(content);
  size_t written = fwrite(content, 1, len, stdout);
  fflush(stdout);
  return written == len ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int docx2html_write_stderr(moonbit_bytes_t content) {
  size_t len = Moonbit_array_length(content);
  size_t written = fwrite(content, 1, len, stderr);
  fflush(stderr);
  return written == len ? 0 : -1;
}

MOONBIT_FFI_EXPORT
void docx2html_exit(int status) {
  exit(status);
}
