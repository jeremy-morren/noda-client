// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/TimeZoneInfoReplacer.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: IDisposable is Dispose() (C#'s `using` is try/finally).

import 'package:noda_dart/src/System/TimeZoneInfo.dart';
import 'package:noda_dart/src/System/TimeZoneNotFoundException.dart';
import 'package:noda_dart/src/System/Windows/WindowsTimeZoneApi.dart';
import 'package:noda_dart/src/TimeZones/TimeZoneInfoInterceptor.dart';

/// Class used to temporarily replace the shim used by [TimeZoneInfoInterceptor],
/// for test purposes. On disposal, the original is restored.
final class TimeZoneInfoReplacer implements TimeZoneInfoInterceptorITimeZoneInfoShim {
  final TimeZoneInfoInterceptorITimeZoneInfoShim? _originalShim;
  final List<TimeZoneInfo> _zones;

  @override
  final TimeZoneInfo? Local;

  TimeZoneInfoReplacer._(this.Local, this._zones) : _originalShim = TimeZoneInfoInterceptor.Shim {
    TimeZoneInfoInterceptor.Shim = this;
  }

  static TimeZoneInfoReplacer Replace(TimeZoneInfo? local, List<TimeZoneInfo> allZones) =>
      TimeZoneInfoReplacer._(local, List.unmodifiable(allZones));

  @override
  TimeZoneInfo FindSystemTimeZoneById(String id) {
    for (final zone in _zones) {
      if (zone.Id == id) {
        return zone;
      }
    }
    throw TimeZoneNotFoundException('No such time zone: $id');
  }

  @override
  List<TimeZoneInfo> GetSystemTimeZones() => _zones;

  void Dispose() => TimeZoneInfoInterceptor.Shim = _originalShim;

  // noda_dart: the members noda_dart's shim adds (for SystemDateTimeZoneSource.Backend and VersionId).
  @override
  SystemTimeZoneBackend get Backend => 'ffi';

  @override
  String get Description => 'TimeZoneInfoReplacer';
}
