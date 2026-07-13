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
typedef NTSTATUS(WINAPI *office_bcrypt_gen_random_fn)(PVOID, PUCHAR, ULONG,
                                                       ULONG);

typedef struct {
  HANDLE handle;
  DWORD error;
} office_publication_directory;

typedef struct {
  HANDLE file;
  HANDLE directory;
  wchar_t *leaf;
  DWORD error;
  int published;
  int cleaned;
} office_publication_temp;

typedef struct {
  HANDLE thread;
  HANDLE target;
  volatile LONG done;
  DWORD error;
} office_sync_task;

typedef struct {
  HANDLE thread;
  HANDLE file;
  uint8_t *data;
  int32_t length;
  volatile LONG done;
  DWORD error;
} office_read_task;

typedef struct {
  HANDLE thread;
  HANDLE file;
  moonbit_bytes_t bytes;
  int32_t length;
  volatile LONG done;
  DWORD error;
} office_write_task;

static DWORD WINAPI office_sync_worker(LPVOID context) {
  office_sync_task *task = (office_sync_task *)context;
  if (!FlushFileBuffers(task->target)) {
    task->error = GetLastError();
  }
  CloseHandle(task->target);
  task->target = INVALID_HANDLE_VALUE;
  InterlockedExchange(&task->done, 1);
  return 0;
}

static uint64_t office_sync_start(HANDLE source) {
  office_sync_task *task = (office_sync_task *)calloc(1, sizeof(*task));
  if (task == NULL) {
    return 0;
  }
  task->thread = NULL;
  task->target = INVALID_HANDLE_VALUE;
  task->done = 0;
  task->error = ERROR_SUCCESS;
  if (!DuplicateHandle(GetCurrentProcess(), source, GetCurrentProcess(),
                       &task->target, 0, FALSE, DUPLICATE_SAME_ACCESS)) {
    task->error = GetLastError();
    task->done = 1;
    return (uint64_t)(uintptr_t)task;
  }
  task->thread = CreateThread(NULL, 0, office_sync_worker, task, 0, NULL);
  if (task->thread == NULL) {
    task->error = GetLastError();
    CloseHandle(task->target);
    task->target = INVALID_HANDLE_VALUE;
    task->done = 1;
  }
  return (uint64_t)(uintptr_t)task;
}

static DWORD WINAPI office_read_worker(LPVOID context) {
  office_read_task *task = (office_read_task *)context;
  int32_t offset = 0;
  while (offset < task->length) {
    DWORD count = 0;
    DWORD requested = (DWORD)(task->length - offset);
    if (!ReadFile(task->file, task->data + offset, requested, &count, NULL)) {
      task->error = GetLastError();
      break;
    }
    if (count == 0) {
      task->error = ERROR_HANDLE_EOF;
      break;
    }
    offset += (int32_t)count;
  }
  CloseHandle(task->file);
  task->file = INVALID_HANDLE_VALUE;
  InterlockedExchange(&task->done, 1);
  return 0;
}

static DWORD WINAPI office_write_worker(LPVOID context) {
  office_write_task *task = (office_write_task *)context;
  int32_t offset = 0;
  while (offset < task->length) {
    DWORD count = 0;
    DWORD requested = (DWORD)(task->length - offset);
    if (!WriteFile(task->file, task->bytes + offset, requested, &count, NULL)) {
      task->error = GetLastError();
      break;
    }
    if (count == 0) {
      task->error = ERROR_WRITE_FAULT;
      break;
    }
    offset += (int32_t)count;
  }
  CloseHandle(task->file);
  task->file = INVALID_HANDLE_VALUE;
  InterlockedExchange(&task->done, 1);
  return 0;
}

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

static HANDLE office_open_relative(HANDLE directory, const wchar_t *leaf,
                                   ACCESS_MASK access, ULONG disposition,
                                   ULONG attributes, ULONG options,
                                   DWORD *error) {
  HMODULE module = GetModuleHandleW(L"ntdll.dll");
  office_nt_create_file_fn create_file;
  UNICODE_STRING name;
  OBJECT_ATTRIBUTES object_attributes;
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
  if (characters == 0 || characters > 32767) {
    *error = ERROR_FILENAME_EXCED_RANGE;
    return INVALID_HANDLE_VALUE;
  }
  name.Buffer = (PWSTR)leaf;
  name.Length = (USHORT)(characters * sizeof(wchar_t));
  name.MaximumLength = name.Length;
  InitializeObjectAttributes(&object_attributes, &name, 0, directory, NULL);
  status = create_file(
      &file, access, &object_attributes, &status_block, NULL, attributes,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, disposition,
      options | FILE_SYNCHRONOUS_IO_NONALERT, NULL, 0);
  if (status < 0) {
    *error = office_ntstatus_error(status);
    return INVALID_HANDLE_VALUE;
  }
  return file;
}

static int office_duplicate_handle(HANDLE source, HANDLE *destination,
                                   DWORD *error) {
  if (!DuplicateHandle(GetCurrentProcess(), source, GetCurrentProcess(),
                       destination, 0, FALSE, DUPLICATE_SAME_ACCESS)) {
    *error = GetLastError();
    *destination = INVALID_HANDLE_VALUE;
    return 0;
  }
  return 1;
}

static int office_random_bytes(uint8_t *bytes, ULONG length, DWORD *error) {
  HMODULE module = LoadLibraryW(L"bcrypt.dll");
  office_bcrypt_gen_random_fn generate;
  NTSTATUS status;
  if (module == NULL) {
    *error = GetLastError();
    return 0;
  }
  generate = (office_bcrypt_gen_random_fn)GetProcAddress(module,
                                                          "BCryptGenRandom");
  if (generate == NULL) {
    *error = ERROR_PROC_NOT_FOUND;
    FreeLibrary(module);
    return 0;
  }
  status = generate(NULL, bytes, length, 0x00000002UL);
  FreeLibrary(module);
  if (status < 0) {
    *error = office_ntstatus_error(status);
    return 0;
  }
  return 1;
}

static wchar_t *office_random_leaf(DWORD *error) {
  static const wchar_t hex[] = L"0123456789abcdef";
  static const wchar_t prefix[] = L".office-tmp-";
  uint8_t random[16];
  size_t prefix_length = (sizeof(prefix) / sizeof(prefix[0])) - 1;
  wchar_t *leaf;
  size_t i;
  if (!office_random_bytes(random, (ULONG)sizeof(random), error)) {
    return NULL;
  }
  leaf = (wchar_t *)malloc((prefix_length + 32 + 1) * sizeof(wchar_t));
  if (leaf == NULL) {
    *error = ERROR_NOT_ENOUGH_MEMORY;
    return NULL;
  }
  memcpy(leaf, prefix, prefix_length * sizeof(wchar_t));
  for (i = 0; i < sizeof(random); ++i) {
    leaf[prefix_length + i * 2] = hex[random[i] >> 4];
    leaf[prefix_length + i * 2 + 1] = hex[random[i] & 0x0f];
  }
  leaf[prefix_length + 32] = L'\0';
  return leaf;
}

static int office_file_identity(HANDLE file, BY_HANDLE_FILE_INFORMATION *info,
                                DWORD *error) {
  if (!GetFileInformationByHandle(file, info)) {
    *error = GetLastError();
    return 0;
  }
  return 1;
}

static int office_same_file(HANDLE left, HANDLE right, DWORD *error) {
  BY_HANDLE_FILE_INFORMATION left_info;
  BY_HANDLE_FILE_INFORMATION right_info;
  if (!office_file_identity(left, &left_info, error) ||
      !office_file_identity(right, &right_info, error)) {
    return 0;
  }
  return left_info.dwVolumeSerialNumber == right_info.dwVolumeSerialNumber &&
         left_info.nFileIndexHigh == right_info.nFileIndexHigh &&
         left_info.nFileIndexLow == right_info.nFileIndexLow;
}

static int office_temp_path_is_owned(office_publication_temp *temp) {
  HANDLE current;
  int same;
  current = office_open_relative(temp->directory, temp->leaf,
                                 FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_OPEN,
                                 FILE_ATTRIBUTE_NORMAL, 0, &temp->error);
  if (current == INVALID_HANDLE_VALUE) {
    return 0;
  }
  same = office_same_file(temp->file, current, &temp->error);
  CloseHandle(current);
  if (!same && temp->error == ERROR_SUCCESS) {
    temp->error = ERROR_FILE_INVALID;
  }
  return same;
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

static int office_rename_open_file(HANDLE file, const wchar_t *leaf,
                                   int replace, DWORD *error) {
  FILE_RENAME_INFO *rename_info;
  size_t characters = wcslen(leaf);
  size_t size = sizeof(FILE_RENAME_INFO) + characters * sizeof(wchar_t);
  rename_info = (FILE_RENAME_INFO *)calloc(1, size);
  if (rename_info == NULL) {
    *error = ERROR_NOT_ENOUGH_MEMORY;
    return 0;
  }
  rename_info->ReplaceIfExists = replace ? TRUE : FALSE;
  /* RootDirectory must be NULL for SMB/SMB2. A simple leaf name means rename
     within the open file's current directory. */
  rename_info->RootDirectory = NULL;
  rename_info->FileNameLength = (DWORD)(characters * sizeof(wchar_t));
  memcpy(rename_info->FileName, leaf, rename_info->FileNameLength);
  if (!SetFileInformationByHandle(file, FileRenameInfo, rename_info,
                                  (DWORD)size)) {
    *error = GetLastError();
    free(rename_info);
    return 0;
  }
  free(rename_info);
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
  }
  free(directory);
}

static void office_temp_release(office_publication_temp *temp) {
  if (temp == NULL) {
    return;
  }
  if (temp->file != INVALID_HANDLE_VALUE) {
    CloseHandle(temp->file);
  }
  if (temp->directory != INVALID_HANDLE_VALUE) {
    CloseHandle(temp->directory);
  }
  free(temp->leaf);
  free(temp);
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_directory_open(uint8_t *path) {
  office_publication_directory *directory =
      (office_publication_directory *)malloc(sizeof(*directory));
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
      wide, FILE_LIST_DIRECTORY | FILE_TRAVERSE | FILE_READ_ATTRIBUTES |
                SYNCHRONIZE,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
      OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
  if (directory->handle == INVALID_HANDLE_VALUE) {
    directory->error = GetLastError();
  }
  free(wide);
  return (uint64_t)(uintptr_t)directory;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_directory_duplicate(uint64_t handle) {
  office_publication_directory *source = office_directory_from_handle(handle);
  office_publication_directory *copy =
      (office_publication_directory *)malloc(sizeof(*copy));
  if (copy == NULL) {
    return 0;
  }
  copy->handle = INVALID_HANDLE_VALUE;
  copy->error = ERROR_SUCCESS;
  if (source == NULL || source->handle == INVALID_HANDLE_VALUE) {
    copy->error = ERROR_INVALID_HANDLE;
  } else {
    office_duplicate_handle(source->handle, &copy->handle, &copy->error);
  }
  return (uint64_t)(uintptr_t)copy;
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

MOONBIT_FFI_EXPORT HANDLE
bobzhang_office_transaction_directory_sync_fd(uint64_t handle) {
  (void)handle;
  return INVALID_HANDLE_VALUE;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_fd_valid(HANDLE file) {
  return file != INVALID_HANDLE_VALUE;
}

MOONBIT_FFI_EXPORT HANDLE
bobzhang_office_transaction_directory_open_read(uint64_t handle,
                                                 uint8_t *leaf) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  wchar_t *wide;
  HANDLE file;
  if (directory == NULL || directory->handle == INVALID_HANDLE_VALUE) {
    if (directory != NULL) {
      directory->error = ERROR_INVALID_HANDLE;
    }
    return INVALID_HANDLE_VALUE;
  }
  wide = office_utf8_to_wide(leaf, &directory->error);
  if (wide == NULL) {
    return INVALID_HANDLE_VALUE;
  }
  file = office_open_relative(
      directory->handle, wide, GENERIC_READ | FILE_READ_ATTRIBUTES | SYNCHRONIZE,
      FILE_OPEN, FILE_ATTRIBUTE_NORMAL, FILE_NON_DIRECTORY_FILE,
      &directory->error);
  free(wide);
  return file;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_read_start(uint64_t handle, uint8_t *leaf,
                                        int32_t max_bytes) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  office_read_task *task = (office_read_task *)calloc(1, sizeof(*task));
  wchar_t *wide;
  LARGE_INTEGER size;
  if (task == NULL) {
    return 0;
  }
  task->thread = NULL;
  task->file = INVALID_HANDLE_VALUE;
  task->data = NULL;
  task->length = 0;
  task->done = 0;
  task->error = ERROR_SUCCESS;
  if (directory == NULL || directory->handle == INVALID_HANDLE_VALUE ||
      max_bytes < 0) {
    task->error = ERROR_INVALID_PARAMETER;
    task->done = 1;
    return (uint64_t)(uintptr_t)task;
  }
  wide = office_utf8_to_wide(leaf, &task->error);
  if (wide == NULL) {
    task->done = 1;
    return (uint64_t)(uintptr_t)task;
  }
  task->file = office_open_relative(
      directory->handle, wide, GENERIC_READ | FILE_READ_ATTRIBUTES | SYNCHRONIZE,
      FILE_OPEN, FILE_ATTRIBUTE_NORMAL, FILE_NON_DIRECTORY_FILE, &task->error);
  free(wide);
  if (task->file == INVALID_HANDLE_VALUE ||
      !GetFileSizeEx(task->file, &size)) {
    if (task->file != INVALID_HANDLE_VALUE) {
      task->error = GetLastError();
      CloseHandle(task->file);
      task->file = INVALID_HANDLE_VALUE;
    }
    task->done = 1;
    return (uint64_t)(uintptr_t)task;
  }
  if (size.QuadPart < 0 || size.QuadPart > max_bytes) {
    task->error = ERROR_FILE_TOO_LARGE;
    CloseHandle(task->file);
    task->file = INVALID_HANDLE_VALUE;
    task->length = size.QuadPart > INT32_MAX ? INT32_MAX : (int32_t)size.QuadPart;
    task->done = 1;
    return (uint64_t)(uintptr_t)task;
  }
  task->length = (int32_t)size.QuadPart;
  if (task->length > 0) {
    task->data = (uint8_t *)malloc((size_t)task->length);
    if (task->data == NULL) {
      task->error = ERROR_NOT_ENOUGH_MEMORY;
      CloseHandle(task->file);
      task->file = INVALID_HANDLE_VALUE;
      task->done = 1;
      return (uint64_t)(uintptr_t)task;
    }
  }
  task->thread = CreateThread(NULL, 0, office_read_worker, task, 0, NULL);
  if (task->thread == NULL) {
    task->error = GetLastError();
    CloseHandle(task->file);
    task->file = INVALID_HANDLE_VALUE;
    task->done = 1;
  }
  return (uint64_t)(uintptr_t)task;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_read_poll(uint64_t handle) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  if (task == NULL) {
    return -1;
  }
  if (InterlockedCompareExchange(&task->done, 0, 0) == 0) {
    return 0;
  }
  return task->error == ERROR_SUCCESS ? 1 : -1;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_read_error(uint64_t handle) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  return task == NULL ? (int32_t)ERROR_NOT_ENOUGH_MEMORY
                      : (int32_t)task->error;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_read_length(uint64_t handle) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  return task == NULL ? -1 : task->length;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_read_copy(uint64_t handle, uint8_t *destination,
                                      int32_t offset, int32_t length) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  if (task == NULL || destination == NULL || offset < 0 || length < 0 ||
      offset > task->length || length > task->length - offset ||
      task->error != ERROR_SUCCESS || task->done == 0) {
    return 0;
  }
  if (length > 0) {
    memcpy(destination + offset, task->data + offset, (size_t)length);
  }
  return 1;
}

MOONBIT_FFI_EXPORT void
bobzhang_office_transaction_read_close(uint64_t handle) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  if (task == NULL) {
    return;
  }
  if (task->thread != NULL) {
    WaitForSingleObject(task->thread, INFINITE);
    CloseHandle(task->thread);
  }
  if (task->file != INVALID_HANDLE_VALUE) {
    CloseHandle(task->file);
  }
  free(task->data);
  free(task);
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_random_nonce(void) {
  uint64_t nonce = 0;
  DWORD error = ERROR_SUCCESS;
  if (!office_random_bytes((uint8_t *)&nonce, (ULONG)sizeof(nonce), &error)) {
    return 0;
  }
  return nonce;
}

MOONBIT_FFI_EXPORT int64_t
bobzhang_office_transaction_file_size(HANDLE file) {
  LARGE_INTEGER size;
  if (!GetFileSizeEx(file, &size)) {
    return -1;
  }
  return size.QuadPart;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_directory_entry_kind(
    uint64_t handle, uint8_t *leaf) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  wchar_t *wide;
  HANDLE file;
  BY_HANDLE_FILE_INFORMATION info;
  if (directory == NULL || directory->handle == INVALID_HANDLE_VALUE) {
    return -1;
  }
  wide = office_utf8_to_wide(leaf, &directory->error);
  if (wide == NULL) {
    return -1;
  }
  file = office_open_relative(directory->handle, wide,
                              FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_OPEN,
                              FILE_ATTRIBUTE_NORMAL, 0, &directory->error);
  free(wide);
  if (file == INVALID_HANDLE_VALUE) {
    if (directory->error == ERROR_FILE_NOT_FOUND ||
        directory->error == ERROR_PATH_NOT_FOUND) {
      return 0;
    }
    return -1;
  }
  if (!office_file_identity(file, &info, &directory->error)) {
    CloseHandle(file);
    return -1;
  }
  CloseHandle(file);
  return (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? 2 : 1;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_entries_same(
    uint64_t left_handle, uint8_t *left_leaf, uint64_t right_handle,
    uint8_t *right_leaf) {
  office_publication_directory *left = office_directory_from_handle(left_handle);
  office_publication_directory *right =
      office_directory_from_handle(right_handle);
  wchar_t *left_wide;
  wchar_t *right_wide;
  HANDLE left_file;
  HANDLE right_file;
  int same;
  if (left == NULL || right == NULL || left->handle == INVALID_HANDLE_VALUE ||
      right->handle == INVALID_HANDLE_VALUE) {
    return -1;
  }
  left_wide = office_utf8_to_wide(left_leaf, &left->error);
  right_wide = office_utf8_to_wide(right_leaf, &right->error);
  if (left_wide == NULL || right_wide == NULL) {
    free(left_wide);
    free(right_wide);
    return -1;
  }
  left_file = office_open_relative(left->handle, left_wide,
                                   FILE_READ_ATTRIBUTES | SYNCHRONIZE,
                                   FILE_OPEN, FILE_ATTRIBUTE_NORMAL, 0,
                                   &left->error);
  right_file = office_open_relative(right->handle, right_wide,
                                    FILE_READ_ATTRIBUTES | SYNCHRONIZE,
                                    FILE_OPEN, FILE_ATTRIBUTE_NORMAL, 0,
                                    &right->error);
  free(left_wide);
  free(right_wide);
  if (left_file == INVALID_HANDLE_VALUE || right_file == INVALID_HANDLE_VALUE) {
    if (left_file != INVALID_HANDLE_VALUE) {
      CloseHandle(left_file);
    }
    if (right_file != INVALID_HANDLE_VALUE) {
      CloseHandle(right_file);
    }
    return -1;
  }
  same = office_same_file(left_file, right_file, &left->error);
  CloseHandle(left_file);
  CloseHandle(right_file);
  return same ? 1 : 0;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_temp_create(uint64_t directory_handle,
                                         int32_t permission) {
  office_publication_directory *directory =
      office_directory_from_handle(directory_handle);
  office_publication_temp *temp =
      (office_publication_temp *)malloc(sizeof(*temp));
  (void)permission;
  if (temp == NULL) {
    return 0;
  }
  temp->file = INVALID_HANDLE_VALUE;
  temp->directory = INVALID_HANDLE_VALUE;
  temp->leaf = NULL;
  temp->error = ERROR_SUCCESS;
  temp->published = 0;
  temp->cleaned = 0;
  if (directory == NULL || directory->handle == INVALID_HANDLE_VALUE) {
    temp->error = ERROR_INVALID_HANDLE;
    return (uint64_t)(uintptr_t)temp;
  }
  /* Duplicate first so no failure after creation can orphan a named file. */
  if (!office_duplicate_handle(directory->handle, &temp->directory,
                               &temp->error)) {
    return (uint64_t)(uintptr_t)temp;
  }
  temp->leaf = office_random_leaf(&temp->error);
  if (temp->leaf == NULL) {
    return (uint64_t)(uintptr_t)temp;
  }
  temp->file = office_open_relative(
      temp->directory, temp->leaf,
      GENERIC_WRITE | DELETE | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_CREATE,
      FILE_ATTRIBUTE_TEMPORARY, FILE_NON_DIRECTORY_FILE, &temp->error);
  return (uint64_t)(uintptr_t)temp;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_temp_write_start(uint64_t handle,
                                              moonbit_bytes_t bytes) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  office_write_task *task = (office_write_task *)calloc(1, sizeof(*task));
  if (task == NULL) {
    moonbit_decref(bytes);
    return 0;
  }
  task->thread = NULL;
  task->file = INVALID_HANDLE_VALUE;
  task->bytes = bytes;
  task->length = Moonbit_array_length(bytes);
  task->done = 0;
  task->error = ERROR_SUCCESS;
  if (temp == NULL || temp->file == INVALID_HANDLE_VALUE ||
      !office_duplicate_handle(temp->file, &task->file, &task->error)) {
    task->done = 1;
    return (uint64_t)(uintptr_t)task;
  }
  task->thread = CreateThread(NULL, 0, office_write_worker, task, 0, NULL);
  if (task->thread == NULL) {
    task->error = GetLastError();
    CloseHandle(task->file);
    task->file = INVALID_HANDLE_VALUE;
    task->done = 1;
  }
  return (uint64_t)(uintptr_t)task;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_write_poll(uint64_t handle) {
  office_write_task *task = (office_write_task *)(uintptr_t)handle;
  if (task == NULL) {
    return -1;
  }
  if (InterlockedCompareExchange(&task->done, 0, 0) == 0) {
    return 0;
  }
  return task->error == ERROR_SUCCESS ? 1 : -1;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_write_error(uint64_t handle) {
  office_write_task *task = (office_write_task *)(uintptr_t)handle;
  return task == NULL ? (int32_t)ERROR_NOT_ENOUGH_MEMORY
                      : (int32_t)task->error;
}

MOONBIT_FFI_EXPORT void
bobzhang_office_transaction_write_close(uint64_t handle) {
  office_write_task *task = (office_write_task *)(uintptr_t)handle;
  if (task == NULL) {
    return;
  }
  if (task->thread != NULL) {
    WaitForSingleObject(task->thread, INFINITE);
    CloseHandle(task->thread);
  }
  if (task->file != INVALID_HANDLE_VALUE) {
    CloseHandle(task->file);
  }
  moonbit_decref(task->bytes);
  free(task);
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_ok(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  return temp != NULL && temp->file != INVALID_HANDLE_VALUE &&
         temp->directory != INVALID_HANDLE_VALUE && temp->leaf != NULL;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_error(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  return temp == NULL ? (int32_t)ERROR_NOT_ENOUGH_MEMORY
                      : (int32_t)temp->error;
}

MOONBIT_FFI_EXPORT HANDLE
bobzhang_office_transaction_temp_io_fd(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  HANDLE duplicate = INVALID_HANDLE_VALUE;
  if (temp == NULL || temp->file == INVALID_HANDLE_VALUE) {
    return INVALID_HANDLE_VALUE;
  }
  office_duplicate_handle(temp->file, &duplicate, &temp->error);
  return duplicate;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_temp_sync_start(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  if (temp == NULL || temp->file == INVALID_HANDLE_VALUE) {
    return 0;
  }
  return office_sync_start(temp->file);
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_directory_sync_start(uint64_t handle) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  if (directory == NULL || directory->handle == INVALID_HANDLE_VALUE) {
    return 0;
  }
  return office_sync_start(directory->handle);
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_sync_poll(uint64_t handle) {
  office_sync_task *task = (office_sync_task *)(uintptr_t)handle;
  if (task == NULL) {
    return -1;
  }
  if (InterlockedCompareExchange(&task->done, 0, 0) == 0) {
    return 0;
  }
  return task->error == ERROR_SUCCESS ? 1 : -1;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_sync_error(uint64_t handle) {
  office_sync_task *task = (office_sync_task *)(uintptr_t)handle;
  return task == NULL ? (int32_t)ERROR_NOT_ENOUGH_MEMORY
                      : (int32_t)task->error;
}

MOONBIT_FFI_EXPORT void
bobzhang_office_transaction_sync_close(uint64_t handle) {
  office_sync_task *task = (office_sync_task *)(uintptr_t)handle;
  if (task == NULL) {
    return;
  }
  if (task->thread != NULL) {
    WaitForSingleObject(task->thread, INFINITE);
    CloseHandle(task->thread);
  }
  if (task->target != INVALID_HANDLE_VALUE) {
    CloseHandle(task->target);
  }
  free(task);
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_publish(
    uint64_t handle, uint8_t *destination_leaf, int32_t replace) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  wchar_t *wide;
  if (temp == NULL || temp->file == INVALID_HANDLE_VALUE ||
      temp->directory == INVALID_HANDLE_VALUE || temp->leaf == NULL) {
    if (temp != NULL) {
      temp->error = ERROR_INVALID_HANDLE;
    }
    return 0;
  }
  if (!office_temp_path_is_owned(temp)) {
    return 0;
  }
  wide = office_utf8_to_wide(destination_leaf, &temp->error);
  if (wide == NULL) {
    return 0;
  }
  if (!office_rename_open_file(temp->file, wide, replace, &temp->error)) {
    free(wide);
    return 0;
  }
  free(wide);
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
  if (temp->file == INVALID_HANDLE_VALUE || temp->directory == INVALID_HANDLE_VALUE ||
      temp->leaf == NULL) {
    temp->error = ERROR_INVALID_HANDLE;
    return 0;
  }
  if (!office_temp_path_is_owned(temp)) {
    /* Remove only the still-open file we created; never delete a substitute. */
    (void)office_delete_open_file(temp->file, &temp->error);
    return 0;
  }
  if (!office_delete_open_file(temp->file, &temp->error)) {
    return 0;
  }
  temp->cleaned = 1;
  return 1;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_substitute(
    uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  wchar_t *moved;
  HANDLE foreign;
  static const uint8_t marker[] = "foreign";
  DWORD written;
  if (temp == NULL || !office_temp_path_is_owned(temp)) {
    return 0;
  }
  moved = office_random_leaf(&temp->error);
  if (moved == NULL ||
      !office_rename_open_file(temp->file, moved, 0, &temp->error)) {
    free(moved);
    return 0;
  }
  free(moved);
  foreign = office_open_relative(
      temp->directory, temp->leaf, GENERIC_WRITE | DELETE | SYNCHRONIZE,
      FILE_CREATE, FILE_ATTRIBUTE_TEMPORARY, FILE_NON_DIRECTORY_FILE,
      &temp->error);
  if (foreign == INVALID_HANDLE_VALUE) {
    return 0;
  }
  if (!WriteFile(foreign, marker, (DWORD)(sizeof(marker) - 1), &written, NULL)) {
    temp->error = GetLastError();
    CloseHandle(foreign);
    return 0;
  }
  CloseHandle(foreign);
  return 1;
}

MOONBIT_FFI_EXPORT void bobzhang_office_transaction_temp_close(
    uint64_t handle) {
  office_temp_release(office_temp_from_handle(handle));
}

MOONBIT_FFI_EXPORT void bobzhang_office_transaction_directory_close(
    uint64_t handle) {
  office_directory_release(office_directory_from_handle(handle));
}

#else

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdatomic.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifdef __linux__
#include <sys/random.h>
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
  int source_link_remaining;
  int cleaned;
} office_publication_temp;

typedef struct {
  pthread_t thread;
  int target;
  atomic_int done;
  int error;
  int started;
} office_sync_task;

typedef struct {
  pthread_t thread;
  int file;
  uint8_t *data;
  int32_t length;
  atomic_int done;
  int error;
  int started;
} office_read_task;

typedef struct {
  pthread_t thread;
  int file;
  moonbit_bytes_t bytes;
  int32_t length;
  atomic_int done;
  int error;
  int started;
} office_write_task;

static int office_duplicate_fd(int fd);

static void *office_read_worker(void *context) {
  office_read_task *task = (office_read_task *)context;
  int32_t offset = 0;
  while (offset < task->length) {
    ssize_t count = read(task->file, task->data + offset,
                         (size_t)(task->length - offset));
    if (count > 0) {
      offset += (int32_t)count;
    } else if (count < 0 && errno == EINTR) {
      continue;
    } else {
      task->error = count == 0 ? EIO : errno;
      break;
    }
  }
  close(task->file);
  task->file = -1;
  atomic_store_explicit(&task->done, 1, memory_order_release);
  return NULL;
}

static void *office_write_worker(void *context) {
  office_write_task *task = (office_write_task *)context;
  int32_t offset = 0;
  while (offset < task->length) {
    ssize_t count = write(task->file, task->bytes + offset,
                          (size_t)(task->length - offset));
    if (count > 0) {
      offset += (int32_t)count;
    } else if (count < 0 && errno == EINTR) {
      continue;
    } else {
      task->error = count == 0 ? EIO : errno;
      break;
    }
  }
  close(task->file);
  task->file = -1;
  atomic_store_explicit(&task->done, 1, memory_order_release);
  return NULL;
}

static void *office_sync_worker(void *context) {
  office_sync_task *task = (office_sync_task *)context;
  int result;
  do {
    result = fsync(task->target);
  } while (result < 0 && errno == EINTR);
  if (result < 0) {
    task->error = errno;
  }
  close(task->target);
  task->target = -1;
  atomic_store_explicit(&task->done, 1, memory_order_release);
  return NULL;
}

static uint64_t office_sync_start(int source) {
  office_sync_task *task = (office_sync_task *)calloc(1, sizeof(*task));
  if (task == NULL) {
    return 0;
  }
  task->target = office_duplicate_fd(source);
  atomic_init(&task->done, 0);
  task->error = 0;
  task->started = 0;
  if (task->target < 0) {
    task->error = errno;
    atomic_store_explicit(&task->done, 1, memory_order_release);
    return (uint64_t)(uintptr_t)task;
  }
  if (pthread_create(&task->thread, NULL, office_sync_worker, task) != 0) {
    task->error = errno == 0 ? EIO : errno;
    close(task->target);
    task->target = -1;
    atomic_store_explicit(&task->done, 1, memory_order_release);
    return (uint64_t)(uintptr_t)task;
  }
  task->started = 1;
  return (uint64_t)(uintptr_t)task;
}

static int office_duplicate_fd(int fd) {
#ifdef F_DUPFD_CLOEXEC
  return fcntl(fd, F_DUPFD_CLOEXEC, 0);
#else
  return dup(fd);
#endif
}

static int office_random_bytes(uint8_t *bytes, size_t length) {
#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__)
  arc4random_buf(bytes, length);
  return 0;
#else
  size_t offset = 0;
#ifdef __linux__
  while (offset < length) {
    ssize_t count = getrandom(bytes + offset, length - offset, 0);
    if (count > 0) {
      offset += (size_t)count;
      continue;
    }
    if (count < 0 && errno == EINTR) {
      continue;
    }
    break;
  }
  if (offset == length) {
    return 0;
  }
#endif
  {
    int fd = open("/dev/urandom", O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
      return -1;
    }
    while (offset < length) {
      ssize_t count = read(fd, bytes + offset, length - offset);
      if (count > 0) {
        offset += (size_t)count;
      } else if (count < 0 && errno == EINTR) {
        continue;
      } else {
        int saved = count == 0 ? EIO : errno;
        close(fd);
        errno = saved;
        return -1;
      }
    }
    close(fd);
    return 0;
  }
#endif
}

static char *office_random_leaf(void) {
  static const char hex[] = "0123456789abcdef";
  static const char prefix[] = ".office-tmp-";
  uint8_t random[16];
  size_t prefix_length = sizeof(prefix) - 1;
  char *leaf;
  size_t i;
  if (office_random_bytes(random, sizeof(random)) < 0) {
    return NULL;
  }
  leaf = (char *)malloc(prefix_length + 32 + 1);
  if (leaf == NULL) {
    errno = ENOMEM;
    return NULL;
  }
  memcpy(leaf, prefix, prefix_length);
  for (i = 0; i < sizeof(random); ++i) {
    leaf[prefix_length + i * 2] = hex[random[i] >> 4];
    leaf[prefix_length + i * 2 + 1] = hex[random[i] & 0x0f];
  }
  leaf[prefix_length + 32] = '\0';
  return leaf;
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
  }
  free(directory);
}

static void office_temp_release(office_publication_temp *temp) {
  if (temp == NULL) {
    return;
  }
  if (temp->file_fd >= 0) {
    close(temp->file_fd);
  }
  if (temp->directory_fd >= 0) {
    close(temp->directory_fd);
  }
  free(temp->leaf);
  free(temp);
}

static int office_same_stat(const struct stat *left, const struct stat *right) {
  return left->st_dev == right->st_dev && left->st_ino == right->st_ino;
}

static int office_temp_path_is_owned(office_publication_temp *temp) {
  struct stat opened;
  struct stat named;
  if (fstat(temp->file_fd, &opened) < 0) {
    temp->error = errno;
    return 0;
  }
  if (fstatat(temp->directory_fd, temp->leaf, &named, AT_SYMLINK_NOFOLLOW) < 0) {
    temp->error = errno;
    return 0;
  }
  if (!office_same_stat(&opened, &named)) {
#ifdef ESTALE
    temp->error = ESTALE;
#else
    temp->error = EIO;
#endif
    return 0;
  }
  return 1;
}

static int office_publish_no_replace(int directory_fd, const char *source,
                                     const char *destination,
                                     int *source_link_remaining) {
#if defined(__APPLE__)
  return renameatx_np(directory_fd, source, directory_fd, destination,
                      RENAME_EXCL);
#elif defined(__linux__) && defined(SYS_renameat2)
  {
    int result = (int)syscall(SYS_renameat2, directory_fd, source, directory_fd,
                              destination, RENAME_NOREPLACE);
    if (result == 0 || errno != ENOSYS) {
      return result;
    }
  }
#endif
  /* Portable atomic no-replace fallback. The destination link is the commit
     point; remove the private staging link immediately afterward. */
  if (linkat(directory_fd, source, directory_fd, destination, 0) < 0) {
    return -1;
  }
  if (unlinkat(directory_fd, source, 0) == 0) {
    return 0;
  }
  {
    int unlink_error = errno;
    if (unlinkat(directory_fd, destination, 0) == 0) {
      errno = unlink_error;
      return -1;
    }
    *source_link_remaining = 1;
    errno = unlink_error;
    return 1;
  }
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_directory_open(uint8_t *path) {
  office_publication_directory *directory =
      (office_publication_directory *)malloc(sizeof(*directory));
  if (directory == NULL) {
    return 0;
  }
  directory->fd = open((const char *)path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  directory->error = directory->fd < 0 ? errno : 0;
  return (uint64_t)(uintptr_t)directory;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_directory_duplicate(uint64_t handle) {
  office_publication_directory *source = office_directory_from_handle(handle);
  office_publication_directory *copy =
      (office_publication_directory *)malloc(sizeof(*copy));
  if (copy == NULL) {
    return 0;
  }
  copy->fd = -1;
  copy->error = 0;
  if (source == NULL || source->fd < 0) {
    copy->error = EBADF;
  } else {
    copy->fd = office_duplicate_fd(source->fd);
    if (copy->fd < 0) {
      copy->error = errno;
    }
  }
  return (uint64_t)(uintptr_t)copy;
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

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_directory_sync_fd(uint64_t handle) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  int duplicate;
  if (directory == NULL || directory->fd < 0) {
    return -1;
  }
  duplicate = office_duplicate_fd(directory->fd);
  if (duplicate < 0) {
    directory->error = errno;
  }
  return duplicate;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_fd_valid(int32_t file) {
  return file >= 0;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_directory_open_read(uint64_t handle,
                                                 uint8_t *leaf) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  int file;
  if (directory == NULL || directory->fd < 0) {
    if (directory != NULL) {
      directory->error = EBADF;
    }
    return -1;
  }
  file = openat(directory->fd, (const char *)leaf, O_RDONLY | O_CLOEXEC);
  if (file < 0) {
    directory->error = errno;
  }
  return file;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_read_start(uint64_t handle, uint8_t *leaf,
                                        int32_t max_bytes) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  office_read_task *task = (office_read_task *)calloc(1, sizeof(*task));
  struct stat info;
  if (task == NULL) {
    return 0;
  }
  task->file = -1;
  task->data = NULL;
  task->length = 0;
  atomic_init(&task->done, 0);
  task->error = 0;
  task->started = 0;
  if (directory == NULL || directory->fd < 0 || max_bytes < 0) {
    task->error = EINVAL;
    atomic_store_explicit(&task->done, 1, memory_order_release);
    return (uint64_t)(uintptr_t)task;
  }
  task->file = openat(directory->fd, (const char *)leaf, O_RDONLY | O_CLOEXEC);
  if (task->file < 0 || fstat(task->file, &info) < 0) {
    task->error = errno;
    if (task->file >= 0) {
      close(task->file);
      task->file = -1;
    }
    atomic_store_explicit(&task->done, 1, memory_order_release);
    return (uint64_t)(uintptr_t)task;
  }
  if (info.st_size < 0 || info.st_size > max_bytes) {
    task->error = EFBIG;
    task->length = info.st_size > INT32_MAX ? INT32_MAX : (int32_t)info.st_size;
    close(task->file);
    task->file = -1;
    atomic_store_explicit(&task->done, 1, memory_order_release);
    return (uint64_t)(uintptr_t)task;
  }
  task->length = (int32_t)info.st_size;
  if (task->length > 0) {
    task->data = (uint8_t *)malloc((size_t)task->length);
    if (task->data == NULL) {
      task->error = ENOMEM;
      close(task->file);
      task->file = -1;
      atomic_store_explicit(&task->done, 1, memory_order_release);
      return (uint64_t)(uintptr_t)task;
    }
  }
  {
    int create_error = pthread_create(&task->thread, NULL, office_read_worker,
                                      task);
    if (create_error != 0) {
      task->error = create_error;
      close(task->file);
      task->file = -1;
      atomic_store_explicit(&task->done, 1, memory_order_release);
      return (uint64_t)(uintptr_t)task;
    }
  }
  task->started = 1;
  return (uint64_t)(uintptr_t)task;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_read_poll(uint64_t handle) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  if (task == NULL) {
    return -1;
  }
  if (atomic_load_explicit(&task->done, memory_order_acquire) == 0) {
    return 0;
  }
  return task->error == 0 ? 1 : -1;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_read_error(uint64_t handle) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  return task == NULL ? ENOMEM : task->error;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_read_length(uint64_t handle) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  return task == NULL ? -1 : task->length;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_read_copy(uint64_t handle, uint8_t *destination,
                                      int32_t offset, int32_t length) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  if (task == NULL || destination == NULL || offset < 0 || length < 0 ||
      offset > task->length || length > task->length - offset ||
      task->error != 0 ||
      atomic_load_explicit(&task->done, memory_order_acquire) == 0) {
    return 0;
  }
  if (length > 0) {
    memcpy(destination + offset, task->data + offset, (size_t)length);
  }
  return 1;
}

MOONBIT_FFI_EXPORT void
bobzhang_office_transaction_read_close(uint64_t handle) {
  office_read_task *task = (office_read_task *)(uintptr_t)handle;
  if (task == NULL) {
    return;
  }
  if (task->started) {
    pthread_join(task->thread, NULL);
  }
  if (task->file >= 0) {
    close(task->file);
  }
  free(task->data);
  free(task);
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_random_nonce(void) {
  uint64_t nonce = 0;
  if (office_random_bytes((uint8_t *)&nonce, sizeof(nonce)) < 0) {
    return 0;
  }
  return nonce;
}

MOONBIT_FFI_EXPORT int64_t
bobzhang_office_transaction_file_size(int32_t file) {
  struct stat info;
  if (fstat(file, &info) < 0) {
    return -1;
  }
  return (int64_t)info.st_size;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_directory_entry_kind(
    uint64_t handle, uint8_t *leaf) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  struct stat info;
  if (directory == NULL || directory->fd < 0) {
    return -1;
  }
  if (fstatat(directory->fd, (const char *)leaf, &info, 0) < 0) {
    directory->error = errno;
    return errno == ENOENT ? 0 : -1;
  }
  if (S_ISDIR(info.st_mode)) {
    return 2;
  }
  return S_ISREG(info.st_mode) ? 1 : 3;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_entries_same(
    uint64_t left_handle, uint8_t *left_leaf, uint64_t right_handle,
    uint8_t *right_leaf) {
  office_publication_directory *left = office_directory_from_handle(left_handle);
  office_publication_directory *right =
      office_directory_from_handle(right_handle);
  struct stat left_info;
  struct stat right_info;
  if (left == NULL || right == NULL || left->fd < 0 || right->fd < 0) {
    return -1;
  }
  if (fstatat(left->fd, (const char *)left_leaf, &left_info, 0) < 0) {
    left->error = errno;
    return -1;
  }
  if (fstatat(right->fd, (const char *)right_leaf, &right_info, 0) < 0) {
    right->error = errno;
    return -1;
  }
  return office_same_stat(&left_info, &right_info) ? 1 : 0;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_temp_create(uint64_t directory_handle,
                                         int32_t permission) {
  office_publication_directory *directory =
      office_directory_from_handle(directory_handle);
  office_publication_temp *temp =
      (office_publication_temp *)malloc(sizeof(*temp));
  if (temp == NULL) {
    return 0;
  }
  temp->file_fd = -1;
  temp->directory_fd = -1;
  temp->leaf = NULL;
  temp->error = 0;
  temp->published = 0;
  temp->source_link_remaining = 0;
  temp->cleaned = 0;
  if (directory == NULL || directory->fd < 0) {
    temp->error = EBADF;
    return (uint64_t)(uintptr_t)temp;
  }
  /* Duplicate first so no failure after creation can orphan a named file. */
  temp->directory_fd = office_duplicate_fd(directory->fd);
  if (temp->directory_fd < 0) {
    temp->error = errno;
    return (uint64_t)(uintptr_t)temp;
  }
  temp->leaf = office_random_leaf();
  if (temp->leaf == NULL) {
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
  /* Enforce the requested mode exactly; umask must not silently weaken the
     contract into a different mode. */
  if (fchmod(temp->file_fd, (mode_t)permission) < 0) {
    temp->error = errno;
    (void)unlinkat(temp->directory_fd, temp->leaf, 0);
    close(temp->file_fd);
    temp->file_fd = -1;
  }
  return (uint64_t)(uintptr_t)temp;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_temp_write_start(uint64_t handle,
                                              moonbit_bytes_t bytes) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  office_write_task *task = (office_write_task *)calloc(1, sizeof(*task));
  int create_error;
  if (task == NULL) {
    moonbit_decref(bytes);
    return 0;
  }
  task->file = -1;
  task->bytes = bytes;
  task->length = Moonbit_array_length(bytes);
  atomic_init(&task->done, 0);
  task->error = 0;
  task->started = 0;
  if (temp == NULL || temp->file_fd < 0) {
    task->error = EBADF;
    atomic_store_explicit(&task->done, 1, memory_order_release);
    return (uint64_t)(uintptr_t)task;
  }
  task->file = office_duplicate_fd(temp->file_fd);
  if (task->file < 0) {
    task->error = errno;
    atomic_store_explicit(&task->done, 1, memory_order_release);
    return (uint64_t)(uintptr_t)task;
  }
  create_error = pthread_create(&task->thread, NULL, office_write_worker, task);
  if (create_error != 0) {
    task->error = create_error;
    close(task->file);
    task->file = -1;
    atomic_store_explicit(&task->done, 1, memory_order_release);
    return (uint64_t)(uintptr_t)task;
  }
  task->started = 1;
  return (uint64_t)(uintptr_t)task;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_write_poll(uint64_t handle) {
  office_write_task *task = (office_write_task *)(uintptr_t)handle;
  if (task == NULL) {
    return -1;
  }
  if (atomic_load_explicit(&task->done, memory_order_acquire) == 0) {
    return 0;
  }
  return task->error == 0 ? 1 : -1;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_write_error(uint64_t handle) {
  office_write_task *task = (office_write_task *)(uintptr_t)handle;
  return task == NULL ? ENOMEM : task->error;
}

MOONBIT_FFI_EXPORT void
bobzhang_office_transaction_write_close(uint64_t handle) {
  office_write_task *task = (office_write_task *)(uintptr_t)handle;
  if (task == NULL) {
    return;
  }
  if (task->started) {
    pthread_join(task->thread, NULL);
  }
  if (task->file >= 0) {
    close(task->file);
  }
  moonbit_decref(task->bytes);
  free(task);
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_ok(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  return temp != NULL && temp->file_fd >= 0 && temp->directory_fd >= 0 &&
         temp->leaf != NULL;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_error(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  return temp == NULL ? ENOMEM : temp->error;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_temp_io_fd(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  int duplicate;
  if (temp == NULL || temp->file_fd < 0) {
    return -1;
  }
  duplicate = office_duplicate_fd(temp->file_fd);
  if (duplicate < 0) {
    temp->error = errno;
  }
  return duplicate;
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_temp_sync_start(uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  if (temp == NULL || temp->file_fd < 0) {
    return 0;
  }
  return office_sync_start(temp->file_fd);
}

MOONBIT_FFI_EXPORT uint64_t
bobzhang_office_transaction_directory_sync_start(uint64_t handle) {
  office_publication_directory *directory = office_directory_from_handle(handle);
  if (directory == NULL || directory->fd < 0) {
    return 0;
  }
  return office_sync_start(directory->fd);
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_sync_poll(uint64_t handle) {
  office_sync_task *task = (office_sync_task *)(uintptr_t)handle;
  if (task == NULL) {
    return -1;
  }
  if (atomic_load_explicit(&task->done, memory_order_acquire) == 0) {
    return 0;
  }
  return task->error == 0 ? 1 : -1;
}

MOONBIT_FFI_EXPORT int32_t
bobzhang_office_transaction_sync_error(uint64_t handle) {
  office_sync_task *task = (office_sync_task *)(uintptr_t)handle;
  return task == NULL ? ENOMEM : task->error;
}

MOONBIT_FFI_EXPORT void
bobzhang_office_transaction_sync_close(uint64_t handle) {
  office_sync_task *task = (office_sync_task *)(uintptr_t)handle;
  if (task == NULL) {
    return;
  }
  if (task->started) {
    pthread_join(task->thread, NULL);
  }
  if (task->target >= 0) {
    close(task->target);
  }
  free(task);
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_publish(
    uint64_t handle, uint8_t *destination_leaf, int32_t replace) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  int result;
  if (temp == NULL || temp->file_fd < 0 || temp->directory_fd < 0 ||
      temp->leaf == NULL) {
    if (temp != NULL) {
      temp->error = EBADF;
    }
    return 0;
  }
  if (!office_temp_path_is_owned(temp)) {
    return 0;
  }
  if (replace) {
    result = renameat(temp->directory_fd, temp->leaf, temp->directory_fd,
                      (const char *)destination_leaf);
  } else {
    result = office_publish_no_replace(temp->directory_fd, temp->leaf,
                                       (const char *)destination_leaf,
                                       &temp->source_link_remaining);
  }
  if (result < 0) {
    temp->error = errno;
    return 0;
  }
  temp->published = 1;
  return temp->source_link_remaining ? 2 : 1;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_cleanup(
    uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  if (temp == NULL) {
    return 0;
  }
  if (temp->cleaned || (temp->published && !temp->source_link_remaining)) {
    return 1;
  }
  if (temp->file_fd < 0 || temp->directory_fd < 0 || temp->leaf == NULL) {
    temp->error = EBADF;
    return 0;
  }
  if (!office_temp_path_is_owned(temp)) {
    return 0;
  }
  if (unlinkat(temp->directory_fd, temp->leaf, 0) < 0) {
    temp->error = errno;
    return 0;
  }
  temp->source_link_remaining = 0;
  temp->cleaned = 1;
  return 1;
}

MOONBIT_FFI_EXPORT int32_t bobzhang_office_transaction_temp_substitute(
    uint64_t handle) {
  office_publication_temp *temp = office_temp_from_handle(handle);
  int foreign;
  static const char marker[] = "foreign";
  if (temp == NULL || !office_temp_path_is_owned(temp)) {
    return 0;
  }
  if (unlinkat(temp->directory_fd, temp->leaf, 0) < 0) {
    temp->error = errno;
    return 0;
  }
  foreign = openat(temp->directory_fd, temp->leaf,
                   O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
  if (foreign < 0) {
    temp->error = errno;
    return 0;
  }
  if (write(foreign, marker, sizeof(marker) - 1) !=
      (ssize_t)(sizeof(marker) - 1)) {
    temp->error = errno == 0 ? EIO : errno;
    close(foreign);
    return 0;
  }
  close(foreign);
  return 1;
}

MOONBIT_FFI_EXPORT void bobzhang_office_transaction_temp_close(
    uint64_t handle) {
  office_temp_release(office_temp_from_handle(handle));
}

MOONBIT_FFI_EXPORT void bobzhang_office_transaction_directory_close(
    uint64_t handle) {
  office_directory_release(office_directory_from_handle(handle));
}

#endif
