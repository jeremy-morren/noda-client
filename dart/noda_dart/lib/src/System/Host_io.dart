// noda_dart: new code. System/Host.dart on native platforms: dart:ffi on Windows, TZif files elsewhere, no Intl.

import 'dart:io';

import 'package:meta/meta.dart';

import 'IHostSystemTimeZones.dart';
import 'IntlTimeZone.dart';
import 'TzifSystemTimeZones.dart';
import 'Windows/FfiWindowsTimeZoneApi.dart' as ffi;
import 'Windows/IWindowsTimeZoneApi.dart';

@internal
bool IsWindowsRuntime() => Platform.isWindows;

@internal
String? ReadHostTZ() {
  try {
    return Platform.environment['TZ'];
  } catch (_) {
    return null;
  }
}

@internal
(String, IWindowsTimeZoneApi)? CreateFfiWindowsTimeZoneApi() {
  final api = ffi.FfiWindowsTimeZoneApi.TryCreate();
  return api == null ? null : (api.FfiName, api);
}

@internal
String? IcuCanonicalTimeZoneId(String id) => ffi.IcuCanonicalTimeZoneId(id);

@internal
bool IntlIsAvailable() => false;

@internal
IntlDateTimeFormat NewIntlDateTimeFormat(String? locale, Map<String, Object> options) =>
    throw UnsupportedError('There is no Intl on native platforms');

@internal
List<String>? IntlSupportedTimeZones() => null;

@internal
String? GetProcessTzVersion() => null;

@internal
IHostSystemTimeZones? CreateTzifSystemTimeZones() => Platform.isWindows ? null : TzifSystemTimeZones.ForHost();

/// The host's zone ID (Windows' dynamic zone key, else /etc/localtime's or Android's persist.sys.timezone), or null.
@internal
String? GetHostLocalTimeZoneId() {
  if (Platform.isWindows) {
    final keyName = ffi.FfiWindowsTimeZoneApi.TryCreate()?.GetDynamicTimeZoneInformation()?.TimeZoneKeyName;
    return keyName == null || keyName.isEmpty ? null : keyName;
  }
  return TzifSystemTimeZones.ForHost().GetHostLocalId();
}
