// noda_dart: new code. test/system/Environment.dart on the VM.

import 'dart:io';

import 'package:noda_dart/src/System/Windows/FfiWindowsTimeZoneApi.dart';

/// Null if unset or empty.
String? ReadEnvironment(String name) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : value;
}

bool get IsWindows => Platform.isWindows;

bool get IsTZSet => (Platform.environment['TZ'] ?? '') != '';

String get PlatformName => Platform.operatingSystem;

bool get IsWindowsDaylightSavingTimeDisabled =>
    Platform.isWindows &&
    (FfiWindowsTimeZoneApi.TryCreate()?.GetDynamicTimeZoneInformation()?.DynamicDaylightTimeDisabled ?? false);
