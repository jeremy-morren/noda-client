// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/Cldr/WindowsZones.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { MapZone, Preconditions, CreateReadOnlyList, CreateReadOnlyMap } from "../../internal.ts";
import type { IDateTimeZoneReader, IDateTimeZoneWriter } from "../../internal.ts";
import type { TzdbDateTimeZoneSource } from "../../internal.ts";
import { NewArgumentException, NewInvalidOperationException } from "../../internal.ts";

/**
 * Representation of the `<windowsZones>` element of CLDR supplemental data.
 *
 * See [the CLDR design proposal](http://cldr.unicode.org/development/development-process/design-proposals/extended-windows-olson-zid-mapping)
 * for more details of the structure of the file from which data is taken.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class WindowsZones {
  private readonly _version: string;

  /**
   * Gets the version of the Windows zones mapping data read from the original file.
   *
   * As with other IDs, this should largely be treated as an opaque string, but the current method for
   * generating this from the mapping file extracts a number from an element such as `<version number="$Revision: 7825 $"/>`.
   * This is a Subversion revision number, but that association should only be used for diagnostic curiosity, and never
   * assumed in code.
   */
  get Version(): string {
    return this._version;
  }

  private readonly _tzdbVersion: string;

  /**
   * Gets the TZDB version this Windows zone mapping data was created from.
   *
   * The CLDR mapping file usually lags behind the TZDB file somewhat - partly because the
   * mappings themselves don't always change when the time zone data does. For example, it's entirely
   * reasonable for a {@link TzdbDateTimeZoneSource} with a {@link TzdbDateTimeZoneSource.TzdbVersion | TzdbVersion} of
   * "2013b" to be supply a `WindowsZones` object with a `TzdbVersion` of "2012f".
   */
  get TzdbVersion(): string {
    return this._tzdbVersion;
  }

  private readonly _windowsVersion: string;

  /**
   * Gets the Windows time zone database version this Windows zone mapping data was created from.
   *
   * At the time of this writing, this is populated (by CLDR) from the registry key
   * HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones\TzVersion,
   * so "7dc0101" for example.
   */
  get WindowsVersion(): string {
    return this._windowsVersion;
  }

  private readonly _mapZones: readonly MapZone[];

  /**
   * Gets an immutable collection of mappings from Windows system time zones to
   * TZDB time zones.
   *
   * Each mapping consists of a single Windows time zone ID and a single
   * territory to potentially multiple TZDB IDs that are broadly equivalent to that Windows zone/territory
   * pair.
   *
   * Mappings for a single Windows system time zone can appear multiple times
   * in this list, in different territories. For example, "Central Standard Time"
   * maps to different TZDB zones in different countries (the US, Canada, Mexico) and
   * even within a single territory there can be multiple zones. Every Windows system time zone covered within
   * this collection has a "primary" entry with a territory code of "001" (which is the value of
   * {@link MapZone.PrimaryTerritory}) and a single corresponding TZDB zone.
   *
   * This collection is not guaranteed to cover every Windows time zone. Some zones may be unmappable
   * (such as "Mid-Atlantic Standard Time") and there can be a delay between a new Windows time zone being introduced
   * and it appearing in CLDR, ready to be used by Noda Time. (There's also bound to be a delay between it appearing
   * in CLDR and being used in your production system.) In practice however, you're unlikely to wish to use a time zone
   * which isn't covered here.
   */
  get MapZones(): readonly MapZone[] {
    return this._mapZones;
  }

  private readonly _primaryMapping: ReadonlyMap<string, string>;

  /**
   * Gets an immutable dictionary of primary mappings, from Windows system time zone ID
   * to TZDB zone ID. This corresponds to the "001" territory which is present for every zone
   * within the mapping file.
   *
   * Each value in the dictionary is a canonical ID in CLDR, but it may not be canonical
   * in TZDB. For example, the ID corresponding to "India Standard Time" is "Asia/Calcutta", which
   * is canonical in CLDR but is an alias in TZDB for "Asia/Kolkata". To obtain a canonical TZDB
   * ID, use {@link TzdbDateTimeZoneSource.CanonicalIdMap}.
   */
  get PrimaryMapping(): ReadonlyMap<string, string> {
    return this._primaryMapping;
  }

  /** @internal */
  static NewVersionTzdbVersionWindowsVersionMapZones(
    version: string,
    tzdbVersion: string,
    windowsVersion: string,
    mapZones: readonly MapZone[],
  ): WindowsZones {
    return new WindowsZones(
      Preconditions.CheckNotNull(version, "version"),
      Preconditions.CheckNotNull(tzdbVersion, "tzdbVersion"),
      Preconditions.CheckNotNull(windowsVersion, "windowsVersion"),
      [...Preconditions.CheckNotNull(mapZones, "mapZones")],
    );
  }

  private constructor(version: string, tzdbVersion: string, windowsVersion: string, mapZones: readonly MapZone[]) {
    this._version = version;
    this._tzdbVersion = tzdbVersion;
    this._windowsVersion = windowsVersion;
    this._mapZones = CreateReadOnlyList(mapZones);
    // mapZones.Where(z => z.Territory == MapZone.PrimaryTerritory).ToDictionary(z => z.WindowsId, z => z.TzdbIds.Single())
    const primaryMapping = new Map<string, string>();
    for (const z of mapZones) {
      if (z.Territory === MapZone.PrimaryTerritory) {
        if (z.TzdbIds.length !== 1) {
          throw NewInvalidOperationException(z.TzdbIds.length === 0 ? "Sequence contains no elements" : "Sequence contains more than one element");
        }
        if (primaryMapping.has(z.WindowsId)) {
          throw NewArgumentException(`An item with the same key has already been added. Key: ${z.WindowsId}`);
        }
        primaryMapping.set(z.WindowsId, z.TzdbIds[0]!);
      }
    }
    this._primaryMapping = CreateReadOnlyMap(primaryMapping);
  }

  /** @internal */
  static Read(reader: IDateTimeZoneReader): WindowsZones {
    const version = reader.ReadString();
    const tzdbVersion = reader.ReadString();
    const windowsVersion = reader.ReadString();
    const count = reader.ReadCount();
    const mapZones = new Array<MapZone>(count);
    for (let i = 0; i < count; i++) {
      mapZones[i] = MapZone.Read(reader);
    }
    return new WindowsZones(version, tzdbVersion, windowsVersion, mapZones);
  }

  /** @internal */
  Write(writer: IDateTimeZoneWriter): void {
    writer.WriteString(this.Version);
    writer.WriteString(this.TzdbVersion);
    writer.WriteString(this.WindowsVersion);
    writer.WriteCount(this.MapZones.length);
    for (const mapZone of this.MapZones) {
      mapZone.Write(writer);
    }
  }
}
