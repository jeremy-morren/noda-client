// noda-js: new code. The Windows calls behind the native addon (time-zones.c), without Node-API, so the C tests
// (test/) can call them. Registry paths are under HKEY_LOCAL_MACHINE.

#ifndef NODA_JS_WINDOWS_TIME_ZONES_H
#define NODA_JS_WINDOWS_TIME_ZONES_H

#define WIN32_LEAN_AND_MEAN
#ifndef UNICODE
#define UNICODE
#endif
#include <windows.h>
#include <stdint.h>

// .NET's LoadStringMaxLength (TimeZoneInfo.Win32.cs).
#define LOAD_STRING_MAX_LENGTH 500
// The longest registry key name (MSDN: 255 characters).
#define MAX_KEY_LENGTH 256

/** Receives each name of a list, from index 0. */
typedef void (*TzNameCallback)(void* context, uint32_t index, const WCHAR* name, size_t length);

/** A wide string's length, up to its first NUL or `maxLength` characters (as the FFI implementation reads). */
size_t TzWideLength(const WCHAR* text, size_t maxLength);

/** kernel32!GetDynamicTimeZoneInformation; FALSE for TIME_ZONE_ID_INVALID. */
BOOL TzGetDynamicTimeZoneInformation(DYNAMIC_TIME_ZONE_INFORMATION* dtzi);

/** advapi32!RegOpenKeyExW + RegEnumKeyExW: each subkey name; FALSE if the key can't be opened. */
BOOL TzGetRegistrySubKeyNames(const WCHAR* keyPath, TzNameCallback onName, void* context);

/** advapi32!RegOpenKeyExW: whether the key can be opened. */
BOOL TzRegistryKeyExists(const WCHAR* keyPath);

/** advapi32!RegGetValueW(RRF_RT_ANY | RRF_NOEXPAND): the data (free with TzFree), type and size; NULL if missing. */
BYTE* TzGetRegistryValue(const WCHAR* keyPath, const WCHAR* valueName, DWORD* type, DWORD* size);

/** Frees TzGetRegistryValue's data. */
void TzFree(void* memory);

/** kernel32!GetSystemDirectoryW: its length, 0 if it fails. */
size_t TzGetSystemDirectory(WCHAR directory[MAX_PATH + 1]);

/** kernel32!GetUserPreferredUILanguages(MUI_LANGUAGE_NAME): each language name, most preferred first. */
void TzGetUserPreferredUILanguages(TzNameCallback onName, void* context);

/** The first `count` names of a multi-string (NUL-terminated names, then an empty one). */
void TzForEachMultiString(const WCHAR* names, ULONG count, TzNameCallback onName, void* context);

/** kernel32!GetFileAttributesW: whether the path exists and isn't a directory (.NET's File.Exists). */
BOOL TzFileExists(const WCHAR* path);

/**
 * kernel32!LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE), user32!LoadStringW, FreeLibrary: the string's length in `text`,
 * 0 if the file can't be loaded or has no such string (as .NET's TryGetLocalizedNameByNativeResource).
 */
size_t TzLoadString(const WCHAR* path, UINT resourceId, WCHAR text[LOAD_STRING_MAX_LENGTH]);

#endif
