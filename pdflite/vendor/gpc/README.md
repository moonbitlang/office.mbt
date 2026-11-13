Vendored Generic Polygon Clipper sources from CamlPDF's `gpc.c` and `gpc.h`.

The upstream files carry Alan Murta's MIT-style license header. They are vendored
so the native `pdf_clip` binding can build without relying on any local migration
source checkout.

Local changes: `gpc_read_polygon` checks formatted reads and returns an empty,
fully cleaned polygon on a failed scan or a negative count.
This also keeps fortified native builds free of ignored-result warnings.

Run the input regression checks from the repository root:

```sh
cc -O2 -D_FORTIFY_SOURCE=2 -Werror=unused-result \
  -fsanitize=address,undefined -fno-omit-frame-pointer \
  -I pdflite/vendor/gpc pdflite/vendor/gpc/read_polygon_test.c \
  pdflite/vendor/gpc/gpc.c -lm -o /tmp/gpc-read-test
/tmp/gpc-read-test
```
