// noda-js: new code. Windows time zone IDs mapped to tzdb zones with CLDR's windowsZones.xml.

import { CreateReadOnlyList, MapZone, WindowsZones, type DateTimeZone, type IDateTimeZoneProvider } from "../internal.ts";
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

/** Wraps a provider (normally tzdb) so lookups also accept Windows IDs; zones keep their tzdb IDs. */
export class WindowsIdDateTimeZoneProvider implements IDateTimeZoneProvider {
  private _ids: readonly string[] | undefined;

  constructor(
    private readonly _provider: IDateTimeZoneProvider,
    private readonly _mapping: WindowsZones = GetCldrWindowsZones(),
  ) {}

  /** @inheritDoc */
  get VersionId(): string {
    return `${this._provider.VersionId} + CLDR windowsZones ${this._mapping.Version}`;
  }

  /** The wrapped provider's IDs plus the mapped Windows IDs, in ordinal order (patterns parse IDs from this list). */
  get Ids(): readonly string[] {
    if (this._ids === undefined) {
      const ids = new Set(this._provider.Ids);
      this._mapping.PrimaryMapping.forEach((tzdbId, windowsId) => {
        if (this._provider.GetZoneOrNull(tzdbId) !== null) {
          ids.add(windowsId);
        }
      });
      this._ids = CreateReadOnlyList(Array.from(ids).sort());
    }
    return this._ids;
  }

  /** @inheritDoc */
  GetSystemDefault(): DateTimeZone {
    return this._provider.GetSystemDefault();
  }

  /** @inheritDoc */
  GetZoneOrNull(id: string): DateTimeZone | null {
    const zone = this._provider.GetZoneOrNull(id);
    if (zone !== null) {
      return zone;
    }
    const tzdbId = this._mapping.PrimaryMapping.get(id);
    return tzdbId === undefined ? null : this._provider.GetZoneOrNull(tzdbId);
  }

  /** @inheritDoc */
  Get(id: string): DateTimeZone {
    const zone = this.GetZoneOrNull(id);
    if (zone === null) {
      return this._provider.Get(id);
    }
    return zone;
  }

  /** The Windows ID CLDR maps to the given tzdb zone (for the "001" territory), if any. */
  WindowsIdForTzdbId(tzdbId: string): string | null {
    for (const mapZone of this._mapping.MapZones) {
      if (mapZone.Territory === MapZone.PrimaryTerritory && mapZone.TzdbIds.indexOf(tzdbId) !== -1) {
        return mapZone.WindowsId;
      }
    }
    return null;
  }
}
