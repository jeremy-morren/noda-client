// noda-js: new code. Windows <-> IANA ID conversion with the bundled CLDR mapping (ICU's role in .NET).

import { MapZone } from "../internal.ts";
import { GetCldrWindowsZones } from "../Bcl/CldrWindowsZones.ts";
import { IntlCanonicalTimeZoneId } from "./IntlTimeZone.ts";

let ianaToWindows: Map<string, string> | undefined;
let canonicalIanaToWindows: Map<string, string> | undefined;

/** Every IANA ID in CLDR's mapping (any territory) → its Windows ID. */
function GetIanaToWindows(): Map<string, string> {
  if (ianaToWindows === undefined) {
    ianaToWindows = new Map<string, string>();
    for (const mapZone of GetCldrWindowsZones().MapZones) {
      for (const tzdbId of mapZone.TzdbIds) {
        if (!ianaToWindows.has(tzdbId)) {
          ianaToWindows.set(tzdbId, mapZone.WindowsId);
        }
      }
    }
  }
  return ianaToWindows;
}

/** The Windows ID for an IANA ID or alias (canonicalized with Intl, as ICU does), or null. @internal */
export function TryConvertIanaIdToWindowsId(ianaId: string): string | null {
  const direct = GetIanaToWindows().get(ianaId);
  if (direct !== undefined) {
    return direct;
  }
  const canonical = IntlCanonicalTimeZoneId(ianaId);
  if (canonical === null) {
    return null;
  }
  if (canonicalIanaToWindows === undefined) {
    canonicalIanaToWindows = new Map<string, string>();
    GetIanaToWindows().forEach((windowsId, tzdbId) => {
      const key = IntlCanonicalTimeZoneId(tzdbId);
      if (key !== null && !canonicalIanaToWindows!.has(key)) {
        canonicalIanaToWindows!.set(key, windowsId);
      }
    });
  }
  return canonicalIanaToWindows.get(canonical) ?? null;
}

/** The "001" IANA ID for a Windows ID (matched ignoring case), or null. @internal */
export function TryConvertWindowsIdToIanaId(windowsId: string): { readonly WindowsId: string; readonly IanaId: string } | null {
  const upper = windowsId.toUpperCase();
  for (const mapZone of GetCldrWindowsZones().MapZones) {
    if (mapZone.Territory === MapZone.PrimaryTerritory && mapZone.WindowsId.toUpperCase() === upper) {
      return { WindowsId: mapZone.WindowsId, IanaId: mapZone.TzdbIds[0]! };
    }
  }
  return null;
}

/** The Windows IDs with a primary ("001") mapping, in CLDR's order. @internal */
export function GetMappedWindowsIds(): readonly string[] {
  const ids: string[] = [];
  for (const mapZone of GetCldrWindowsZones().MapZones) {
    if (mapZone.Territory === MapZone.PrimaryTerritory) {
      ids.push(mapZone.WindowsId);
    }
  }
  return ids;
}

/** The version of the CLDR mapping. @internal */
export function GetWindowsIdMappingVersion(): string {
  return GetCldrWindowsZones().Version;
}
