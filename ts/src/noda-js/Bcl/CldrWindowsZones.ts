// noda-js: new code. The bundled CLDR windowsZones mapping (for the system source and the tzdb compiler).

import { MapZone, WindowsZones } from "../internal.ts";
import { cldrWindowsZones } from "./CldrWindowsZones.generated.ts";

/** CLDR windowsZones data, as written by tools/NodaJs.Tools (cldr). */
export interface WindowsZonesData {
  readonly Version: string;
  readonly TzdbVersion: string;
  readonly WindowsVersion: string;
  readonly MapZones: readonly { readonly WindowsId: string; readonly Territory: string; readonly TzdbIds: readonly string[] }[];
}

let windowsZones: WindowsZones | undefined;

/** The Windows ↔ tzdb mapping from the CLDR release bundled with noda-js. */
export function GetCldrWindowsZones(): WindowsZones {
  return (windowsZones ??= WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(
    cldrWindowsZones.Version,
    cldrWindowsZones.TzdbVersion,
    cldrWindowsZones.WindowsVersion,
    cldrWindowsZones.MapZones.map(z => new MapZone(z.WindowsId, z.Territory, [...z.TzdbIds])),
  ));
}
