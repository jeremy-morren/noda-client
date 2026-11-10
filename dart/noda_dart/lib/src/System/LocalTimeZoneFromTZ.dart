// noda_dart: new code (noda-js's LocalTimeZoneFromTZ.ts). TimeZoneInfo.Local from TZ, which .NET honours only on Unix
// and noda_dart on Windows too (see docs/Timezones.md).

import 'package:meta/meta.dart';

import '../Utility/TimeZoneEnvironment.dart';
import 'InvalidTimeZoneException.dart';
import 'TimeZoneInfo.dart';
import 'TimeZoneNotFoundException.dart';
import 'WindowsIdMapping.dart';

/// The parts of TimeZoneInfoCachedData these functions use.
@internal
abstract interface class ISystemTimeZoneLookup {
  List<TimeZoneInfo> GetSystemTimeZones();

  TimeZoneInfo FindSystemTimeZoneById(String id);

  TimeZoneInfo get Utc;
}

/// The local zone TZ names, or null if TZ isn't set. A TZ naming no zone means UTC, as for glibc and .NET on Unix.
@internal
TimeZoneInfo? GetLocalTimeZoneFromTZ(ISystemTimeZoneLookup lookup) {
  final tz = GetTZEnvironmentVariable();
  if (tz == null) {
    return null;
  }
  final id = ResolveTimeZoneInfoId(lookup, tz) ?? ResolveTimeZoneInfoId(lookup, 'UTC');
  return id == null ? lookup.Utc : lookup.FindSystemTimeZoneById(id);
}

/// The system zone ID an ID (such as TZ's) names: a Windows ID in the registry's case, or an IANA ID's Windows ID;
/// null if none.
@internal
String? ResolveTimeZoneInfoId(ISystemTimeZoneLookup lookup, String id) {
  try {
    // Read every zone first, so that a Windows ID matched case-insensitively comes back in the registry's case.
    lookup.GetSystemTimeZones();
    final zone = lookup.FindSystemTimeZoneById(id);
    if (!zone.HasIanaId || zone.Id.toUpperCase() == 'UTC') {
      return zone.Id;
    }
    // An IANA ID keeps its ID; the system zone's ID is its Windows ID.
    final windowsId = TryConvertIanaIdToWindowsId(id);
    return windowsId == null ? null : lookup.FindSystemTimeZoneById(windowsId).Id;
  } on TimeZoneNotFoundException {
    return null;
  } on InvalidTimeZoneException {
    return null;
  }
}
