// noda_dart: new code (noda-js's IWindowsTimeZoneApi). The Win32 calls .NET's TimeZoneInfo.Win32.cs makes, as plain
// Dart values, one call each, so implementations (dart:ffi, test fakes) return exactly what Windows does.

import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A Win32 SYSTEMTIME (minwinbase.h): every field is a WORD.
@internal
final class WindowsSystemTime {
  final int Year;
  final int Month;
  final int DayOfWeek;
  final int Day;
  final int Hour;
  final int Minute;
  final int Second;
  final int Milliseconds;

  const WindowsSystemTime(
      this.Year, this.Month, this.DayOfWeek, this.Day, this.Hour, this.Minute, this.Second, this.Milliseconds);

  /// Reads a SYSTEMTIME at the given offset of a buffer (little-endian WORDs).
  static WindowsSystemTime Read(ByteData view, int offset) {
    return WindowsSystemTime(
      view.getUint16(offset, Endian.little),
      view.getUint16(offset + 2, Endian.little),
      view.getUint16(offset + 4, Endian.little),
      view.getUint16(offset + 6, Endian.little),
      view.getUint16(offset + 8, Endian.little),
      view.getUint16(offset + 10, Endian.little),
      view.getUint16(offset + 12, Endian.little),
      view.getUint16(offset + 14, Endian.little),
    );
  }
}

/// A Win32 DYNAMIC_TIME_ZONE_INFORMATION (timezoneapi.h), as GetDynamicTimeZoneInformation fills it.
@internal
final class WindowsDynamicTimeZoneInformation {
  final int Bias;
  final String StandardName;
  final WindowsSystemTime StandardDate;
  final int StandardBias;
  final String DaylightName;
  final WindowsSystemTime DaylightDate;
  final int DaylightBias;
  final String TimeZoneKeyName;
  final bool DynamicDaylightTimeDisabled;

  const WindowsDynamicTimeZoneInformation(this.Bias, this.StandardName, this.StandardDate, this.StandardBias,
      this.DaylightName, this.DaylightDate, this.DaylightBias, this.TimeZoneKeyName, this.DynamicDaylightTimeDisabled);

  /// sizeof(DYNAMIC_TIME_ZONE_INFORMATION).
  static const int Size = 432;

  /// Reads a DYNAMIC_TIME_ZONE_INFORMATION (432 bytes, timezoneapi.h).
  static WindowsDynamicTimeZoneInformation Read(Uint8List bytes) {
    final view = ByteData.sublistView(bytes);
    return WindowsDynamicTimeZoneInformation(
      view.getInt32(0, Endian.little),
      ReadWideString(bytes, 4, 32),
      WindowsSystemTime.Read(view, 68),
      view.getInt32(84, Endian.little),
      ReadWideString(bytes, 88, 32),
      WindowsSystemTime.Read(view, 152),
      view.getInt32(168, Endian.little),
      ReadWideString(bytes, 172, 128),
      bytes[428] != 0,
    );
  }
}

/// Reads a UTF-16LE string of at most [maxChars] characters from [bytes] at [offset], up to the first null.
@internal
String ReadWideString(Uint8List bytes, int offset, int maxChars) {
  final codeUnits = <int>[];
  for (var i = 0; i < maxChars && offset + 2 * i + 1 < bytes.length; i++) {
    final c = bytes[offset + 2 * i] | (bytes[offset + 2 * i + 1] << 8);
    if (c == 0) {
      break;
    }
    codeUnits.add(c);
  }
  return String.fromCharCodes(codeUnits);
}

/// The Windows calls the system source makes. Registry paths are relative to HKLM, with no trailing backslash.
/// Implementations return null (or false, or "") rather than throw for a missing key, value or file.
@internal
abstract interface class IWindowsTimeZoneApi {
  /// kernel32!GetDynamicTimeZoneInformation, or null for TIME_ZONE_ID_INVALID.
  WindowsDynamicTimeZoneInformation? GetDynamicTimeZoneInformation();

  /// RegOpenKeyExW then RegEnumKeyExW: the key's subkey names in enumeration order; null if it can't be opened.
  List<String>? GetRegistrySubKeyNames(String keyPath);

  /// advapi32!RegOpenKeyExW(HKEY_LOCAL_MACHINE, keyPath, KEY_READ): whether the key can be opened.
  bool RegistryKeyExists(String keyPath);

  /// RegGetValueW(HKLM, keyPath, valueName, RRF_RT_ANY | RRF_NOEXPAND), or null: a [String] for REG_SZ/REG_EXPAND_SZ
  /// (unexpanded), an [int] for REG_DWORD, else the bytes ([Uint8List]).
  Object? GetRegistryValue(String keyPath, String valueName);

  /// kernel32!GetSystemDirectoryW (.NET's Environment.SystemDirectory), e.g. "C:\\Windows\\system32".
  String GetSystemDirectory();

  /// kernel32!GetUserPreferredUILanguages(MUI_LANGUAGE_NAME), most preferred first (.NET's CurrentUICulture).
  List<String> GetUserPreferredUILanguages();

  /// kernel32!GetFileAttributesW: whether the file exists (and isn't a directory), as .NET's File.Exists.
  bool FileExists(String path);

  /// kernel32!LoadLibraryExW(filePath, LOAD_LIBRARY_AS_DATAFILE), user32!LoadStringW(resourceId, 500 characters), then
  /// FreeLibrary: the string resource, or "" if the file can't be loaded or has no such string.
  String LoadString(String filePath, int resourceId);
}
