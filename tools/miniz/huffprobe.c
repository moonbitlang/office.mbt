/* Dev-time oracle for the MoonBit port of miniz's Huffman builder.
 *
 * miniz's tdefl_radix_sort_syms / tdefl_calculate_minimum_redundancy /
 * tdefl_huffman_enforce_max_code_size are static, so this includes the
 * translation unit to reach them. It prints, for a frequency vector on stdin,
 * the code length each symbol receives -- which is exactly what the MoonBit
 * port has to reproduce before any of the rest of the compressor is worth
 * writing.
 *
 * Not part of the build. Compile ad hoc:
 *   cc -o huffprobe huffprobe.c -I<vendor/miniz>
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "miniz.c"

int main(void) {
  /* one case per line: n freq0 freq1 ... freq{n-1} */
  char line[65536];
  while (fgets(line, sizeof line, stdin)) {
    int n = 0;
    char *cursor = line;
    int freqs[288];
    int count = 0;
    n = (int)strtol(cursor, &cursor, 10);
    if (n <= 0) continue;
    for (int i = 0; i < n; i++) freqs[i] = (int)strtol(cursor, &cursor, 10);

    tdefl_sym_freq syms0[TDEFL_MAX_HUFF_SYMBOLS], syms1[TDEFL_MAX_HUFF_SYMBOLS];
    int used = 0;
    for (int i = 0; i < n; i++) {
      if (freqs[i]) {
        syms0[used].m_key = (mz_uint16)freqs[i];
        syms0[used].m_sym_index = (mz_uint16)i;
        used++;
      }
    }
    if (used == 0) { printf("\n"); continue; }

    tdefl_sym_freq *sorted = tdefl_radix_sort_syms(used, syms0, syms1);
    tdefl_calculate_minimum_redundancy(sorted, used);

    int num_codes[1 + TDEFL_MAX_SUPPORTED_HUFF_CODESIZE];
    memset(num_codes, 0, sizeof num_codes);
    for (int i = 0; i < used; i++) num_codes[sorted[i].m_key]++;
    tdefl_huffman_enforce_max_code_size(num_codes, used, 15);

    /* symbol -> code length, in symbol order, so the comparison is stable */
    int sizes[288];
    memset(sizes, 0, sizeof sizes);
    int k = used;
    for (int i = 1; i <= 15; i++)
      for (int j = num_codes[i]; j > 0; j--)
        sizes[sorted[--k].m_sym_index] = i;

    for (int i = 0; i < n; i++) printf("%d ", sizes[i]);
    printf("\n");
    count++;
  }
  return 0;
}
