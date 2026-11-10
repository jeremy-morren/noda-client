// noda_dart: new code. Platform access for the system time zone source, by conditional export (so the web never
// imports dart:io or dart:ffi, and native code never imports dart:js_interop). Each Host_*.dart has the same functions:
// IsWindowsRuntime, ReadHostTZ, CreateFfiWindowsTimeZoneApi, IcuCanonicalTimeZoneId, the Intl ones (web only),
// CreateTzifSystemTimeZones (native non-Windows) and GetHostLocalTimeZoneId (ignoring TZ).

export 'Host_stub.dart' if (dart.library.io) 'Host_io.dart' if (dart.library.js_interop) 'Host_web.dart';
