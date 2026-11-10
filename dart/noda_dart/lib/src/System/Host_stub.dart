// noda_dart: new code. System/Host.dart for platforms with neither dart:io nor dart:js_interop: no system time zones.

import 'package:meta/meta.dart';

import 'IHostSystemTimeZones.dart';
import 'IntlTimeZone.dart';
import 'Windows/IWindowsTimeZoneApi.dart';

@internal
bool IsWindowsRuntime() => false;

@internal
String? ReadHostTZ() => null;

@internal
(String, IWindowsTimeZoneApi)? CreateFfiWindowsTimeZoneApi() => null;

@internal
String? IcuCanonicalTimeZoneId(String id) => null;

@internal
bool IntlIsAvailable() => false;

@internal
IntlDateTimeFormat NewIntlDateTimeFormat(String? locale, Map<String, Object> options) =>
    throw UnsupportedError('There is no Intl on this platform');

@internal
List<String>? IntlSupportedTimeZones() => null;

@internal
String? GetProcessTzVersion() => null;

@internal
IHostSystemTimeZones? CreateTzifSystemTimeZones() => null;

@internal
String? GetHostLocalTimeZoneId() => null;
