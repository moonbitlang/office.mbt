#include <moonbit.h>
#include <stdint.h>
#include <time.h>

MOONBIT_FFI_EXPORT
int32_t pdflite_local_time(int32_t *out) {
  if (out == NULL) {
    return 0;
  }

  time_t now = time(NULL);
  if (now == (time_t)-1) {
    return 0;
  }

  struct tm local;
#if defined(_WIN32)
  if (localtime_s(&local, &now) != 0) {
    return 0;
  }
#else
  if (localtime_r(&now, &local) == NULL) {
    return 0;
  }
#endif

  out[0] = (int32_t)local.tm_sec;
  out[1] = (int32_t)local.tm_min;
  out[2] = (int32_t)local.tm_hour;
  out[3] = (int32_t)local.tm_mday;
  out[4] = (int32_t)local.tm_mon;
  out[5] = (int32_t)local.tm_year;
  out[6] = (int32_t)local.tm_wday;
  out[7] = (int32_t)local.tm_yday;
  out[8] = (int32_t)local.tm_isdst;
  return 1;
}
