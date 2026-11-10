// noda-js: new code. TimeZoneInfo.Local from the TZ environment variable, on Windows too (unlike .NET).

import { IsNodaError } from "../internal.ts";
import { GetTZEnvironmentVariable } from "../Utility/TimeZoneEnvironment.ts";
import type { TimeZoneInfo } from "./TimeZoneInfo.ts";
import { TryConvertIanaIdToWindowsId } from "./WindowsIdMapping.ts";

/** The parts of TimeZoneInfo's static API (TimeZoneInfoCachedData) ResolveTimeZoneInfoId uses. @internal */
export interface ISystemTimeZoneLookup {
  GetSystemTimeZones(): readonly TimeZoneInfo[];
  FindSystemTimeZoneById(id: string): TimeZoneInfo;
}

/** The zone TZ names (UTC if it names none), or null if TZ isn't set. @internal */
export function GetLocalTimeZoneFromTZ(lookup: ISystemTimeZoneLookup & { readonly Utc: TimeZoneInfo }): TimeZoneInfo | null {
  const tz = GetTZEnvironmentVariable();
  if (tz === null) {
    return null;
  }
  const id = ResolveTimeZoneInfoId(lookup, tz) ?? ResolveTimeZoneInfoId(lookup, "UTC");
  return id === null ? lookup.Utc : lookup.FindSystemTimeZoneById(id);
}

/** The Windows ID (in the registry's case) a Windows or IANA ID names, or null. @internal */
export function ResolveTimeZoneInfoId(lookup: ISystemTimeZoneLookup, id: string): string | null {
  try {
    // Read every zone first, so a case-insensitive match comes back in the registry's case.
    lookup.GetSystemTimeZones();
    const zone = lookup.FindSystemTimeZoneById(id);
    if (!zone.HasIanaId || zone.Id.toUpperCase() === "UTC") {
      return zone.Id;
    }
    const windowsId = TryConvertIanaIdToWindowsId(id);
    return windowsId === null ? null : lookup.FindSystemTimeZoneById(windowsId).Id;
  } catch (e) {
    if (IsNodaError(e, "TimeZoneNotFoundException") || IsNodaError(e, "InvalidTimeZoneException")) {
      return null;
    }
    throw e;
  }
}
