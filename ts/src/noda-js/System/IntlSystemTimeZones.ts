// noda-js: new code. The host's Intl zones, for noda-js/system without Windows' data (Windows IDs on a Windows runtime).

import { NewInvalidOperationException, SystemDateTimeZone } from "../internal.ts";
import type { InvalidOperationException } from "../internal.ts";
import { IsWindowsRuntime } from "./Host.ts";
import { GetIntlLocalId, GetIntlSupportedTimeZones, GetIntlTimeZoneVersion, IntlCanonicalTimeZoneId, IsIntlAvailable, IsIntlTimeZoneId } from "./IntlTimeZone.ts";
import { GetTZEnvironmentVariable } from "../Utility/TimeZoneEnvironment.ts";
import { GetMappedWindowsIds, GetWindowsIdMappingVersion, TryConvertIanaIdToWindowsId, TryConvertWindowsIdToIanaId } from "./WindowsIdMapping.ts";

let forHost: IntlSystemTimeZones | undefined;

/** The host's Intl time zones, with Windows or IANA IDs. @internal */
export class IntlSystemTimeZones {
  private _windowsIds: readonly string[] | undefined;
  private _systemDefault: SystemDateTimeZone | null = null;

  /** @throws {InvalidOperationException} The host has no Intl.DateTimeFormat. */
  constructor(readonly UseWindowsIds: boolean) {
    if (!IsIntlAvailable()) {
      throw NewInvalidOperationException(
        "noda-js/system needs the host's Intl.DateTimeFormat (with time zone support) where it can't read Windows' time zones, " +
          "and it isn't available. Use the bundled tzdb (noda-js/tzdb/bundled) instead.",
      );
    }
  }

  /** @throws {InvalidOperationException} The host has no Intl.DateTimeFormat. */
  static ForHost(): IntlSystemTimeZones {
    return (forHost ??= new IntlSystemTimeZones(IsWindowsRuntime()));
  }

  /** E.g. "Intl: 2025b". */
  get VersionId(): string {
    const version = `Intl: ${GetIntlTimeZoneVersion()}`;
    return this.UseWindowsIds ? `${version} (Windows IDs from CLDR windowsZones ${GetWindowsIdMappingVersion()})` : version;
  }

  /** The supported (or mapped Windows) IDs, plus the host's default zone's ID (hosts often don't list "UTC"). */
  GetIds(): readonly string[] {
    const ids = new Set<string>(this.UseWindowsIds ? this.GetWindowsIds() : GetSupportedIds());
    const local = this.GetSystemDefaultId();
    if (local !== null && this.FindZoneIds(local) !== null) {
      ids.add(local);
    }
    return [...ids];
  }

  /** The zone with the given ID (with Windows IDs, a mapped IANA ID too, as .NET 6+ accepts), or null. */
  ForId(id: string): SystemDateTimeZone | null {
    const ids = this.FindZoneIds(id);
    return ids === null ? null : SystemDateTimeZone.FromIntl(ids.Id, ids.IanaId);
  }

  /** The zone's ID and the IANA ID of its rules, without building the zone; null if there's none. */
  private FindZoneIds(id: string): { readonly Id: string; readonly IanaId: string } | null {
    if (!this.UseWindowsIds) {
      return IsIntlTimeZoneId(id) ? { Id: id, IanaId: id } : null;
    }
    const windows = TryConvertWindowsIdToIanaId(id);
    if (windows !== null && this.GetWindowsIds().indexOf(windows.WindowsId) !== -1) {
      return { Id: windows.WindowsId, IanaId: windows.IanaId };
    }
    if (IsIntlTimeZoneId(id) && (TryConvertIanaIdToWindowsId(id) !== null || id === this.GetSystemDefaultId())) {
      return { Id: id, IanaId: id };
    }
    return null;
  }

  /** The ID of the zone TZ names (UTC if none), else of the host's default zone; null if there's none. */
  GetSystemDefaultId(): string | null {
    const tz = GetTZEnvironmentVariable();
    if (tz !== null) {
      return this.ResolveId(tz) ?? this.ResolveId(this.UseWindowsIds ? "UTC" : "Etc/UTC") ?? (this.UseWindowsIds ? null : "Etc/UTC");
    }
    const local = GetIntlLocalId();
    if (local === null || !this.UseWindowsIds) {
      return local;
    }
    const windowsId = TryConvertIanaIdToWindowsId(local);
    return windowsId !== null && this.GetWindowsIds().indexOf(windowsId) !== -1 ? windowsId : local;
  }

  /** The ID, as one of {@link IntlSystemTimeZones.GetIds}, of the zone an ID names; null if none. */
  ResolveId(id: string): string | null {
    if (this.UseWindowsIds) {
      const windows = TryConvertWindowsIdToIanaId(id);
      if (windows !== null && this.GetWindowsIds().indexOf(windows.WindowsId) !== -1) {
        return windows.WindowsId;
      }
      const windowsId = IsIntlTimeZoneId(id) ? TryConvertIanaIdToWindowsId(id) : null;
      return windowsId !== null && this.GetWindowsIds().indexOf(windowsId) !== -1 ? windowsId : null;
    }
    if (!IsIntlTimeZoneId(id)) {
      return null;
    }
    // (Etc/UTC as is: hosts canonicalize it to "UTC", or list neither.)
    return GetSupportedIds().indexOf(id) !== -1 || id === "Etc/UTC" ? id : IntlCanonicalTimeZoneId(id);
  }

  /** The host's default zone (cached while it doesn't change), or null. */
  ForSystemDefault(): SystemDateTimeZone | null {
    const id = this.GetSystemDefaultId();
    if (id === null) {
      return null;
    }
    let current = this._systemDefault;
    if (current?.Id !== id) {
      current = this.ForId(id);
      this._systemDefault = current;
    }
    return current;
  }

  /** The Windows IDs whose primary IANA zone the host supports. */
  private GetWindowsIds(): readonly string[] {
    if (this._windowsIds === undefined) {
      const ids: string[] = [];
      for (const windowsId of GetMappedWindowsIds()) {
        const mapping = TryConvertWindowsIdToIanaId(windowsId);
        if (mapping !== null && IsIntlTimeZoneId(mapping.IanaId)) {
          ids.push(windowsId);
        }
      }
      this._windowsIds = ids;
    }
    return this._windowsIds;
  }
}

function GetSupportedIds(): readonly string[] {
  return GetIntlSupportedTimeZones();
}

