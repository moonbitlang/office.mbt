#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "../vendor/miniz/miniz.h"
#include "../vendor/miniz/miniz.c"

static moonbit_bytes_t pdflite_zlib_result_bytes(
  int32_t ok,
  const uint8_t *data,
  int32_t len,
  int32_t *status_out
) {
  *status_out = ok ? 1 : 0;
  if (!ok || len < 0) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t result = moonbit_make_bytes(len, 0);
  if (len > 0) {
    memcpy(result, data, (size_t)len);
  }
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t pdflite_zlib_compress(
  moonbit_bytes_t input,
  int32_t level,
  int32_t *status_out
) {
  if (level < 0 || level > 9) {
    return pdflite_zlib_result_bytes(0, NULL, 0, status_out);
  }
  mz_ulong input_len = (mz_ulong)Moonbit_array_length(input);
  mz_ulong bound = mz_compressBound(input_len);
  if (bound > INT32_MAX) {
    return pdflite_zlib_result_bytes(0, NULL, 0, status_out);
  }
  uint8_t *buffer = (uint8_t *)malloc((size_t)bound);
  if (buffer == NULL && bound > 0) {
    return pdflite_zlib_result_bytes(0, NULL, 0, status_out);
  }
  mz_ulong output_len = bound;
  int zstatus = mz_compress2(buffer, &output_len, input, input_len, level);
  moonbit_bytes_t result = zstatus == MZ_OK && output_len <= INT32_MAX
    ? pdflite_zlib_result_bytes(1, buffer, (int32_t)output_len, status_out)
    : pdflite_zlib_result_bytes(0, NULL, 0, status_out);
  free(buffer);
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t pdflite_zlib_decompress(
  moonbit_bytes_t input,
  int32_t *status_out
) {
  mz_stream stream;
  memset(&stream, 0, sizeof(stream));
  int zstatus = mz_inflateInit(&stream);
  if (zstatus != MZ_OK) {
    return pdflite_zlib_result_bytes(0, NULL, 0, status_out);
  }

  stream.next_in = input;
  stream.avail_in = (unsigned int)Moonbit_array_length(input);

  size_t capacity = 1024;
  size_t length = 0;
  uint8_t *output = (uint8_t *)malloc(capacity);
  if (output == NULL) {
    mz_inflateEnd(&stream);
    return pdflite_zlib_result_bytes(0, NULL, 0, status_out);
  }

  do {
    if (length == capacity) {
      if (capacity > (size_t)INT32_MAX / 2) {
        free(output);
        mz_inflateEnd(&stream);
        return pdflite_zlib_result_bytes(0, NULL, 0, status_out);
      }
      size_t next_capacity = capacity * 2;
      uint8_t *next = (uint8_t *)realloc(output, next_capacity);
      if (next == NULL) {
        free(output);
        mz_inflateEnd(&stream);
        return pdflite_zlib_result_bytes(0, NULL, 0, status_out);
      }
      output = next;
      capacity = next_capacity;
    }
    stream.next_out = output + length;
    stream.avail_out = (unsigned int)(capacity - length);
    zstatus = mz_inflate(&stream, MZ_NO_FLUSH);
    length = capacity - stream.avail_out;
  } while (zstatus == MZ_OK);

  moonbit_bytes_t result = zstatus == MZ_STREAM_END && length <= (size_t)INT32_MAX
    ? pdflite_zlib_result_bytes(1, output, (int32_t)length, status_out)
    : pdflite_zlib_result_bytes(0, NULL, 0, status_out);
  free(output);
  mz_inflateEnd(&stream);
  return result;
}
