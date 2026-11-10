// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/BclDateTimeZoneSource.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: BclDateTimeZoneSource, renamed as in noda-js.

import 'package:meta/meta.dart';

import '../System/IHostSystemTimeZones.dart';
import '../System/TimeZoneNotFoundException.dart';
import '../System/Windows/WindowsTimeZoneApi.dart';
import 'IDateTimeZoneSource.dart';
import 'SystemDateTimeZone.dart';
import 'TimeZoneInfoInterceptor.dart';

/// Provides an implementation of [IDateTimeZoneSource] that loads data from the host system's time zones
/// (NodaTime's BclDateTimeZoneSource, which loads them from the BCL `TimeZoneInfo` class).
///
/// All calls to [ForId] return instances of [SystemDateTimeZone], including for fixed-offset IDs (i.e. "UTC" and
/// "UTC+/-Offset").
///
/// noda_dart: the zones are Windows' (Windows IDs, IANA IDs accepted too), the OS's TZif files, or the web host's
/// Intl (IANA IDs). TZ is honoured everywhere. See docs/Timezones.md.
///
/// This type maintains no state, and all members are thread-safe. See the thread safety section of the user guide for
/// more information.
final class SystemDateTimeZoneSource implements IDateTimeZoneSource {
  /// noda_dart: TimeZoneInfo on this host, or null if it has none (then [_host] is set).
  final TimeZoneInfoInterceptorITimeZoneInfoShim? _shim;

  /// noda_dart: the TZif or Intl zones (noda-js's _intl).
  final IHostSystemTimeZones? _host;

  /// Constructs a new instance. This is rarely useful in application code, as this class has no state of its own.
  /// Most application code should use `SystemDateTimeZoneProvider` (from package:noda_dart/system.dart).
  ///
  /// Throws [StateError] if the host has no time zone data.
  factory SystemDateTimeZoneSource() {
    final shim = TimeZoneInfoInterceptor.Shim;
    return SystemDateTimeZoneSource._(shim, shim == null ? HostSystemTimeZonesForHost() : null);
  }

  SystemDateTimeZoneSource._(this._shim, this._host);

  /// noda_dart: a source over the given TZif or Intl zones (for tests).
  @internal
  factory SystemDateTimeZoneSource.NewHost(IHostSystemTimeZones host) => SystemDateTimeZoneSource._(null, host);

  /// noda_dart: where the zones come from: "ffi" (Windows), "tzif" or "intl".
  @internal
  SystemTimeZoneBackend get Backend {
    final shim = _shim;
    if (shim != null) {
      return shim.Backend;
    }
    return _host!.Backend;
  }

  /// Returns the IDs of all system time zones.
  ///
  /// Returns the IDs available from this source.
  @override
  Iterable<String> GetIds() {
    final host = _host;
    if (host != null) {
      return host.GetIds();
    }
    // Always include the local time zone, since Mono may not include it in the list of system time zones, even
    // though it allows the Id to be passed to FindSystemTimeZoneById().
    // See https://github.com/nodatime/nodatime/issues/235.
    return <String>{
      ..._shim!.GetSystemTimeZones().map((zone) => zone.Id),
      ..._GetTimeZoneInfoLocalIdOrEmpty(),
    }.toList();
  }

  /// Returns an enumerable containing a singleton element of the Id of the local time zone
  /// (`TimeZoneInfo.Local.Id`), unless the local time zone is not available, or not a system time zone, in
  /// which case returns an empty enumerable.
  List<String> _GetTimeZoneInfoLocalIdOrEmpty() {
    // This complexity is entirely to handle Mono, which fails quite badly at this in some cases.
    try {
      // May throw TimeZoneNotFoundException, particularly on Mono/Windows.
      // See https://bugzilla.xamarin.com/show_bug.cgi?id=11817
      final local = _shim!.Local;

      if (local != null) {
        // https://github.com/nodatime/nodatime/issues/235#issuecomment-80932079
        // Make sure we can look it up again, as there are legitimate cases where the local time zone is not
        // a system time zone.  If not, this also throws TimeZoneNotFoundException.
        _shim.FindSystemTimeZoneById(local.Id);

        return [local.Id];
      }
    } on TimeZoneNotFoundException {
      //
    }
    return const [];
  }

  /// This source returns a string such as "TimeZoneInfo: 3.5.0.0" corresponding to the version of the assembly
  /// containing TimeZoneInfo.
  ///
  /// noda_dart: "TimeZoneInfo: Windows (dart:ffi)", "TZif: 2025b (/usr/share/zoneinfo)" or "Intl: 2025b"
  /// ("Intl: unknown" where the host doesn't say).
  @override
  String get VersionId {
    final host = _host;
    return host != null ? host.VersionId : 'TimeZoneInfo: Windows (${_shim!.Description})';
  }

  /// Creates a new instance of [SystemDateTimeZone] from the TimeZoneInfo with the given ID. The ID must be a known
  /// system time zone ID.
  ///
  /// [id]: The ID of the system time zone to convert
  ///
  /// Throws [ArgumentError] if the given zone doesn't exist.
  ///
  /// Returns the Noda Time representation of the given BCL time zone
  @override
  SystemDateTimeZone ForId(String id) {
    final host = _host;
    if (host != null) {
      final zone = host.ForId(id);
      if (zone == null) {
        throw ArgumentError('$id is not a system time zone ID', 'id');
      }
      return zone;
    }
    try {
      final zone = _shim!.FindSystemTimeZoneById(id);
      return SystemDateTimeZone.FromTimeZoneInfo(zone);
    } on TimeZoneNotFoundException {
      throw ArgumentError('$id is not a system time zone ID', 'id');
    }
  }

  // Note: if TimeZoneInfo.Local returns a null reference, we'll return a null reference here as well.
  // However, we *don't* attempt to validate that a non-null reference has a valid ID that can be looked up.
  // We'll let the DateTimeZoneCache do that for us. (We get a DateTimeZoneNotFoundException either way.)

  /// Returns this source's ID for the system default time zone.
  ///
  /// noda_dart: the zone TZ names if set (UTC if it names none, as Node, Python and .NET on Unix do), else the
  /// host's; null if there's none. [SystemDateTimeZone.ForSystemDefault] always agrees.
  @override
  String? GetSystemDefaultId() {
    final host = _host;
    return host != null ? host.GetSystemDefaultId() : GetTimeZoneInfoSystemDefaultId(_shim!);
  }
}

/// noda_dart: TimeZoneInfo.Local's ID (TZ's zone if set), shared with SystemDateTimeZone.ForSystemDefault.
@internal
String? GetTimeZoneInfoSystemDefaultId(TimeZoneInfoInterceptorITimeZoneInfoShim shim) {
  return shim.Local?.Id;
}
