// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/TimeZoneInfoInterceptor.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../System/TimeZoneInfo.Win32.dart';
import '../System/TimeZoneInfo.dart';
import '../System/Windows/WindowsTimeZoneApi.dart';

/// The shim to use for all the static methods.
///
/// noda_dart: null when the host can't read Windows' time zones; [_shimInitialized] is false until first use.
TimeZoneInfoInterceptorITimeZoneInfoShim? _shim;
bool _shimInitialized = false;

/// Interception for TimeZoneInfo static methods. These are still represented as
/// static methods in this class, but they're implemented via a replaceable shim, which
/// by default delegates to the static methods in TimeZoneInfo.
///
/// noda_dart: the default shim reads Windows' time zones through dart:ffi.
@internal
abstract final class TimeZoneInfoInterceptor {
  /// The shim to use for all the static methods. We don't care about thread safety here,
  /// beyond "it must be correct when used in production" - it's only ever changed in tests,
  /// which are single-threaded anyway.
  ///
  /// noda_dart: null if the host can't read Windows' time zones.
  static TimeZoneInfoInterceptorITimeZoneInfoShim? get Shim {
    if (!_shimInitialized) {
      final backend = FindWindowsTimeZoneApi();
      _shim = backend == null ? null : _TimeZoneInfoInterceptorBclShim(backend);
      _shimInitialized = true;
    }
    return _shim;
  }

  static set Shim(TimeZoneInfoInterceptorITimeZoneInfoShim? value) {
    _shim = value;
    _shimInitialized = true;
  }

  static TimeZoneInfo? get Local => _RequireShim().Local;

  static TimeZoneInfo FindSystemTimeZoneById(String id) => _RequireShim().FindSystemTimeZoneById(id);

  static List<TimeZoneInfo> GetSystemTimeZones() => _RequireShim().GetSystemTimeZones();

  static TimeZoneInfoInterceptorITimeZoneInfoShim _RequireShim() {
    final current = Shim;
    if (current == null) {
      throw StateError('There is no TimeZoneInfo on this host');
    }
    return current;
  }
}

/// TimeZoneInfoInterceptor.ITimeZoneInfoShim (Dart has no nested types).
@internal
abstract interface class TimeZoneInfoInterceptorITimeZoneInfoShim {
  TimeZoneInfo? get Local;

  TimeZoneInfo FindSystemTimeZoneById(String id);

  List<TimeZoneInfo> GetSystemTimeZones();

  /// noda_dart: where the zones come from (for SystemDateTimeZoneSource.Backend).
  SystemTimeZoneBackend get Backend;

  /// noda_dart: how they're read, for VersionId ("dart:ffi").
  String get Description;
}

/// Implementation that just delegates in a simple manner.
///
/// noda_dart: to the port of TimeZoneInfo's Windows implementation, over the host's Windows API.
final class _TimeZoneInfoInterceptorBclShim implements TimeZoneInfoInterceptorITimeZoneInfoShim {
  final WindowsTimeZoneApiBackend _backend;
  final TimeZoneInfoCachedData _data;

  _TimeZoneInfoInterceptorBclShim(this._backend) : _data = TimeZoneInfoCachedData(_backend.Api);

  @override
  TimeZoneInfo? get Local => _data.Local;

  @override
  TimeZoneInfo FindSystemTimeZoneById(String id) => _data.FindSystemTimeZoneById(id);

  @override
  List<TimeZoneInfo> GetSystemTimeZones() => _data.GetSystemTimeZones();

  @override
  SystemTimeZoneBackend get Backend => _backend.Backend;

  @override
  String get Description => _backend.Description;
}

/// A shim over a given Windows API (for tests: fake Windows data through the same code as the real thing).
@internal
TimeZoneInfoInterceptorITimeZoneInfoShim CreateWindowsTimeZoneInfoShim(WindowsTimeZoneApiBackend backend) {
  return _TimeZoneInfoInterceptorBclShim(backend);
}
