// noda_dart: new code. The host's own (non-Windows) system zones: TZif files on native platforms, Intl on the web.

import 'package:meta/meta.dart';

import '../TimeZones/SystemDateTimeZone.dart';
import 'Host.dart' as host;
import 'IntlSystemTimeZones.dart';
import 'Windows/WindowsTimeZoneApi.dart';

/// The host's own time zones, with IANA IDs (Windows IDs for Intl on a Windows runtime).
@internal
abstract interface class IHostSystemTimeZones {
  /// Where the zones come from: "tzif" or "intl".
  SystemTimeZoneBackend get Backend;

  /// The source's VersionId: e.g. "Intl: 2025b" or "TZif: 2025b (/usr/share/zoneinfo)".
  String get VersionId;

  /// The IDs of the zones, plus the host's default zone's ID if that isn't one of them.
  List<String> GetIds();

  /// The zone with the given ID, or null if there isn't one.
  SystemDateTimeZone? ForId(String id);

  /// The current zone's ID: TZ's (resolved by [ResolveId]; UTC if it names no zone), else the host default's.
  String? GetSystemDefaultId();

  /// The ID in [GetIds] that an ID (such as TZ's) names, or null.
  String? ResolveId(String id);

  /// The host's default zone (cached while it doesn't change), or null if there isn't one.
  SystemDateTimeZone? ForSystemDefault();
}

/// The host's own time zones: TZif files on native non-Windows platforms, otherwise Intl. Throws [StateError] if none.
@internal
IHostSystemTimeZones HostSystemTimeZonesForHost() {
  return host.CreateTzifSystemTimeZones() ?? IntlSystemTimeZones.ForHost();
}
