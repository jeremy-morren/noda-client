// noda_dart: new code (noda-js's WindowsIdMapping.ts). Windows ↔ IANA IDs by CLDR, for .NET's ICU-based conversions.

import 'package:meta/meta.dart';

import '../Bcl/CldrWindowsZones.dart';
import '../TimeZones/Cldr/MapZone.dart';
import 'IntlTimeZone.dart';

Map<String, String>? _ianaToWindows;
Map<String, String>? _canonicalIanaToWindows;

/// Every IANA ID in CLDR's mapping (any territory) → its Windows ID.
Map<String, String> _GetIanaToWindows() {
  var ianaToWindows = _ianaToWindows;
  if (ianaToWindows == null) {
    ianaToWindows = <String, String>{};
    for (final mapZone in GetCldrWindowsZones().MapZones) {
      for (final tzdbId in mapZone.TzdbIds) {
        ianaToWindows.putIfAbsent(tzdbId, () => mapZone.WindowsId);
      }
    }
    _ianaToWindows = ianaToWindows;
  }
  return ianaToWindows;
}

/// The Windows ID CLDR maps an IANA ID to (canonicalized first, so aliases map too), as ICU does for .NET; or null.
@internal
String? TryConvertIanaIdToWindowsId(String ianaId) {
  final direct = _GetIanaToWindows()[ianaId];
  if (direct != null) {
    return direct;
  }
  final canonical = IntlCanonicalTimeZoneId(ianaId);
  if (canonical == null) {
    return null;
  }
  var canonicalIanaToWindows = _canonicalIanaToWindows;
  if (canonicalIanaToWindows == null) {
    canonicalIanaToWindows = <String, String>{};
    _GetIanaToWindows().forEach((tzdbId, windowsId) {
      final key = IntlCanonicalTimeZoneId(tzdbId);
      if (key != null) {
        canonicalIanaToWindows!.putIfAbsent(key, () => windowsId);
      }
    });
    _canonicalIanaToWindows = canonicalIanaToWindows;
  }
  return canonicalIanaToWindows[canonical];
}

/// The IANA ID CLDR maps a Windows ID (matched case-insensitively) to for territory "001", or null.
@internal
({String WindowsId, String IanaId})? TryConvertWindowsIdToIanaId(String windowsId) {
  final upper = windowsId.toUpperCase();
  for (final mapZone in GetCldrWindowsZones().MapZones) {
    if (mapZone.Territory == MapZone.PrimaryTerritory && mapZone.WindowsId.toUpperCase() == upper) {
      return (WindowsId: mapZone.WindowsId, IanaId: mapZone.TzdbIds[0]);
    }
  }
  return null;
}

/// The Windows IDs with a primary ("001") mapping, in CLDR's order.
@internal
List<String> GetMappedWindowsIds() {
  final ids = <String>[];
  for (final mapZone in GetCldrWindowsZones().MapZones) {
    if (mapZone.Territory == MapZone.PrimaryTerritory) {
      ids.add(mapZone.WindowsId);
    }
  }
  return ids;
}

/// The version of the CLDR mapping.
@internal
String GetWindowsIdMappingVersion() {
  return GetCldrWindowsZones().Version;
}
