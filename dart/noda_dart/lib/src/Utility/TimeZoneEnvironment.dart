// noda_dart: new code. The TZ environment variable (see docs/Timezones.md).

import 'package:meta/meta.dart';

import '../System/Host.dart' as host;

/// For tests: the TZ replacement; a record so that null (not set) can be one.
({String? value})? _replacement;

/// For tests: makes [GetTZEnvironmentVariable] read [value] until the returned function is called.
@internal
void Function() ReplaceTZEnvironmentVariable(String? value) {
  final previous = _replacement;
  _replacement = (value: value);
  return () {
    _replacement = previous;
  };
}

/// TZ without a leading ":"; null if unset, empty or unreadable.
@internal
String? GetTZEnvironmentVariable() {
  final replacement = _replacement;
  return _Normalize(replacement != null ? replacement.value : host.ReadHostTZ());
}

/// A leading ":" removed; null for unset or empty.
String? _Normalize(String? value) {
  if (value == null) {
    return null;
  }
  if (value.startsWith(':')) {
    value = value.substring(1);
  }
  return value == '' ? null : value;
}
