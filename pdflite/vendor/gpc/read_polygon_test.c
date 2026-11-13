/* Regression checks for the local formatted-input handling patch. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "gpc.h"

static gpc_polygon read_polygon(const char *text, int holes) {
  FILE *file = tmpfile();
  assert(file != NULL);
  assert(fwrite(text, 1, strlen(text), file) == strlen(text));
  rewind(file);
  gpc_polygon polygon;
  gpc_read_polygon(file, holes, &polygon);
  assert(fclose(file) == 0);
  return polygon;
}

int main(void) {
  const char *invalid[] = {
    "", "x", "-1", "1", "1 -1", "1 1", "1 1 x", "1 1 0", "1 1 0 2",
    "2 1 0 2 3", "2 1 0 2 3 1 0 4 x", "3 1 0 2 3 1 0 4 5 1"
  };
  for (unsigned i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    gpc_polygon polygon = read_polygon(invalid[i], 1);
    assert(polygon.num_contours == 0);
    assert(polygon.hole == NULL);
    assert(polygon.contour == NULL);
    gpc_free_polygon(&polygon);
  }
  gpc_polygon polygon = read_polygon("1 3 1 0 0 2 0 0 2", 1);
  assert(polygon.num_contours == 1);
  assert(polygon.hole[0] == 1);
  assert(polygon.contour[0].num_vertices == 3);
  assert(polygon.contour[0].vertex[1].x == 2.0);
  gpc_free_polygon(&polygon);
  polygon = read_polygon("1 1 3 4", 0);
  assert(polygon.num_contours == 1);
  assert(polygon.hole[0] == 0);
  assert(polygon.contour[0].vertex[0].x == 3.0);
  assert(polygon.contour[0].vertex[0].y == 4.0);
  gpc_free_polygon(&polygon);
  polygon = read_polygon("0", 1);
  assert(polygon.num_contours == 0);
  gpc_free_polygon(&polygon);
  puts("GPC formatted read regression: OK");
  return 0;
}
