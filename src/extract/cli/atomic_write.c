#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "moonbit.h"

MOONBIT_FFI_EXPORT int moonstyle_atomic_rename(moonbit_bytes_t from,
                                             moonbit_bytes_t to) {
  return rename((const char *)from, (const char *)to);
}

MOONBIT_FFI_EXPORT int moonstyle_atomic_mkdirs(moonbit_bytes_t input) {
  const char *path = (const char *)input;
  size_t length = strlen(path);
  char *copy = malloc(length + 1);
  if (copy == NULL) return -1;
  memcpy(copy, path, length + 1);
  for (size_t index = 1; index < length; index++) {
    if (copy[index] != '/') continue;
    copy[index] = '\0';
    if (mkdir(copy, 0777) != 0 && errno != EEXIST) {
      free(copy);
      return -1;
    }
    copy[index] = '/';
  }
  int result = mkdir(copy, 0777);
  if (result != 0 && errno == EEXIST) result = 0;
  free(copy);
  return result;
}
