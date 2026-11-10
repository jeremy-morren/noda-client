// noda_dart: new code. System/Host.dart on the web: the host's Intl through dart:js_interop, and Node's process.env.TZ.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:meta/meta.dart';

import 'IHostSystemTimeZones.dart';
import 'IntlTimeZone.dart';
import 'Windows/IWindowsTimeZoneApi.dart';

@JS('Intl.DateTimeFormat')
extension type _JSDateTimeFormat._(JSObject _) implements JSObject {
  external factory _JSDateTimeFormat([JSAny? locales, JSAny? options]);
  external JSString format(JSNumber date);
  external JSArray<_JSDateTimeFormatPart> formatToParts(JSNumber date);
  external _JSResolvedOptions resolvedOptions();
}

extension type _JSDateTimeFormatPart._(JSObject _) implements JSObject {
  external JSString get type;
  external JSString get value;
}

extension type _JSResolvedOptions._(JSObject _) implements JSObject {
  external JSAny? get timeZone;
  external JSAny? get timeZoneName;
}

/// An Intl.DateTimeFormat.
final class _IntlDateTimeFormat implements IntlDateTimeFormat {
  final _JSDateTimeFormat _format;

  _IntlDateTimeFormat(this._format);

  @override
  String Format(int milliseconds) => _format.format(milliseconds.toJS).toDart;

  @override
  List<IntlDateTimeFormatPart> FormatToParts(int milliseconds) => [
        for (final part in _format.formatToParts(milliseconds.toJS).toDart)
          (Type: part.type.toDart, Value: part.value.toDart),
      ];

  @override
  String? get ResolvedTimeZone => _StringOrNull(_format.resolvedOptions().timeZone);

  @override
  String? get ResolvedTimeZoneName => _StringOrNull(_format.resolvedOptions().timeZoneName);
}

String? _StringOrNull(JSAny? value) => value != null && value.isA<JSString>() ? (value as JSString).toDart : null;

/// globalThis[name1][name2]..., or null if any of them is missing or not an object.
JSAny? _GetGlobal(List<String> names) {
  JSAny? current = globalContext;
  for (final name in names) {
    if (current == null || !(current.isA<JSObject>() || current.typeofEquals('function'))) {
      return null;
    }
    current = (current as JSObject).getProperty<JSAny?>(name.toJS);
  }
  return current;
}

@internal
bool IsWindowsRuntime() => false;

/// Node's process.env.TZ (browsers have none).
@internal
String? ReadHostTZ() {
  try {
    return _StringOrNull(_GetGlobal(['process', 'env', 'TZ']));
  } catch (_) {
    return null;
  }
}

@internal
(String, IWindowsTimeZoneApi)? CreateFfiWindowsTimeZoneApi() => null;

@internal
String? IcuCanonicalTimeZoneId(String id) => null;

@internal
bool IntlIsAvailable() {
  try {
    final dateTimeFormat = _GetGlobal(['Intl', 'DateTimeFormat']);
    return dateTimeFormat != null && dateTimeFormat.typeofEquals('function');
  } catch (_) {
    return false;
  }
}

/// new Intl.DateTimeFormat(locale, options). Throws (a RangeError, from JavaScript) for an unknown time zone.
@internal
IntlDateTimeFormat NewIntlDateTimeFormat(String? locale, Map<String, Object> options) {
  // No locale: an empty list (the host's default locale), as JavaScript's undefined would be; null throws a TypeError.
  return _IntlDateTimeFormat(_JSDateTimeFormat(locale == null ? JSArray<JSString>() : locale.toJS, options.jsify()));
}

/// Intl.supportedValuesOf("timeZone"), or null where the host doesn't have it.
@internal
List<String>? IntlSupportedTimeZones() {
  try {
    final intl = _GetGlobal(['Intl']);
    final supportedValuesOf = _GetGlobal(['Intl', 'supportedValuesOf']);
    if (intl == null || supportedValuesOf == null || !supportedValuesOf.typeofEquals('function')) {
      return null;
    }
    final values = (intl as JSObject).callMethod<JSArray<JSString>>('supportedValuesOf'.toJS, 'timeZone'.toJS);
    return [for (final value in values.toDart) value.toDart];
  } catch (_) {
    return null;
  }
}

/// Node's process.versions.tz, or null.
@internal
String? GetProcessTzVersion() {
  try {
    return _StringOrNull(_GetGlobal(['process', 'versions', 'tz']));
  } catch (_) {
    return null;
  }
}

@internal
IHostSystemTimeZones? CreateTzifSystemTimeZones() => null;

/// Intl.DateTimeFormat().resolvedOptions().timeZone, or null.
@internal
String? GetHostLocalTimeZoneId() {
  try {
    return IntlIsAvailable() ? _StringOrNull(_JSDateTimeFormat().resolvedOptions().timeZone) : null;
  } catch (_) {
    return null;
  }
}
