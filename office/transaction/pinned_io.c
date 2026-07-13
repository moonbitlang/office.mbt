#ifndef _WIN32
#define _GNU_SOURCE
#endif

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winternl.h>

typedef NTSTATUS(NTAPI *office_nt_create_file_fn)(
    PHANDLE, ACCESS_MASK, POBJECT_ATTRIBUTES, PIO_STATUS_BLOCK, PLARGE_INTEGER,
    ULONG, ULONG, ULONG, ULONG, PVOID, ULONG);
typedef ULONG(WINAPI *office_ntstatus_to_error_fn)(NTSTATUS);

typedef struct {
  HANDLE handle;
  DWORD error;
} office_publication_directory;

typedef struct {
  HANDLE file;
  HANDLE directory;
  DWORD error;
  int published;
  int cleaned;
} office_publication_temp;

static wchar_t *office_utf8_to_wide(const uint8_t *text, DWORD *error) {
  int length;
  wchar_t *wide;
  if (text == NULL) {
    *error = ERROR_INVALID_PARAMETER;
    return NULL;
  }
  length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                               (const char *)text, -1, NULL, 0);
  if (length <= 0) {
    *error = GetLastError();
    return NULL;
  }
  wide = (wchar_t *)malloc((size_t)length * sizeof(wchar_t));
  if (wide == NULL) {
    *error = ERROR_NOT_ENOUGH_MEMORY;
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)text,
                          -1, wide, length) <= 0) {
    *error = GetLastError();
    free(wide);
    return NULL;
  }
  return wide;
}

static DWORD office_ntstatus_error(NTSTATUS status) {
  HMODULE module = GetModuleHandleW(L"ntdll.dll");
  office_ntstatus_to_error_fn convert;
  if (module == NULL) {
    return ERROR_GEN_FAILURE;
  }
  convert = (office_ntstatus_to_error_fn)GetProcAddress(
      module, "RtlNtStatusToDosError");
  if (convert == NULL) {
    return ERROR_GEN_FAILURE;
  }
  return convert(status);
}

static HANDLE office_create_relative_file(HANDLE directory,
                                          const wchar_t *leaf, DWORD *error) {
  HMODULE module = GetModuleHandleW(L"ntdll.dll");
  office_nt_create_file_fn create_file;
  UNICODE_STRING name;
  OBJECT_ATTRIBUTES attributes;
  IO_STATUS_BLOCK status_block;
  HANDLE file = INVALID_HANDLE_VALUE;
  size_t characters;
  NTSTATUS status;
  if (module == NULL) {
    *error = ERROR_PROC_NOT_FOUND;
    return INVALID_HANDLE_VALUE;
  }
  create_file =
      (office_nt_create_file_fn)GetProcAddress(module, "NtCreateFile");
  if (create_file == NULL) {
    *error = ERROR_PROC_NOT_FOUND;
    return INVALID_HANDLE_VALUE;
  }
  characters = wcslen(leaf);
  if (characters > 32767) {
    *error = ERROR_FILENAME_EXCED_RANGE;
    return INVALID_HANDLE_VALUE;
  }
  name.Buffer = (PWSTR)leaf;
  name.Length = (USHORT)(characters * sizeof(wchar_t));
  name.MaximumLength = name.Length;
  InitializeObjectAttributes(&attributes, &name, 0, directory, NULL);
  status = create_file(
      &file, GENERIC_WRITE | DELETE | SYNCHRONIZE, &attributes, &status_block,
      NULL, FILE_ATTRIBUTE_TEMPORARY, FILE_SHARE_READ | FILE_SHARE_WRITE |
                                          FILE_SHARE_DELETE,
      FILE_CREATE, FILE_NON_DIRECTORY_FILE | FILE_SYNCHRONOUS_IO_NONALERT, NULL,
      0);
  if (status < 0) {
    *error = office_ntstatus_error(status);
    return INVALID_HANDLE_VALUE;
  }
  return file;
}

static int office_delete_open_file(HANDLE file, DWORD *error) {
  FILE_DISPOSITION_INFO disposition;
  disposition.DeleteFile = TRUE;
  if (!SetFileInformationByHandle(file, FileDispositionInfo, &disposition,
                                  sizeof(disposition))) {
    *error = GetLastError();
    return 0;
  }
  return 1;
}

static office_publication_directory *office_directory_from_handle(
    uint64_t handle) {
  return (office_publication_directory *)(uintptr_t)handle;
}

static office_publication_temp *office_temp_from_handle(uint64_t handle) {
  return (office_publication_temp *)(uintptr_t)handle;
}

static void office_directory_release(office_publication_directory *directory) {
  if (directory == NULL) {
    return;
  }
  if (directory->handle != INVALID_HANDLE_VALUE) {
    CloseHandle(directory->handle);
    directory->handle = INVALID_HANDLE_VALUE;
  }
  free(directory);
}

static void office_temp_release(office_publication_temp *temp) {
  if (temp == NULL) {
    return;
  }
  if (temp->file != INVALID_HANDLE_VALUE) {
    CloseHandle(temp->file);
    temp->file = INVALID_HANDLE_VALUE;
  }
  if (temp->directory != INVALID_HANDLE_VALUE) {
    CloseHandle(temp->directory);
    temp->directory = INVALID_HANDLE_VALUE;
  }
  free(temp);
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_directory_open(uint8_t *path) {
  office_publication_directory *directory =
      (office_publication_directory *)malloc(
          sizeof(office_publication_directory));
  wchar_t *wide;
  if (directory == NULL) {
    return 0;
  }
  directory->handle = INVALID_HANDLE_VALUE;
  directory->error = ERROR_SUCCESS;
  wide = office_utf8_to_wide(path, &directory->error);
  if (wide == NULL) {
    return (uint64_t)(uintptr_t)directory;
  }
  directory->handle = CreateFileW(
      wide, FILE_LIST_DIRECTORY | FILE_TRAVERSE | SYNCHRONIZE,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
      OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
  if (directory->handle == INVALID_HANDLE_VALUE) {
    directory->error = GetLastError();
  }
  free(wide);
  return (uint64_t)(uintptr_t)directory;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_directory_ok(
    uint64_t handle) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  return directory != NULL && directory->handle != INVALID_HANDLE_VALUE;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_directory_error(
    uint64_t handle) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  return directory == NULL ? (int32_t)ERROR_NOT_ENOUGH_MEMORY
                           : (int32_t)directory->error;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_temp_create(
    uint64_t directory_handle, uint8_t *leaf, int32_t permission) {
  office_publication_directory *directory =
      office_directory_from_handle(directory_handle);
  office_publication_temp *temp =
      (office_publication_temp *)malloc(sizeof(office_publication_temp));
  wchar_t *wide;
  if (temp == NULL) {
    return 0;
  }
  (void)permission;
  temp->file = INVALID_HANDLE_VALUE;
  temp->directory = INVALID_HANDLE_VALUE;
  temp->error = ERROR_SUCCESS;
  temp->published = 0;
  temp->cleaned = 0;
  if (directory == NULL || directory->handle == INVALID_HANDLE_VALUE) {
    temp->error = directory != NULL && directory->error != ERROR_SUCCESS
                      ? directory->error
                      : ERROR_INVALID_HANDLE;
    return (uint64_t)(uintptr_t)temp;
  }
  wide = office_utf8_to_wide(leaf, &temp->error);
  if (wide == NULL) {
    return (uint64_t)(uintptr_t)temp;
  }
  temp->file =
      office_create_relative_file(directory->handle, wide, &temp->error);
  free(wide);
  if (temp->file == INVALID_HANDLE_VALUE) {
    return (uint64_t)(uintptr_t)temp;
  }
  if (!DuplicateHandle(GetCurrentProcess(), directory->handle,
                       GetCurrentProcess(), &temp->directory, 0, FALSE,
                       DUPLICATE_SAME_ACCESS)) {
    temp->error = GetLastError();
    (void)office_delete_open_file(temp->file, &temp->error);
    CloseHandle(temp->file);
    temp->file = INVALID_HANDLE_VALUE;
  }
  return (uint64_t)(uintptr_t)temp;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_ok(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  return temp != NULL && temp->file != INVALID_HANDLE_VALUE;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_error(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  return temp == NULL ? (int32_t)ERROR_NOT_ENOUGH_MEMORY
                      : (int32_t)temp->error;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_write(
    uint64_t handle, uint8_t *bytes, int32_t offset, int32_t length) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  DWORD written = 0;
  if (temp == NULL) {
    return -1;
  }
  if (temp->file == INVALID_HANDLE_VALUE || offset < 0 || length < 0) {
    temp->error = ERROR_INVALID_HANDLE;
    return -1;
  }
  if (!WriteFile(temp->file, bytes + offset, (DWORD)length, &written, NULL)) {
    temp->error = GetLastError();
    return -1;
  }
  return (int32_t)written;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_sync(
    uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  if (temp == NULL) {
    return 0;
  }
  if (temp->file == INVALID_HANDLE_VALUE) {
    temp->error = ERROR_INVALID_HANDLE;
    return 0;
  }
  if (!FlushFileBuffers(temp->file)) {
    temp->error = GetLastError();
    return 0;
  }
  return 1;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_publish(
    uint64_t handle, uint8_t *destination_leaf, int32_t replace) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  wchar_t *wide;
  FILE_RENAME_INFO *rename_info;
  size_t characters;
  size_t size;
  if (temp == NULL) {
    return 0;
  }
  if (temp->file == INVALID_HANDLE_VALUE ||
      temp->directory == INVALID_HANDLE_VALUE) {
    temp->error = ERROR_INVALID_HANDLE;
    return 0;
  }
  wide = office_utf8_to_wide(destination_leaf, &temp->error);
  if (wide == NULL) {
    return 0;
  }
  characters = wcslen(wide);
  size = sizeof(FILE_RENAME_INFO) + characters * sizeof(wchar_t);
  rename_info = (FILE_RENAME_INFO *)calloc(1, size);
  if (rename_info == NULL) {
    free(wide);
    temp->error = ERROR_NOT_ENOUGH_MEMORY;
    return 0;
  }
  rename_info->ReplaceIfExists = replace ? TRUE : FALSE;
  rename_info->RootDirectory = temp->directory;
  rename_info->FileNameLength = (DWORD)(characters * sizeof(wchar_t));
  memcpy(rename_info->FileName, wide,
         (size_t)rename_info->FileNameLength);
  if (!SetFileInformationByHandle(temp->file, FileRenameInfo, rename_info,
                                  (DWORD)size)) {
    temp->error = GetLastError();
    free(rename_info);
    free(wide);
    return 0;
  }
  temp->published = 1;
  free(rename_info);
  free(wide);
  return 1;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_cleanup(
    uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  if (temp == NULL) {
    return 0;
  }
  if (temp->published || temp->cleaned) {
    return 1;
  }
  if (temp->file == INVALID_HANDLE_VALUE) {
    temp->error = ERROR_INVALID_HANDLE;
    return 0;
  }
  if (!office_delete_open_file(temp->file, &temp->error)) {
    return 0;
  }
  temp->cleaned = 1;
  CloseHandle(temp->file);
  temp->file = INVALID_HANDLE_VALUE;
  if (temp->directory != INVALID_HANDLE_VALUE) {
    CloseHandle(temp->directory);
    temp->directory = INVALID_HANDLE_VALUE;
  }
  return 1;
}

MOONBIT_FFI_EXPORT void bobzhang_office_transaction_temp_close(
    uint64_t handle) {
  office_temp_release(office_temp_from_handle(handle));
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_directory_sync(
    uint64_t handle) {
  (void)handle;
  return 0;
}

MOONBIT_FFI_EXPORT void bobzhang_office_transaction_directory_close(
    uint64_t handle) {
  office_directory_release(office_directory_from_handle(handle));
}

#else

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifdef __linux__
#include <sys/syscall.h>
#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1U << 0)
#endif
#endif

#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif
#ifndef O_DIRECTORY
#define O_DIRECTORY 0
#endif

typedef struct {
  int fd;
  int error;
} office_publication_directory;

typedef struct {
  int file_fd;
  int directory_fd;
  char *leaf;
  int error;
  int published;
  int cleaned;
} office_publication_temp;

static char *office_copy_text(const uint8_t *text) {
  size_t length;
  char *copy;
  if (text == NULL) {
    errno = EINVAL;
    return NULL;
  }
  length = strlen((const char *)text);
  copy = (char *)malloc(length + 1);
  if (copy == NULL) {
    errno = ENOMEM;
    return NULL;
  }
  memcpy(copy, text, length + 1);
  return copy;
}

static int office_duplicate_fd(int fd) {
#ifdef F_DUPFD_CLOEXEC
  return fcntl(fd, F_DUPFD_CLOEXEC, 0);
#else
  return dup(fd);
#endif
}

static office_publication_directory *office_directory_from_handle(
    uint64_t handle) {
  return (office_publication_directory *)(uintptr_t)handle;
}

static office_publication_temp *office_temp_from_handle(uint64_t handle) {
  return (office_publication_temp *)(uintptr_t)handle;
}

static void office_directory_release(office_publication_directory *directory) {
  if (directory == NULL) {
    return;
  }
  if (directory->fd >= 0) {
    close(directory->fd);
    directory->fd = -1;
  }
  free(directory);
}

static void office_temp_release(office_publication_temp *temp) {
  if (temp == NULL) {
    return;
  }
  if (temp->file_fd >= 0) {
    close(temp->file_fd);
    temp->file_fd = -1;
  }
  if (temp->directory_fd >= 0) {
    close(temp->directory_fd);
    temp->directory_fd = -1;
  }
  free(temp->leaf);
  temp->leaf = NULL;
  free(temp);
}

static int office_sync_fd(int fd) {
  int result;
  do {
    result = fsync(fd);
  } while (result < 0 && errno == EINTR);
  return result;
}

static int office_publish_no_replace(int directory_fd, const char *source,
                                     const char *destination) {
#if defined(__APPLE__)
  return renameatx_np(directory_fd, source, directory_fd, destination,
                      RENAME_EXCL);
#elif defined(__linux__) && defined(SYS_renameat2)
  int result = (int)syscall(SYS_renameat2, directory_fd, source, directory_fd,
                            destination, RENAME_NOREPLACE);
  if (result == 0 || errno != ENOSYS) {
    return result;
  }
#endif
  errno = ENOTSUP;
  return -1;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_directory_open(uint8_t *path) {
  office_publication_directory *directory =
      (office_publication_directory *)malloc(
          sizeof(office_publication_directory));
  if (directory == NULL) {
    return 0;
  }
  directory->fd = open((const char *)path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  directory->error = directory->fd < 0 ? errno : 0;
  return (uint64_t)(uintptr_t)directory;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_directory_ok(
    uint64_t handle) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  return directory != NULL && directory->fd >= 0;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_directory_error(
    uint64_t handle) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  return directory == NULL ? ENOMEM : directory->error;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_temp_create(
    uint64_t directory_handle, uint8_t *leaf, int32_t permission) {
  office_publication_directory *directory =
      office_directory_from_handle(directory_handle);
  office_publication_temp *temp =
      (office_publication_temp *)malloc(sizeof(office_publication_temp));
  if (temp == NULL) {
    return 0;
  }
  temp->file_fd = -1;
  temp->directory_fd = -1;
  temp->leaf = NULL;
  temp->error = 0;
  temp->published = 0;
  temp->cleaned = 0;
  if (directory == NULL || directory->fd < 0) {
    temp->error = directory != NULL && directory->error != 0
                      ? directory->error
                      : EBADF;
    return (uint64_t)(uintptr_t)temp;
  }
  temp->leaf = office_copy_text(leaf);
  if (temp->leaf == NULL) {
    temp->error = errno;
    return (uint64_t)(uintptr_t)temp;
  }
  temp->directory_fd = office_duplicate_fd(directory->fd);
  if (temp->directory_fd < 0) {
    temp->error = errno;
    return (uint64_t)(uintptr_t)temp;
  }
  temp->file_fd = openat(temp->directory_fd, temp->leaf,
                         O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC,
                         (mode_t)permission);
  if (temp->file_fd < 0) {
    temp->error = errno;
    return (uint64_t)(uintptr_t)temp;
  }
  return (uint64_t)(uintptr_t)temp;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_ok(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  return temp != NULL && temp->file_fd >= 0 && temp->directory_fd >= 0;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_error(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  return temp == NULL ? ENOMEM : temp->error;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_write(
    uint64_t handle, uint8_t *bytes, int32_t offset, int32_t length) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  ssize_t written;
  if (temp == NULL) {
    return -1;
  }
  if (temp->file_fd < 0 || offset < 0 || length < 0) {
    temp->error = EBADF;
    return -1;
  }
  do {
    written = write(temp->file_fd, bytes + offset, (size_t)length);
  } while (written < 0 && errno == EINTR);
  if (written < 0) {
    temp->error = errno;
    return -1;
  }
  return (int32_t)written;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_sync(
    uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  if (temp == NULL) {
    return 0;
  }
  if (temp->file_fd < 0) {
    temp->error = EBADF;
    return 0;
  }
  if (office_sync_fd(temp->file_fd) < 0) {
    temp->error = errno;
    return 0;
  }
  return 1;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_publish(
    uint64_t handle, uint8_t *destination_leaf, int32_t replace) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  int result;
  if (temp == NULL) {
    return 0;
  }
  if (temp->file_fd < 0 || temp->directory_fd < 0 || temp->leaf == NULL) {
    temp->error = EBADF;
    return 0;
  }
  if (replace) {
    result = renameat(temp->directory_fd, temp->leaf, temp->directory_fd,
                      (const char *)destination_leaf);
  } else {
    result = office_publish_no_replace(temp->directory_fd, temp->leaf,
                                       (const char *)destination_leaf);
  }
  if (result < 0) {
    temp->error = errno;
    return 0;
  }
  temp->published = 1;
  return 1;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_cleanup(
    uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  if (temp == NULL) {
    return 0;
  }
  if (temp->published || temp->cleaned) {
    return 1;
  }
  if (temp->directory_fd < 0 || temp->leaf == NULL) {
    temp->error = EBADF;
    return 0;
  }
  if (temp->file_fd >= 0) {
    close(temp->file_fd);
    temp->file_fd = -1;
  }
  if (unlinkat(temp->directory_fd, temp->leaf, 0) < 0) {
    if (errno == ENOENT) {
      temp->cleaned = 1;
      return 1;
    }
    temp->error = errno;
    return 0;
  }
  temp->cleaned = 1;
  return 1;
}

MOONBIT_FFI_EXPORT void bobzhang_office_transaction_temp_close(
    uint64_t handle) {
  office_temp_release(office_temp_from_handle(handle));
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_directory_sync(
    uint64_t handle) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  if (directory == NULL) {
    return 0;
  }
  if (directory->fd < 0) {
    directory->error = EBADF;
    return 0;
  }
  if (office_sync_fd(directory->fd) < 0) {
    directory->error = errno;
    return 0;
  }
  return 1;
}

MOONBIT_FFI_EXPORT void bobzhang_office_transaction_directory_close(
    uint64_t handle) {
  office_directory_release(office_directory_from_handle(handle));
}

#endif
