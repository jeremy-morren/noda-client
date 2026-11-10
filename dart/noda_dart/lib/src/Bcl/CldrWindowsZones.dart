// noda_dart: new code (noda-js's Bcl/CldrWindowsZones.ts). Windows time zone IDs mapped to tzdb zones by CLDR.

import '../DateTimeZone.dart';
import '../IDateTimeZoneProvider.dart';
import '../TimeZones/Cldr/MapZone.dart';
import '../TimeZones/Cldr/WindowsZones.dart';
import 'CldrWindowsZones.generated.dart';

/// One `<mapZone>` element of CLDR's windowsZones data.
typedef WindowsZonesDataMapZone = ({String WindowsId, String Territory, List<String> TzdbIds});

/// CLDR windowsZones data (`CldrWindowsZones.generated.dart`).
final class WindowsZonesData {
  final String Version;
  final String TzdbVersion;
  final String WindowsVersion;
  final List<WindowsZonesDataMapZone> MapZones;

  const WindowsZonesData(
      {required this.Version, required this.TzdbVersion, required this.WindowsVersion, required this.MapZones});
}

final WindowsZones _windowsZones = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(
  cldrWindowsZones.Version,
  cldrWindowsZones.TzdbVersion,
  cldrWindowsZones.WindowsVersion,
  [for (var z in cldrWindowsZones.MapZones) MapZone(z.WindowsId, z.Territory, z.TzdbIds)],
);

/// The Windows ↔ tzdb mapping from the bundled CLDR release.
WindowsZones GetCldrWindowsZones() => _windowsZones;

/// A provider that also accepts Windows zone IDs, mapped to their CLDR primary tzdb zones.
final class WindowsIdDateTimeZoneProvider implements IDateTimeZoneProvider {
  final IDateTimeZoneProvider _provider;
  final WindowsZones _mapping;
  List<String>? _ids;

  /// Wraps [provider], mapping Windows IDs by [mapping] (by default, [GetCldrWindowsZones]).
  WindowsIdDateTimeZoneProvider(IDateTimeZoneProvider provider, [WindowsZones? mapping])
      : _provider = provider,
        _mapping = mapping ?? GetCldrWindowsZones();

  @override
  String get VersionId => '${_provider.VersionId} + CLDR windowsZones ${_mapping.Version}';

  /// The wrapped provider's IDs plus the mapped Windows IDs (so patterns can parse them), in ordinal order.
  @override
  List<String> get Ids {
    var ids = _ids;
    if (ids == null) {
      final set = <String>{..._provider.Ids};
      _mapping.PrimaryMapping.forEach((windowsId, tzdbId) {
        if (_provider.GetZoneOrNull(tzdbId) != null) {
          set.add(windowsId);
        }
      });
      // compareTo is ordinal (UTF-16 code units).
      ids = _ids = List<String>.unmodifiable(set.toList()..sort((a, b) => a.compareTo(b)));
    }
    return ids;
  }

  @override
  DateTimeZone GetSystemDefault() => _provider.GetSystemDefault();

  @override
  DateTimeZone? GetZoneOrNull(String id) {
    final zone = _provider.GetZoneOrNull(id);
    if (zone != null) {
      return zone;
    }
    final tzdbId = _mapping.PrimaryMapping[id];
    return tzdbId == null ? null : _provider.GetZoneOrNull(tzdbId);
  }

  @override
  DateTimeZone operator [](String id) {
    final zone = GetZoneOrNull(id);
    if (zone == null) {
      return _provider[id];
    }
    return zone;
  }

  /// The Windows ID CLDR maps to the given tzdb zone (for the "001" territory), if any.
  String? WindowsIdForTzdbId(String tzdbId) {
    for (final mapZone in _mapping.MapZones) {
      if (mapZone.Territory == MapZone.PrimaryTerritory && mapZone.TzdbIds.contains(tzdbId)) {
        return mapZone.WindowsId;
      }
    }
    return null;
  }
}
