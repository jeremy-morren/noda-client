// noda-js: new code. Unit tests of windows-time-zones.c (greatest.h), built and run by ts/scripts/native/test-native.ts.
// The registry tests map HKEY_LOCAL_MACHINE to a scratch key under HKEY_CURRENT_USER (RegOverridePredefKey).

// For greatest.h's strncat.
#define _CRT_SECURE_NO_WARNINGS
#include "../windows-time-zones.h"
#include <wchar.h>
#include "greatest.h"

#define TIME_ZONES L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Time Zones"
#define SCRATCH_KEY L"Software\\noda-js\\native-tests"
#define MAX_NAMES 512

/** Asserts two wide strings are equal. */
#define ASSERT_WSTR_EQ(expected, actual) ASSERTm("wide strings differ", wcscmp((expected), (actual)) == 0)

/** The names a TzNameCallback received. */
typedef struct {
  uint32_t count;
  BOOL inOrder;
  WCHAR names[MAX_NAMES][MAX_KEY_LENGTH];
} Names;

static Names names;

/** A TzNameCallback that collects into a Names. */
static void Collect(void* context, uint32_t index, const WCHAR* name, size_t length) {
  Names* collected = (Names*) context;
  collected->inOrder = collected->inOrder && index == collected->count;
  if (collected->count < MAX_NAMES && length < MAX_KEY_LENGTH) {
    wmemcpy(collected->names[collected->count], name, length);
    collected->names[collected->count][length] = L'\0';
  }
  collected->count++;
}

/** Clears the collected names. */
static Names* ResetNames(void) {
  names.count = 0;
  names.inOrder = TRUE;
  return &names;
}

/** Whether the collected names include one. */
static BOOL HasName(const WCHAR* name) {
  for (uint32_t i = 0; i < names.count && i < MAX_NAMES; i++) {
    if (wcscmp(names.names[i], name) == 0) {
      return TRUE;
    }
  }
  return FALSE;
}

// ---- Strings ----

TEST WideLength_stops_at_NUL_or_maxLength(void) {
  ASSERT_EQ(3, TzWideLength(L"abc", 10));
  ASSERT_EQ(2, TzWideLength(L"abc", 2));
  ASSERT_EQ(0, TzWideLength(L"", 10));
  ASSERT_EQ(0, TzWideLength(L"abc", 0));
  ASSERT_EQ(2, TzWideLength(L"ab\0cd", 5));
  PASS();
}

TEST ForEachMultiString_reads_count_names_up_to_the_empty_one(void) {
  const WCHAR* multi = L"en-US\0fr-FR\0";
  TzForEachMultiString(multi, 2, Collect, ResetNames());
  ASSERT_EQ(2, names.count);
  ASSERT(names.inOrder);
  ASSERT_WSTR_EQ(L"en-US", names.names[0]);
  ASSERT_WSTR_EQ(L"fr-FR", names.names[1]);
  TzForEachMultiString(multi, 1, Collect, ResetNames());
  ASSERT_EQ(1, names.count);
  TzForEachMultiString(multi, 5, Collect, ResetNames());
  ASSERT_EQ(2, names.count);
  TzForEachMultiString(L"", 3, Collect, ResetNames());
  ASSERT_EQ(0, names.count);
  PASS();
}

SUITE(strings) {
  RUN_TEST(WideLength_stops_at_NUL_or_maxLength);
  RUN_TEST(ForEachMultiString_reads_count_names_up_to_the_empty_one);
}

// ---- This machine's data ----

TEST DynamicTimeZoneInformation_names_a_registry_zone(void) {
  DYNAMIC_TIME_ZONE_INFORMATION dtzi;
  ASSERT(TzGetDynamicTimeZoneInformation(&dtzi));
  ASSERT(dtzi.TimeZoneKeyName[0] != L'\0');
  WCHAR key[512];
  swprintf(key, ARRAYSIZE(key), L"%s\\%s", TIME_ZONES, dtzi.TimeZoneKeyName);
  ASSERT(TzRegistryKeyExists(key));
  PASS();
}

TEST SubKeyNames_lists_the_time_zones(void) {
  ASSERT(TzGetRegistrySubKeyNames(TIME_ZONES, Collect, ResetNames()));
  ASSERT(names.inOrder);
  ASSERT_GT(names.count, 100);
  ASSERT(HasName(L"UTC"));
  ASSERT(HasName(L"Tokyo Standard Time"));
  ASSERT_FALSE(TzGetRegistrySubKeyNames(TIME_ZONES L"\\No Such Zone", Collect, ResetNames()));
  ASSERT_EQ(0, names.count);
  PASS();
}

TEST RegistryKeyExists_for_zones(void) {
  ASSERT(TzRegistryKeyExists(TIME_ZONES));
  ASSERT(TzRegistryKeyExists(TIME_ZONES L"\\Tokyo Standard Time"));
  ASSERT_FALSE(TzRegistryKeyExists(TIME_ZONES L"\\No Such Zone"));
  PASS();
}

TEST RegistryValue_reads_a_zone(void) {
  DWORD type;
  DWORD size;
  BYTE* tzi = TzGetRegistryValue(TIME_ZONES L"\\Tokyo Standard Time", L"TZI", &type, &size);
  ASSERT(tzi != NULL);
  ASSERT_EQ(REG_BINARY, type);
  // REG_TZI_FORMAT: Bias, StandardBias, DaylightBias, StandardDate, DaylightDate.
  ASSERT_EQ(44, size);
  ASSERT_EQ(-540, *(const LONG*) tzi);
  TzFree(tzi);
  WCHAR* display = (WCHAR*) TzGetRegistryValue(TIME_ZONES L"\\Tokyo Standard Time", L"Display", &type, &size);
  ASSERT(display != NULL);
  ASSERT_EQ(REG_SZ, type);
  ASSERT_EQ(0, wcsncmp(L"(UTC+09:00)", display, 11));
  TzFree(display);
  ASSERT_EQ(NULL, TzGetRegistryValue(TIME_ZONES L"\\Tokyo Standard Time", L"No such value", &type, &size));
  ASSERT_EQ(NULL, TzGetRegistryValue(TIME_ZONES L"\\No Such Zone", L"TZI", &type, &size));
  PASS();
}

TEST RegistryValue_reads_Dynamic_DST(void) {
  DWORD type;
  DWORD size;
  DWORD* first = (DWORD*) TzGetRegistryValue(TIME_ZONES L"\\Pacific Standard Time\\Dynamic DST", L"FirstEntry", &type, &size);
  ASSERT(first != NULL);
  ASSERT_EQ(REG_DWORD, type);
  ASSERT_EQ(sizeof(DWORD), size);
  WCHAR year[16];
  swprintf(year, ARRAYSIZE(year), L"%lu", *first);
  TzFree(first);
  BYTE* rule = TzGetRegistryValue(TIME_ZONES L"\\Pacific Standard Time\\Dynamic DST", year, &type, &size);
  ASSERT(rule != NULL);
  ASSERT_EQ(REG_BINARY, type);
  ASSERT_EQ(44, size);
  TzFree(rule);
  PASS();
}

TEST LoadString_loads_a_MUI_name(void) {
  DWORD type;
  DWORD size;
  WCHAR* mui = (WCHAR*) TzGetRegistryValue(TIME_ZONES L"\\Tokyo Standard Time", L"MUI_Std", &type, &size);
  ASSERT(mui != NULL);
  // "@tzres.dll,-<id>"
  const WCHAR* comma = wcsrchr(mui, L',');
  ASSERT(mui[0] == L'@' && comma != NULL && comma[1] == L'-');
  UINT id = (UINT) wcstoul(comma + 2, NULL, 10);
  WCHAR path[MAX_PATH + 64];
  size_t length = TzGetSystemDirectory(path);
  swprintf(path + length, ARRAYSIZE(path) - length, L"\\%.*s", (int) (comma - mui - 1), mui + 1);
  TzFree(mui);
  WCHAR text[LOAD_STRING_MAX_LENGTH];
  ASSERT_GT(TzLoadString(path, id, text), 0);
  ASSERT_EQ(0, TzLoadString(path, 0xFFF0, text));
  ASSERT_EQ(0, TzLoadString(L"C:\\no-such-directory\\no-such-file.dll", id, text));
  PASS();
}

TEST SystemDirectory_and_FileExists(void) {
  WCHAR path[MAX_PATH + 64];
  size_t length = TzGetSystemDirectory(path);
  ASSERT_GT(length, 0);
  ASSERT_EQ(wcslen(path), length);
  ASSERT_FALSE(TzFileExists(path));
  wcscpy_s(path + length, ARRAYSIZE(path) - length, L"\\kernel32.dll");
  ASSERT(TzFileExists(path));
  wcscpy_s(path + length, ARRAYSIZE(path) - length, L"\\no-such-file.dll");
  ASSERT_FALSE(TzFileExists(path));
  PASS();
}

TEST UserPreferredUILanguages_lists_names(void) {
  TzGetUserPreferredUILanguages(Collect, ResetNames());
  ASSERT_GT(names.count, 0);
  ASSERT(names.inOrder);
  for (uint32_t i = 0; i < names.count; i++) {
    ASSERT(names.names[i][0] != L'\0');
  }
  PASS();
}

SUITE(machine) {
  RUN_TEST(DynamicTimeZoneInformation_names_a_registry_zone);
  RUN_TEST(SubKeyNames_lists_the_time_zones);
  RUN_TEST(RegistryKeyExists_for_zones);
  RUN_TEST(RegistryValue_reads_a_zone);
  RUN_TEST(RegistryValue_reads_Dynamic_DST);
  RUN_TEST(LoadString_loads_a_MUI_name);
  RUN_TEST(SystemDirectory_and_FileExists);
  RUN_TEST(UserPreferredUILanguages_lists_names);
}

// ---- A scratch registry ----

static HKEY scratch;

/** Maps HKEY_LOCAL_MACHINE to a new, empty scratch key. */
static void MapScratch(void* data) {
  (void) data;
  RegDeleteTreeW(HKEY_CURRENT_USER, SCRATCH_KEY);
  RegCreateKeyExW(HKEY_CURRENT_USER, SCRATCH_KEY, 0, NULL, 0, KEY_ALL_ACCESS, NULL, &scratch, NULL);
  RegOverridePredefKey(HKEY_LOCAL_MACHINE, scratch);
}

/** Restores HKEY_LOCAL_MACHINE and deletes the scratch key. */
static void UnmapScratch(void* data) {
  (void) data;
  RegOverridePredefKey(HKEY_LOCAL_MACHINE, NULL);
  RegCloseKey(scratch);
  RegDeleteTreeW(HKEY_CURRENT_USER, SCRATCH_KEY);
}

/** Sets a value in the scratch key (creating its subkey). */
static LSTATUS SetValue(const WCHAR* key, const WCHAR* name, DWORD type, const void* data, DWORD size) {
  return RegSetKeyValueW(scratch, key, name, type, data, size);
}

TEST Scratch_strings_are_read_raw(void) {
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Terminated", REG_SZ, L"abc", 4 * sizeof(WCHAR)));
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Unterminated", REG_SZ, L"abc", 3 * sizeof(WCHAR)));
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Embedded", REG_SZ, L"ab\0cd", 6 * sizeof(WCHAR)));
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Expand", REG_EXPAND_SZ, L"%SystemRoot%", 13 * sizeof(WCHAR)));
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Empty", REG_SZ, L"", 0));
  const WCHAR* expected[][2] = {
    { L"Terminated", L"abc" }, { L"Unterminated", L"abc" }, { L"Embedded", L"ab" }, { L"Expand", L"%SystemRoot%" },
    { L"Empty", L"" },
  };
  for (size_t i = 0; i < ARRAYSIZE(expected); i++) {
    DWORD type;
    DWORD size;
    WCHAR* text = (WCHAR*) TzGetRegistryValue(L"Zone", expected[i][0], &type, &size);
    ASSERTm("missing string value", text != NULL);
    size_t length = TzWideLength(text, size / sizeof(WCHAR));
    ASSERT_EQ(wcslen(expected[i][1]), length);
    ASSERT_EQ(0, wmemcmp(expected[i][1], text, length));
    TzFree(text);
  }
  PASS();
}

TEST Scratch_other_types_are_read_as_bytes(void) {
  DWORD dword = 0x12345678;
  ULONGLONG qword = 0x1122334455667788ULL;
  static BYTE large[100000];
  memset(large, 0x5A, sizeof large);
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Dword", REG_DWORD, &dword, sizeof dword));
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Qword", REG_QWORD, &qword, sizeof qword));
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Multi", REG_MULTI_SZ, L"a\0b\0", 5 * sizeof(WCHAR)));
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"EmptyBinary", REG_BINARY, NULL, 0));
  ASSERT_EQ(ERROR_SUCCESS, SetValue(L"Zone", L"Large", REG_BINARY, large, sizeof large));
  DWORD type;
  DWORD size;
  BYTE* data = TzGetRegistryValue(L"Zone", L"Dword", &type, &size);
  ASSERT(data != NULL && type == REG_DWORD && size == sizeof dword && *(DWORD*) data == dword);
  TzFree(data);
  data = TzGetRegistryValue(L"Zone", L"Qword", &type, &size);
  ASSERT(data != NULL && type == REG_QWORD && size == sizeof qword && *(ULONGLONG*) data == qword);
  TzFree(data);
  data = TzGetRegistryValue(L"Zone", L"Multi", &type, &size);
  ASSERT(data != NULL && type == REG_MULTI_SZ && size == 5 * sizeof(WCHAR));
  ASSERT_MEM_EQ(L"a\0b\0", data, size);
  TzFree(data);
  data = TzGetRegistryValue(L"Zone", L"EmptyBinary", &type, &size);
  ASSERT(data != NULL && type == REG_BINARY && size == 0);
  TzFree(data);
  data = TzGetRegistryValue(L"Zone", L"Large", &type, &size);
  ASSERT(data != NULL && type == REG_BINARY && size == sizeof large);
  ASSERT_MEM_EQ(large, data, size);
  TzFree(data);
  PASS();
}

TEST Scratch_subkeys(void) {
  HKEY key;
  const WCHAR* zones[] = { L"Zones\\B", L"Zones\\A", L"Zones\\C\\Dynamic DST", L"Empty" };
  for (size_t i = 0; i < ARRAYSIZE(zones); i++) {
    ASSERT_EQ(ERROR_SUCCESS, RegCreateKeyExW(scratch, zones[i], 0, NULL, 0, KEY_ALL_ACCESS, NULL, &key, NULL));
    RegCloseKey(key);
  }
  // The longest key name.
  WCHAR longest[6 + MAX_KEY_LENGTH] = L"Zones\\";
  wmemset(longest + 6, L'z', MAX_KEY_LENGTH - 1);
  longest[6 + MAX_KEY_LENGTH - 1] = L'\0';
  ASSERT_EQ(ERROR_SUCCESS, RegCreateKeyExW(scratch, longest, 0, NULL, 0, KEY_ALL_ACCESS, NULL, &key, NULL));
  RegCloseKey(key);
  ASSERT(TzGetRegistrySubKeyNames(L"Zones", Collect, ResetNames()));
  ASSERT(names.inOrder);
  ASSERT_EQ(4, names.count);
  ASSERT(HasName(L"A") && HasName(L"B") && HasName(L"C") && HasName(longest + 6));
  ASSERT(TzGetRegistrySubKeyNames(L"Empty", Collect, ResetNames()));
  ASSERT_EQ(0, names.count);
  ASSERT(TzRegistryKeyExists(L"Zones\\C\\Dynamic DST"));
  ASSERT_FALSE(TzRegistryKeyExists(L"Zones\\D"));
  PASS();
}

static volatile LONG stopWriting;

/** Rewrites the value Racing as absent, 16 bytes of 0x11 and 8192 of 0x22, until stopWriting. */
static DWORD WINAPI RewriteRacing(void* parameter) {
  (void) parameter;
  static BYTE small[16];
  static BYTE large[8192];
  memset(small, 0x11, sizeof small);
  memset(large, 0x22, sizeof large);
  while (!stopWriting) {
    RegSetKeyValueW(scratch, L"Zone", L"Racing", REG_BINARY, small, sizeof small);
    RegSetKeyValueW(scratch, L"Zone", L"Racing", REG_BINARY, large, sizeof large);
    RegDeleteKeyValueW(scratch, L"Zone", L"Racing");
  }
  return 0;
}

TEST Scratch_a_value_changing_while_read_is_read_whole_or_not_at_all(void) {
  stopWriting = 0;
  HANDLE writer = CreateThread(NULL, 0, RewriteRacing, NULL, 0, NULL);
  ASSERT(writer != NULL);
  int whole = 0;
  BOOL torn = FALSE;
  for (int i = 0; i < 20000 && !torn; i++) {
    DWORD type;
    DWORD size;
    BYTE* data = TzGetRegistryValue(L"Zone", L"Racing", &type, &size);
    if (data != NULL) {
      BYTE fill = size == 16 ? 0x11 : size == 8192 ? 0x22 : 0;
      for (DWORD b = 0; b < size; b++) {
        torn = torn || data[b] != fill;
      }
      torn = torn || fill == 0;
      whole++;
      TzFree(data);
    }
  }
  InterlockedExchange(&stopWriting, 1);
  WaitForSingleObject(writer, INFINITE);
  CloseHandle(writer);
  ASSERT_FALSEm("a read returned part of a value", torn);
  ASSERT_GT(whole, 0);
  PASS();
}

SUITE(scratch_registry) {
  SET_SETUP(MapScratch, NULL);
  SET_TEARDOWN(UnmapScratch, NULL);
  RUN_TEST(Scratch_strings_are_read_raw);
  RUN_TEST(Scratch_other_types_are_read_as_bytes);
  RUN_TEST(Scratch_subkeys);
  RUN_TEST(Scratch_a_value_changing_while_read_is_read_whole_or_not_at_all);
}

GREATEST_MAIN_DEFS();

int main(int argc, char** argv) {
  GREATEST_MAIN_BEGIN();
  RUN_SUITE(strings);
  RUN_SUITE(machine);
  RUN_SUITE(scratch_registry);
  GREATEST_MAIN_END();
}
