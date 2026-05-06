#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include ".repos/miniz.h"
#include ".repos/miniz.c"

static moonbit_bytes_t pdflite_zlib_status_bytes(int32_t ok, const uint8_t *data, int32_t len) {
  if (!ok || len < 0 || len > INT32_MAX - 1) {
    moonbit_bytes_t result = moonbit_make_bytes(1, 0);
    result[0] = 0;
    return result;
  }
  moonbit_bytes_t result = moonbit_make_bytes(len + 1, 0);
  result[0] = 1;
  if (len > 0) {
    memcpy(result + 1, data, (size_t)len);
  }
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t pdflite_zlib_compress(moonbit_bytes_t input, int32_t level) {
  if (level < 0 || level > 9) {
    return pdflite_zlib_status_bytes(0, NULL, 0);
  }
  mz_ulong input_len = (mz_ulong)Moonbit_array_length(input);
  mz_ulong bound = mz_compressBound(input_len);
  if (bound > INT32_MAX) {
    return pdflite_zlib_status_bytes(0, NULL, 0);
  }
  uint8_t *buffer = (uint8_t *)malloc((size_t)bound);
  if (buffer == NULL && bound > 0) {
    return pdflite_zlib_status_bytes(0, NULL, 0);
  }
  mz_ulong output_len = bound;
  int status = mz_compress2(buffer, &output_len, input, input_len, level);
  moonbit_bytes_t result = status == MZ_OK && output_len <= INT32_MAX - 1
    ? pdflite_zlib_status_bytes(1, buffer, (int32_t)output_len)
    : pdflite_zlib_status_bytes(0, NULL, 0);
  free(buffer);
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t pdflite_zlib_decompress(moonbit_bytes_t input) {
  mz_stream stream;
  memset(&stream, 0, sizeof(stream));
  int status = mz_inflateInit(&stream);
  if (status != MZ_OK) {
    return pdflite_zlib_status_bytes(0, NULL, 0);
  }

  stream.next_in = input;
  stream.avail_in = (unsigned int)Moonbit_array_length(input);

  size_t capacity = 1024;
  size_t length = 0;
  uint8_t *output = (uint8_t *)malloc(capacity);
  if (output == NULL) {
    mz_inflateEnd(&stream);
    return pdflite_zlib_status_bytes(0, NULL, 0);
  }

  do {
    if (length == capacity) {
      if (capacity > (size_t)INT32_MAX / 2) {
        free(output);
        mz_inflateEnd(&stream);
        return pdflite_zlib_status_bytes(0, NULL, 0);
      }
      size_t next_capacity = capacity * 2;
      uint8_t *next = (uint8_t *)realloc(output, next_capacity);
      if (next == NULL) {
        free(output);
        mz_inflateEnd(&stream);
        return pdflite_zlib_status_bytes(0, NULL, 0);
      }
      output = next;
      capacity = next_capacity;
    }
    stream.next_out = output + length;
    stream.avail_out = (unsigned int)(capacity - length);
    status = mz_inflate(&stream, MZ_NO_FLUSH);
    length = capacity - stream.avail_out;
  } while (status == MZ_OK);

  moonbit_bytes_t result = status == MZ_STREAM_END && length <= (size_t)INT32_MAX - 1
    ? pdflite_zlib_status_bytes(1, output, (int32_t)length)
    : pdflite_zlib_status_bytes(0, NULL, 0);
  free(output);
  mz_inflateEnd(&stream);
  return result;
}
