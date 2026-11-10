// noda_dart: new code (noda-js's Bcl/CldrWindowsZones.ts). The bundled CLDR windowsZones mapping (for the system
// source and the tzdb compiler).

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
