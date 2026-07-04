#include <moonbit.h>
#include <stdint.h>

#if defined(_WIN32)
#include <windows.h>
#include <bcrypt.h>
#pragma comment(lib, "Bcrypt.lib")
#else
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#endif

MOONBIT_FFI_EXPORT
int32_t pdflite_secure_random_bytes(void *buf, int32_t num) {
  if (num < 0) {
    return 0;
  }
  if (num == 0) {
    return 1;
  }

#if defined(_WIN32)
  return BCryptGenRandom(NULL, buf, (ULONG)num, BCRYPT_USE_SYSTEM_PREFERRED_RNG) == 0;
#else
  int fd = open("/dev/urandom", O_RDONLY);
  if (fd < 0) {
    return 0;
  }

  int32_t done = 0;
  while (done < num) {
    ssize_t count = read(fd, (unsigned char *)buf + done, (size_t)(num - done));
    if (count < 0) {
      if (errno == EINTR) {
        continue;
      }
      close(fd);
      return 0;
    }
    if (count == 0) {
      close(fd);
      return 0;
    }
    done += (int32_t)count;
  }

  close(fd);
  return 1;
#endif
}
