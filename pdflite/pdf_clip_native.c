#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "vendor/gpc/gpc.h"
#include "vendor/gpc/gpc.c"

typedef struct {
  const uint8_t *data;
  int32_t length;
  int32_t position;
} pdflite_clip_reader_t;

static moonbit_bytes_t pdflite_gpc_failure(int32_t *status_out) {
  *status_out = 0;
  return moonbit_make_bytes(0, 0);
}

static int pdflite_gpc_read_i32(
  pdflite_clip_reader_t *reader,
  int32_t *value_out
) {
  if (
    reader->position < 0 ||
    reader->position > reader->length ||
    reader->length - reader->position < 4
  ) {
    return 0;
  }
  const uint8_t *data = reader->data + reader->position;
  uint32_t value =
    ((uint32_t)data[0]) |
    ((uint32_t)data[1] << 8) |
    ((uint32_t)data[2] << 16) |
    ((uint32_t)data[3] << 24);
  if (value > INT32_MAX) {
    return 0;
  }
  reader->position += 4;
  *value_out = (int32_t)value;
  return 1;
}

static int pdflite_gpc_read_double(
  pdflite_clip_reader_t *reader,
  double *value_out
) {
  if (
    reader->position < 0 ||
    reader->position > reader->length ||
    reader->length - reader->position < 8
  ) {
    return 0;
  }
  const uint8_t *data = reader->data + reader->position;
  uint64_t bits =
    ((uint64_t)data[0]) |
    ((uint64_t)data[1] << 8) |
    ((uint64_t)data[2] << 16) |
    ((uint64_t)data[3] << 24) |
    ((uint64_t)data[4] << 32) |
    ((uint64_t)data[5] << 40) |
    ((uint64_t)data[6] << 48) |
    ((uint64_t)data[7] << 56);
  memcpy(value_out, &bits, sizeof(bits));
  reader->position += 8;
  return 1;
}

static int pdflite_gpc_size_overflows(size_t count, size_t item_size) {
  return item_size != 0 && count > SIZE_MAX / item_size;
}

static int pdflite_gpc_decode_polygon(
  moonbit_bytes_t bytes,
  gpc_polygon *polygon
) {
  polygon->num_contours = 0;
  polygon->hole = NULL;
  polygon->contour = NULL;

  pdflite_clip_reader_t reader = {
    .data = bytes,
    .length = Moonbit_array_length(bytes),
    .position = 0,
  };

  int32_t num_contours = 0;
  if (!pdflite_gpc_read_i32(&reader, &num_contours)) {
    return 0;
  }
  if (num_contours > (reader.length - reader.position) / 8) {
    return 0;
  }
  if (num_contours > 0) {
    if (
      pdflite_gpc_size_overflows((size_t)num_contours, sizeof(int)) ||
      pdflite_gpc_size_overflows((size_t)num_contours, sizeof(gpc_vertex_list))
    ) {
      return 0;
    }
    polygon->hole = (int *)calloc((size_t)num_contours, sizeof(int));
    polygon->contour = (gpc_vertex_list *)calloc(
      (size_t)num_contours,
      sizeof(gpc_vertex_list)
    );
    if (polygon->hole == NULL || polygon->contour == NULL) {
      gpc_free_polygon(polygon);
      return 0;
    }
  }
  polygon->num_contours = num_contours;

  for (int32_t c = 0; c < num_contours; c++) {
    int32_t hole = 0;
    int32_t num_vertices = 0;
    if (
      !pdflite_gpc_read_i32(&reader, &hole) ||
      (hole != 0 && hole != 1) ||
      !pdflite_gpc_read_i32(&reader, &num_vertices)
    ) {
      gpc_free_polygon(polygon);
      return 0;
    }
    polygon->hole[c] = hole;
    polygon->contour[c].num_vertices = num_vertices;
    if (num_vertices > (reader.length - reader.position) / 16) {
      gpc_free_polygon(polygon);
      return 0;
    }
    if (num_vertices > 0) {
      if (pdflite_gpc_size_overflows(
        (size_t)num_vertices,
        sizeof(gpc_vertex)
      )) {
        gpc_free_polygon(polygon);
        return 0;
      }
      polygon->contour[c].vertex = (gpc_vertex *)calloc(
        (size_t)num_vertices,
        sizeof(gpc_vertex)
      );
      if (polygon->contour[c].vertex == NULL) {
        gpc_free_polygon(polygon);
        return 0;
      }
    }
    for (int32_t v = 0; v < num_vertices; v++) {
      if (
        !pdflite_gpc_read_double(&reader, &polygon->contour[c].vertex[v].x) ||
        !pdflite_gpc_read_double(&reader, &polygon->contour[c].vertex[v].y)
      ) {
        gpc_free_polygon(polygon);
        return 0;
      }
    }
  }

  if (reader.position != reader.length) {
    gpc_free_polygon(polygon);
    return 0;
  }
  return 1;
}

static int pdflite_gpc_add_size(size_t *length, size_t addend) {
  if (*length > SIZE_MAX - addend) {
    return 0;
  }
  *length += addend;
  return 1;
}

static int pdflite_gpc_encoded_length(
  const gpc_polygon *polygon,
  size_t *length_out
) {
  if (polygon->num_contours < 0) {
    return 0;
  }
  if (
    polygon->num_contours > 0 &&
    (polygon->hole == NULL || polygon->contour == NULL)
  ) {
    return 0;
  }
  size_t length = 4;
  for (int c = 0; c < polygon->num_contours; c++) {
    if (!pdflite_gpc_add_size(&length, 8)) {
      return 0;
    }
    int num_vertices = polygon->contour[c].num_vertices;
    if (
      num_vertices < 0 ||
      (size_t)num_vertices > (SIZE_MAX / 16) ||
      !pdflite_gpc_add_size(&length, (size_t)num_vertices * 16)
    ) {
      return 0;
    }
  }
  if (length > INT32_MAX) {
    return 0;
  }
  *length_out = length;
  return 1;
}

static void pdflite_gpc_write_i32(
  uint8_t *output,
  int32_t *position,
  int32_t value
) {
  uint32_t bits = (uint32_t)value;
  output[(*position)++] = (uint8_t)(bits & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 8) & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 16) & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 24) & 0xff);
}

static void pdflite_gpc_write_double(
  uint8_t *output,
  int32_t *position,
  double value
) {
  uint64_t bits = 0;
  memcpy(&bits, &value, sizeof(bits));
  output[(*position)++] = (uint8_t)(bits & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 8) & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 16) & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 24) & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 32) & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 40) & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 48) & 0xff);
  output[(*position)++] = (uint8_t)((bits >> 56) & 0xff);
}

static moonbit_bytes_t pdflite_gpc_encode_polygon(
  const gpc_polygon *polygon,
  int32_t *status_out
) {
  size_t length = 0;
  if (!pdflite_gpc_encoded_length(polygon, &length)) {
    return pdflite_gpc_failure(status_out);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)length, 0);
  int32_t position = 0;
  pdflite_gpc_write_i32(bytes, &position, polygon->num_contours);
  for (int c = 0; c < polygon->num_contours; c++) {
    pdflite_gpc_write_i32(bytes, &position, polygon->hole[c] ? 1 : 0);
    pdflite_gpc_write_i32(bytes, &position, polygon->contour[c].num_vertices);
    for (int v = 0; v < polygon->contour[c].num_vertices; v++) {
      pdflite_gpc_write_double(
        bytes,
        &position,
        polygon->contour[c].vertex[v].x
      );
      pdflite_gpc_write_double(
        bytes,
        &position,
        polygon->contour[c].vertex[v].y
      );
    }
  }
  *status_out = 1;
  return bytes;
}

static int pdflite_gpc_operation(int32_t operation, gpc_op *op_out) {
  switch (operation) {
    case 0:
      *op_out = GPC_DIFF;
      return 1;
    case 1:
      *op_out = GPC_INT;
      return 1;
    case 2:
      *op_out = GPC_XOR;
      return 1;
    case 3:
      *op_out = GPC_UNION;
      return 1;
    default:
      return 0;
  }
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t pdflite_gpc_clip(
  moonbit_bytes_t subject_bytes,
  moonbit_bytes_t clip_bytes,
  int32_t operation,
  int32_t *status_out
) {
  gpc_op op;
  if (!pdflite_gpc_operation(operation, &op)) {
    return pdflite_gpc_failure(status_out);
  }

  gpc_polygon subject = { 0, NULL, NULL };
  gpc_polygon clip = { 0, NULL, NULL };
  gpc_polygon result = { 0, NULL, NULL };
  if (
    !pdflite_gpc_decode_polygon(subject_bytes, &subject) ||
    !pdflite_gpc_decode_polygon(clip_bytes, &clip)
  ) {
    gpc_free_polygon(&subject);
    gpc_free_polygon(&clip);
    return pdflite_gpc_failure(status_out);
  }

  gpc_polygon_clip(op, &subject, &clip, &result);
  gpc_free_polygon(&subject);
  gpc_free_polygon(&clip);
  moonbit_bytes_t result_bytes = pdflite_gpc_encode_polygon(
    &result,
    status_out
  );
  gpc_free_polygon(&result);
  return result_bytes;
}
