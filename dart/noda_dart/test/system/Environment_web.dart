// noda_dart: new code. test/system/Environment.dart on the web: -D defines stand in for environment variables.

// ignore: do_not_use_environment
const bool _isWasm = bool.fromEnvironment('dart.tool.dart2wasm');

const Map<String, String> _defines = {
  // ignore: do_not_use_environment
  'NODA_EXPECT_SYSTEM_TIME_ZONE': String.fromEnvironment('NODA_EXPECT_SYSTEM_TIME_ZONE'),
  // ignore: do_not_use_environment
  'NODA_EXPECT_LOCALIZED_WINDOWS': String.fromEnvironment('NODA_EXPECT_LOCALIZED_WINDOWS'),
  // ignore: do_not_use_environment
  'NODA_SYSTEM_ZONES_JSON': String.fromEnvironment('NODA_SYSTEM_ZONES_JSON'),
};

/// Null if unset or empty.
String? ReadEnvironment(String name) {
  final value = _defines[name];
  return value == null || value.isEmpty ? null : value;
}

bool get IsWindows => false;

/// Node's TZ already decides Intl's default zone.
bool get IsTZSet => false;

String get PlatformName => 'web (${_isWasm ? 'dart2wasm' : 'dart2js'})';

bool get IsWindowsDaylightSavingTimeDisabled => false;
