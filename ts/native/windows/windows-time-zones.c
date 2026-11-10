// noda-js: new code. See windows-time-zones.h.

#include "windows-time-zones.h"

size_t TzWideLength(const WCHAR* text, size_t maxLength) {
  size_t length = 0;
  while (length < maxLength && text[length] != L'\0') {
    length++;
  }
  return length;
}

BOOL TzGetDynamicTimeZoneInformation(DYNAMIC_TIME_ZONE_INFORMATION* dtzi) {
  ZeroMemory(dtzi, sizeof *dtzi);
  return GetDynamicTimeZoneInformation(dtzi) != TIME_ZONE_ID_INVALID;
}

BOOL TzGetRegistrySubKeyNames(const WCHAR* keyPath, TzNameCallback onName, void* context) {
  HKEY key;
  if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, keyPath, 0, KEY_READ, &key) != ERROR_SUCCESS) {
    return FALSE;
  }
  WCHAR name[MAX_KEY_LENGTH];
  for (DWORD index = 0;; index++) {
    DWORD length = MAX_KEY_LENGTH;
    if (RegEnumKeyExW(key, index, name, &length, NULL, NULL, NULL, NULL) != ERROR_SUCCESS) {
      // ERROR_NO_MORE_ITEMS at the end; anything else ends the enumeration too, as .NET's GetSubKeyNames would fail.
      break;
    }
    onName(context, index, name, length);
  }
  RegCloseKey(key);
  return TRUE;
}

BOOL TzRegistryKeyExists(const WCHAR* keyPath) {
  HKEY key;
  LSTATUS status = RegOpenKeyExW(HKEY_LOCAL_MACHINE, keyPath, 0, KEY_READ, &key);
  if (status == ERROR_SUCCESS) {
    RegCloseKey(key);
  }
  return status == ERROR_SUCCESS;
}

BYTE* TzGetRegistryValue(const WCHAR* keyPath, const WCHAR* valueName, DWORD* type, DWORD* size) {
  BYTE* data = NULL;
  *type = 0;
  *size = 0;
  LSTATUS status = RegGetValueW(HKEY_LOCAL_MACHINE, keyPath, valueName, RRF_RT_ANY | RRF_NOEXPAND, type, NULL, size);
  // The value can grow between the two calls; retry with the new size.
  for (int attempt = 0; status == ERROR_SUCCESS && attempt < 4; attempt++) {
    data = (BYTE*) HeapAlloc(GetProcessHeap(), 0, *size + sizeof(WCHAR));
    if (data == NULL) {
      status = ERROR_OUTOFMEMORY;
      break;
    }
    status = RegGetValueW(HKEY_LOCAL_MACHINE, keyPath, valueName, RRF_RT_ANY | RRF_NOEXPAND, type, data, size);
    if (status != ERROR_MORE_DATA) {
      break;
    }
    HeapFree(GetProcessHeap(), 0, data);
    data = NULL;
    status = RegGetValueW(HKEY_LOCAL_MACHINE, keyPath, valueName, RRF_RT_ANY | RRF_NOEXPAND, type, NULL, size);
  }
  if (status != ERROR_SUCCESS) {
    TzFree(data);
    return NULL;
  }
  return data;
}

void TzFree(void* memory) {
  if (memory != NULL) {
    HeapFree(GetProcessHeap(), 0, memory);
  }
}

size_t TzGetSystemDirectory(WCHAR directory[MAX_PATH + 1]) {
  UINT length = GetSystemDirectoryW(directory, MAX_PATH + 1);
  return length < MAX_PATH + 1 ? length : 0;
}

void TzGetUserPreferredUILanguages(TzNameCallback onName, void* context) {
  ULONG count = 0;
  ULONG length = 0;
  if (!GetUserPreferredUILanguages(MUI_LANGUAGE_NAME, &count, NULL, &length) || length == 0) {
    return;
  }
  WCHAR* buffer = (WCHAR*) HeapAlloc(GetProcessHeap(), 0, length * sizeof(WCHAR));
  if (buffer == NULL) {
    return;
  }
  if (GetUserPreferredUILanguages(MUI_LANGUAGE_NAME, &count, buffer, &length)) {
    TzForEachMultiString(buffer, count, onName, context);
  }
  HeapFree(GetProcessHeap(), 0, buffer);
}

void TzForEachMultiString(const WCHAR* names, ULONG count, TzNameCallback onName, void* context) {
  const WCHAR* name = names;
  for (uint32_t index = 0; index < count && *name != L'\0'; index++) {
    size_t nameLength = lstrlenW(name);
    onName(context, index, name, nameLength);
    name += nameLength + 1;
  }
}

BOOL TzFileExists(const WCHAR* path) {
  DWORD attributes = GetFileAttributesW(path);
  return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

size_t TzLoadString(const WCHAR* path, UINT resourceId, WCHAR text[LOAD_STRING_MAX_LENGTH]) {
  int length = 0;
  HMODULE module = LoadLibraryExW(path, NULL, LOAD_LIBRARY_AS_DATAFILE);
  if (module != NULL) {
    length = LoadStringW(module, resourceId, text, LOAD_STRING_MAX_LENGTH);
    FreeLibrary(module);
  }
  return length > 0 ? (size_t) length : 0;
}
