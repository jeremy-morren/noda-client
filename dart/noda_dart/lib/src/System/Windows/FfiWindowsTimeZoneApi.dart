// noda_dart: new code (noda-js's FfiWindowsTimeZoneApi). IWindowsTimeZoneApi over dart:ffi, native only. Memory from
// LocalAlloc (noda_dart depends only on package:meta); string resources load as .NET loads them.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'IWindowsTimeZoneApi.dart';

// #region Win32 constants

/// HKEY_LOCAL_MACHINE: (HKEY)(ULONG_PTR)((LONG)0x80000002), so sign-extended to the pointer size.
final int _HKEY_LOCAL_MACHINE = 0x80000002.toSigned(32);
const int _KEY_READ = 0x20019;
const int _ERROR_SUCCESS = 0;
const int _ERROR_MORE_DATA = 234;
const int _ERROR_NO_MORE_ITEMS = 259;
const int _RRF_RT_ANY = 0x0000ffff;
const int _RRF_NOEXPAND = 0x10000000;
const int _REG_SZ = 1;
const int _REG_EXPAND_SZ = 2;
const int _REG_DWORD = 4;
const int _MUI_LANGUAGE_NAME = 0x8;
const int _TIME_ZONE_ID_INVALID = 0xffffffff;
const int _INVALID_FILE_ATTRIBUTES = 0xffffffff;
const int _FILE_ATTRIBUTE_DIRECTORY = 0x10;
const int _LOAD_LIBRARY_AS_DATAFILE = 0x00000002;

/// LMEM_FIXED | LMEM_ZEROINIT.
const int _LPTR = 0x0040;

/// The longest registry key name, in characters (plus the terminating null).
const int _MaxKeyNameLength = 256;

/// .NET's LoadStringMaxLength.
const int _LoadStringMaxLength = 500;

// #endregion

/// Whether this process runs on Windows (by its ABI, so dart:io isn't needed).
@internal
bool IsWindowsAbi() {
  final abi = Abi.current();
  return abi == Abi.windowsX64 || abi == Abi.windowsArm64 || abi == Abi.windowsIA32;
}

/// Native memory from kernel32!LocalAlloc, freed together.
final class _Allocations {
  final Pointer<NativeFunction<Pointer<Void> Function(Uint32, IntPtr)>> _localAlloc;
  final Pointer<NativeFunction<Pointer<Void> Function(Pointer<Void>)>> _localFree;
  final List<Pointer<Void>> _pointers = [];

  _Allocations(this._localAlloc, this._localFree);

  Pointer<T> Allocate<T extends NativeType>(int byteCount) {
    final pointer = _localAlloc.asFunction<Pointer<Void> Function(int, int)>()(_LPTR, byteCount);
    if (pointer.address == 0) {
      throw StateError('LocalAlloc failed');
    }
    _pointers.add(pointer);
    return pointer.cast<T>();
  }

  /// A null-terminated UTF-16 string.
  Pointer<Uint16> Wide(String value) {
    final pointer = Allocate<Uint16>((value.length + 1) * 2);
    for (var i = 0; i < value.length; i++) {
      pointer[i] = value.codeUnitAt(i);
    }
    return pointer;
  }

  void FreeAll() {
    final free = _localFree.asFunction<Pointer<Void> Function(Pointer<Void>)>();
    for (final pointer in _pointers) {
      free(pointer);
    }
    _pointers.clear();
  }
}

/// Reads a UTF-16 string of at most [maxChars] characters, up to the first null.
String _FromWide(Pointer<Uint16> pointer, int maxChars) {
  final codeUnits = <int>[];
  for (var i = 0; i < maxChars; i++) {
    final c = pointer[i];
    if (c == 0) {
      break;
    }
    codeUnits.add(c);
  }
  return String.fromCharCodes(codeUnits);
}

/// IWindowsTimeZoneApi over Win32 functions loaded with dart:ffi.
@internal
final class FfiWindowsTimeZoneApi implements IWindowsTimeZoneApi {
  final Pointer<NativeFunction<Pointer<Void> Function(Uint32, IntPtr)>> _localAlloc;
  final Pointer<NativeFunction<Pointer<Void> Function(Pointer<Void>)>> _localFree;
  final int Function(Pointer<Uint8>) _getDynamicTimeZoneInformation;
  final int Function(Pointer<Uint16>, int) _getSystemDirectoryW;
  final int Function(int, Pointer<Uint32>, Pointer<Uint16>, Pointer<Uint32>) _getUserPreferredUILanguages;
  final int Function(Pointer<Uint16>) _getFileAttributesW;
  final Pointer<Void> Function(Pointer<Uint16>, Pointer<Void>, int) _loadLibraryExW;
  final int Function(Pointer<Void>) _freeLibrary;
  final int Function(int, Pointer<Uint16>, int, int, Pointer<IntPtr>) _regOpenKeyExW;
  final int Function(int, int, Pointer<Uint16>, Pointer<Uint32>, Pointer<Void>, Pointer<Void>, Pointer<Void>,
      Pointer<Void>) _regEnumKeyExW;
  final int Function(int) _regCloseKey;
  final int Function(int, Pointer<Uint16>, Pointer<Uint16>, int, Pointer<Uint32>, Pointer<Void>, Pointer<Uint32>)
      _regGetValueW;
  int Function(Pointer<Void>, int, Pointer<Uint16>, int)? _loadStringW;

  FfiWindowsTimeZoneApi._(DynamicLibrary kernel32, DynamicLibrary advapi32)
      : _localAlloc = kernel32.lookup('LocalAlloc'),
        _localFree = kernel32.lookup('LocalFree'),
        _getDynamicTimeZoneInformation = kernel32.lookupFunction<Uint32 Function(Pointer<Uint8>),
            int Function(Pointer<Uint8>)>('GetDynamicTimeZoneInformation'),
        _getSystemDirectoryW = kernel32.lookupFunction<Uint32 Function(Pointer<Uint16>, Uint32),
            int Function(Pointer<Uint16>, int)>('GetSystemDirectoryW'),
        _getUserPreferredUILanguages = kernel32.lookupFunction<
            Int32 Function(Uint32, Pointer<Uint32>, Pointer<Uint16>, Pointer<Uint32>),
            int Function(int, Pointer<Uint32>, Pointer<Uint16>, Pointer<Uint32>)>('GetUserPreferredUILanguages'),
        _getFileAttributesW = kernel32.lookupFunction<Uint32 Function(Pointer<Uint16>), int Function(Pointer<Uint16>)>(
            'GetFileAttributesW'),
        _loadLibraryExW = kernel32.lookupFunction<Pointer<Void> Function(Pointer<Uint16>, Pointer<Void>, Uint32),
            Pointer<Void> Function(Pointer<Uint16>, Pointer<Void>, int)>('LoadLibraryExW'),
        _freeLibrary =
            kernel32.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('FreeLibrary'),
        _regOpenKeyExW = advapi32.lookupFunction<Int32 Function(IntPtr, Pointer<Uint16>, Uint32, Uint32, Pointer<IntPtr>),
            int Function(int, Pointer<Uint16>, int, int, Pointer<IntPtr>)>('RegOpenKeyExW'),
        _regEnumKeyExW = advapi32.lookupFunction<
            Int32 Function(IntPtr, Uint32, Pointer<Uint16>, Pointer<Uint32>, Pointer<Void>, Pointer<Void>, Pointer<Void>,
                Pointer<Void>),
            int Function(int, int, Pointer<Uint16>, Pointer<Uint32>, Pointer<Void>, Pointer<Void>, Pointer<Void>,
                Pointer<Void>)>('RegEnumKeyExW'),
        _regCloseKey = advapi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('RegCloseKey'),
        _regGetValueW = advapi32.lookupFunction<
            Int32 Function(IntPtr, Pointer<Uint16>, Pointer<Uint16>, Uint32, Pointer<Uint32>, Pointer<Void>,
                Pointer<Uint32>),
            int Function(int, Pointer<Uint16>, Pointer<Uint16>, int, Pointer<Uint32>, Pointer<Void>,
                Pointer<Uint32>)>('RegGetValueW');

  /// How the API is reached, for VersionId.
  String get FfiName => 'dart:ffi';

  /// The API through dart:ffi, or null if this isn't Windows or a test call fails.
  static FfiWindowsTimeZoneApi? TryCreate() {
    if (!IsWindowsAbi()) {
      return null;
    }
    try {
      final api = FfiWindowsTimeZoneApi._(DynamicLibrary.open('kernel32.dll'), DynamicLibrary.open('advapi32.dll'));
      // A call that must succeed, so that a broken binding falls back rather than failing later.
      api.GetSystemDirectory();
      return api;
    } catch (_) {
      return null;
    }
  }

  _Allocations _NewAllocations() => _Allocations(_localAlloc, _localFree);

  @override
  WindowsDynamicTimeZoneInformation? GetDynamicTimeZoneInformation() {
    final memory = _NewAllocations();
    try {
      final buffer = memory.Allocate<Uint8>(WindowsDynamicTimeZoneInformation.Size);
      final result = _getDynamicTimeZoneInformation(buffer);
      return result == _TIME_ZONE_ID_INVALID
          ? null
          : WindowsDynamicTimeZoneInformation.Read(
              Uint8List.fromList(buffer.asTypedList(WindowsDynamicTimeZoneInformation.Size)));
    } finally {
      memory.FreeAll();
    }
  }

  @override
  List<String>? GetRegistrySubKeyNames(String keyPath) {
    final key = _OpenKey(keyPath);
    if (key == null) {
      return null;
    }
    final memory = _NewAllocations();
    try {
      final names = <String>[];
      final name = memory.Allocate<Uint16>(_MaxKeyNameLength * 2);
      final length = memory.Allocate<Uint32>(4);
      for (var index = 0;; index++) {
        length.value = _MaxKeyNameLength;
        final result = _regEnumKeyExW(key, index, name, length, nullptr, nullptr, nullptr, nullptr);
        if (result == _ERROR_NO_MORE_ITEMS) {
          break;
        }
        if (result != _ERROR_SUCCESS) {
          return null;
        }
        names.add(_FromWide(name, length.value));
      }
      return names;
    } finally {
      memory.FreeAll();
      _regCloseKey(key);
    }
  }

  @override
  bool RegistryKeyExists(String keyPath) {
    final key = _OpenKey(keyPath);
    if (key == null) {
      return false;
    }
    _regCloseKey(key);
    return true;
  }

  @override
  Object? GetRegistryValue(String keyPath, String valueName) {
    final memory = _NewAllocations();
    try {
      final subKey = memory.Wide(keyPath);
      final name = memory.Wide(valueName);
      var size = 1024;
      for (;;) {
        final type = memory.Allocate<Uint32>(4);
        final data = memory.Allocate<Uint8>(size);
        final length = memory.Allocate<Uint32>(4);
        length.value = size;
        final result = _regGetValueW(
            _HKEY_LOCAL_MACHINE, subKey, name, _RRF_RT_ANY | _RRF_NOEXPAND, type, data.cast<Void>(), length);
        if (result == _ERROR_MORE_DATA) {
          size = length.value > size * 2 ? length.value : size * 2;
          continue;
        }
        if (result != _ERROR_SUCCESS) {
          return null;
        }
        final count = length.value;
        switch (type.value) {
          case _REG_SZ:
          case _REG_EXPAND_SZ:
            return _FromWide(data.cast<Uint16>(), count ~/ 2);
          case _REG_DWORD:
            return data.cast<Uint32>().value;
          default:
            return Uint8List.fromList(data.asTypedList(count));
        }
      }
    } finally {
      memory.FreeAll();
    }
  }

  @override
  String GetSystemDirectory() {
    final memory = _NewAllocations();
    try {
      final buffer = memory.Allocate<Uint16>(1024);
      final length = _getSystemDirectoryW(buffer, 512);
      return _FromWide(buffer, length);
    } finally {
      memory.FreeAll();
    }
  }

  @override
  List<String> GetUserPreferredUILanguages() {
    final memory = _NewAllocations();
    try {
      final count = memory.Allocate<Uint32>(4);
      final length = memory.Allocate<Uint32>(4);
      length.value = 1024;
      final buffer = memory.Allocate<Uint16>(2048);
      if (_getUserPreferredUILanguages(_MUI_LANGUAGE_NAME, count, buffer, length) == 0) {
        return const [];
      }
      // A multi-string: null-terminated names, then an empty one.
      final languages = <String>[];
      var offset = 0;
      for (var i = 0; i < count.value; i++) {
        final language = _FromWide(buffer + offset, 1024 - offset);
        if (language.isEmpty) {
          break;
        }
        languages.add(language);
        offset += language.length + 1;
      }
      return languages;
    } finally {
      memory.FreeAll();
    }
  }

  @override
  bool FileExists(String path) {
    final memory = _NewAllocations();
    try {
      final attributes = _getFileAttributesW(memory.Wide(path));
      return attributes != _INVALID_FILE_ATTRIBUTES && (attributes & _FILE_ATTRIBUTE_DIRECTORY) == 0;
    } finally {
      memory.FreeAll();
    }
  }

  @override
  String LoadString(String filePath, int resourceId) {
    // As .NET's TimeZoneInfo.TryGetLocalizedNameByNativeResource: the file as a data file, then LoadString.
    _loadStringW ??= DynamicLibrary.open('user32.dll').lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Pointer<Uint16>, Int32),
        int Function(Pointer<Void>, int, Pointer<Uint16>, int)>('LoadStringW');
    final memory = _NewAllocations();
    try {
      final handle = _loadLibraryExW(memory.Wide(filePath), nullptr, _LOAD_LIBRARY_AS_DATAFILE);
      if (handle.address == 0) {
        return '';
      }
      try {
        final localizedResource = memory.Allocate<Uint16>(_LoadStringMaxLength * 2);
        // ((uint)resourceId)
        final charsWritten = _loadStringW!(handle, resourceId.toUnsigned(32), localizedResource, _LoadStringMaxLength);
        if (charsWritten != 0) {
          return String.fromCharCodes(localizedResource.asTypedList(charsWritten));
        }
      } finally {
        _freeLibrary(handle);
      }
      return '';
    } finally {
      memory.FreeAll();
    }
  }

  /// RegOpenKeyExW(HKEY_LOCAL_MACHINE, keyPath): the key's handle, or null.
  int? _OpenKey(String keyPath) {
    final memory = _NewAllocations();
    try {
      final handle = memory.Allocate<IntPtr>(8);
      if (_regOpenKeyExW(_HKEY_LOCAL_MACHINE, memory.Wide(keyPath), 0, _KEY_READ, handle) != _ERROR_SUCCESS) {
        return null;
      }
      return handle.value;
    } finally {
      memory.FreeAll();
    }
  }
}

/// The ID as Windows' own ICU (icu.dll) canonicalizes it ("Asia/Kolkata" → "Asia/Calcutta"), matching ignoring case as
/// Intl does; null if unknown or ICU is missing. Stands in for noda-js's Intl canonicalization.
@internal
String? IcuCanonicalTimeZoneId(String id) {
  if (!IsWindowsAbi()) {
    return null;
  }
  try {
    final icu = _Icu.Instance;
    final canonical = icu.Canonicalize(id);
    if (canonical != null) {
      return canonical;
    }
    final listed = icu.IdsByUpperCase[id.toUpperCase()];
    return listed == null ? null : icu.Canonicalize(listed);
  } catch (_) {
    return null;
  }
}

/// The ICU functions IcuCanonicalTimeZoneId uses.
final class _Icu {
  static _Icu? _instance;

  static _Icu get Instance => _instance ??= _Icu._(DynamicLibrary.open('icu.dll'), DynamicLibrary.open('kernel32.dll'));

  final int Function(Pointer<Uint16>, int, Pointer<Uint16>, int, Pointer<Int8>, Pointer<Int32>) _getCanonicalTimeZoneId;
  final Pointer<Void> Function(Pointer<Int32>) _openTimeZones;
  final Pointer<Uint16> Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>) _unext;
  final void Function(Pointer<Void>) _close;
  final Pointer<NativeFunction<Pointer<Void> Function(Uint32, IntPtr)>> _localAlloc;
  final Pointer<NativeFunction<Pointer<Void> Function(Pointer<Void>)>> _localFree;
  Map<String, String>? _idsByUpperCase;

  _Icu._(DynamicLibrary icu, DynamicLibrary kernel32)
      : _getCanonicalTimeZoneId = icu.lookupFunction<
            Int32 Function(Pointer<Uint16>, Int32, Pointer<Uint16>, Int32, Pointer<Int8>, Pointer<Int32>),
            int Function(Pointer<Uint16>, int, Pointer<Uint16>, int, Pointer<Int8>, Pointer<Int32>)>(
            'ucal_getCanonicalTimeZoneID'),
        _openTimeZones = icu.lookupFunction<Pointer<Void> Function(Pointer<Int32>), Pointer<Void> Function(Pointer<Int32>)>(
            'ucal_openTimeZones'),
        _unext = icu.lookupFunction<Pointer<Uint16> Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>),
            Pointer<Uint16> Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>)>('uenum_unext'),
        _close = icu.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('uenum_close'),
        _localAlloc = kernel32.lookup('LocalAlloc'),
        _localFree = kernel32.lookup('LocalFree');

  /// ucal_getCanonicalTimeZoneID, or null for an ID ICU doesn't know.
  String? Canonicalize(String id) {
    final memory = _Allocations(_localAlloc, _localFree);
    try {
      const capacity = 128;
      final input = memory.Wide(id);
      final result = memory.Allocate<Uint16>(capacity * 2);
      final isSystemId = memory.Allocate<Int8>(1);
      final status = memory.Allocate<Int32>(4);
      final length = _getCanonicalTimeZoneId(input, id.length, result, capacity, isSystemId, status);
      // UErrorCode: 0 is success, negative values are warnings. An unknown ID is an error, or not a system ID.
      if (status.value > 0 || length <= 0 || length > capacity || isSystemId.value == 0) {
        return null;
      }
      return String.fromCharCodes(result.asTypedList(length));
    } finally {
      memory.FreeAll();
    }
  }

  /// ICU's time zone IDs (ucal_openTimeZones), by their upper-cased form.
  Map<String, String> get IdsByUpperCase {
    var ids = _idsByUpperCase;
    if (ids == null) {
      ids = <String, String>{};
      final memory = _Allocations(_localAlloc, _localFree);
      try {
        final status = memory.Allocate<Int32>(4);
        final length = memory.Allocate<Int32>(4);
        final enumeration = _openTimeZones(status);
        if (status.value <= 0 && enumeration.address != 0) {
          try {
            for (;;) {
              final next = _unext(enumeration, length, status);
              if (next.address == 0 || status.value > 0) {
                break;
              }
              final zoneId = String.fromCharCodes(next.asTypedList(length.value));
              ids.putIfAbsent(zoneId.toUpperCase(), () => zoneId);
            }
          } finally {
            _close(enumeration);
          }
        }
      } finally {
        memory.FreeAll();
      }
      _idsByUpperCase = ids;
    }
    return ids;
  }
}
