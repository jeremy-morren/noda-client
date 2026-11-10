// noda_dart: new code (noda-js's WindowsTimeZoneApi.ts). Finds how this host reads Windows' time zone data.

import 'package:meta/meta.dart';

import '../Host.dart';
import 'IWindowsTimeZoneApi.dart';

/// Where the system source gets its zones: "ffi" (Windows, through dart:ffi), "tzif" (TZif files) or "intl" (browser).
typedef SystemTimeZoneBackend = String;

/// A way to read Windows' time zone data.
@internal
final class WindowsTimeZoneApiBackend {
  /// Always "ffi" in noda_dart.
  final SystemTimeZoneBackend Backend;

  /// For VersionId: "dart:ffi".
  final String Description;

  final IWindowsTimeZoneApi Api;

  const WindowsTimeZoneApiBackend(this.Backend, this.Description, this.Api);
}

WindowsTimeZoneApiBackend? _TryLoadFfi() {
  final api = CreateFfiWindowsTimeZoneApi();
  return api == null ? null : WindowsTimeZoneApiBackend('ffi', api.$1, api.$2);
}

/// The way this host reads Windows' time zone data (dart:ffi), or null if it isn't Windows.
@internal
WindowsTimeZoneApiBackend? FindWindowsTimeZoneApi() {
  if (!IsWindowsRuntime()) {
    return null;
  }
  return _TryLoadFfi();
}
