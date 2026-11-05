// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/TzdbDateTimeZoneSource.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { ArgumentError, InvalidNodaDataError, MapZone, Preconditions, CreateReadOnlyList, CreateReadOnlyMap, TzdbStreamData } from "../internal.ts";
import type {
  DateTimeZone,
  IDateTimeZoneSource,
  TzdbZone1970Location,
  TzdbZoneLocation,
  WindowsZones,
} from "../internal.ts";

/**
 * Provides an implementation of {@link IDateTimeZoneSource} that loads data originating from the
 * [tz database](https://www.iana.org/time-zones) (also known as the IANA Time Zone database, or zoneinfo
 * or Olson database).
 *
 * All calls to {@link TzdbDateTimeZoneSource.ForId} for fixed-offset IDs advertised by the source (i.e. "UTC" and "UTC+/-Offset")
 * will return zones equal to those returned by {@link DateTimeZone.ForOffset}.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class TzdbDateTimeZoneSource implements IDateTimeZoneSource {
  // Not ported here: Default (and its DefaultHolder). The source initialised from the bundled data is
  // `tzdbSource` in the noda-js/tzdb/bundled entry point, so that this module carries no data.

  /**
   * Original source data - we delegate to this to create actual DateTimeZone instances,
   * and for windows mappings.
   */
  private readonly _source: TzdbStreamData;

  /**
   * Composite version ID including TZDB and Windows mapping version strings.
   */
  private readonly _version: string;

  private _tzdbToWindowsId: ReadonlyMap<string, string> | undefined;
  private _windowsToTzdbId: ReadonlyMap<string, string> | undefined;

  private readonly _aliases: ReadonlyMap<string, readonly string[]>;

  /**
   * Gets a lookup from canonical time zone ID (e.g. "Europe/London") to a group of aliases for that time zone
   * (e.g. {"Europe/Belfast", "Europe/Guernsey", "Europe/Jersey", "Europe/Isle_of_Man", "GB", "GB-Eire"}).
   *
   * The group of values for a key never contains the canonical ID, only aliases. Any time zone
   * ID which is itself an alias or has no aliases linking to it will not be present in the lookup.
   * The aliases within a group are returned in alphabetical (ordinal) order.
   *
   * noda-js: NodaTime's `ILookup<string, string>` is a `ReadonlyMap` from canonical ID to its aliases; unlike
   * an ILookup, `get()` returns `undefined` (not an empty sequence) for an ID with no aliases.
   */
  get Aliases(): ReadonlyMap<string, readonly string[]> {
    return this._aliases;
  }

  /**
   * Returns a read-only map from time zone ID to the canonical ID. For example, the key "Europe/Jersey"
   * would be associated with the value "Europe/London".
   *
   * This map contains an entry for every ID returned by {@link TzdbDateTimeZoneSource.GetIds}, where
   * canonical IDs map to themselves.
   */
  get CanonicalIdMap(): ReadonlyMap<string, string> {
    return (this._canonicalIdMap ??= CreateReadOnlyMap(this._source.TzdbIdMap));
  }
  private _canonicalIdMap: ReadonlyMap<string, string> | undefined;

  /**
   * Gets a read-only list of zone locations known to this source, or null if the original source data
   * does not include zone locations.
   *
   * Every zone location's time zone ID is guaranteed to be valid within this source (assuming the source
   * has been validated).
   */
  get ZoneLocations(): readonly TzdbZoneLocation[] | null {
    const locations = this._source.ZoneLocations;
    return locations === null ? null : (this._zoneLocations ??= CreateReadOnlyList(locations));
  }
  private _zoneLocations: readonly TzdbZoneLocation[] | undefined;
  private _zone1970Locations: readonly TzdbZone1970Location[] | undefined;

  /**
   * Gets a read-only list of "zone 1970" locations known to this source, or null if the original source data
   * does not include zone locations.
   *
   * This location data differs from {@link TzdbDateTimeZoneSource.ZoneLocations} in two important respects:
   * - Where multiple similar zones exist but only differ in transitions before 1970,
   *   this location data chooses one zone to be the canonical "post 1970" zone.
   * - This location data can represent multiple ISO-3166 country codes in a single entry. For example,
   *   the entry corresponding to "Europe/London" includes country codes GB, GG, JE and IM (Britain,
   *   Guernsey, Jersey and the Isle of Man, respectively).
   *
   * Every zone location's time zone ID is guaranteed to be valid within this source (assuming the source
   * has been validated).
   */
  get Zone1970Locations(): readonly TzdbZone1970Location[] | null {
    const locations = this._source.Zone1970Locations;
    return locations === null ? null : (this._zone1970Locations ??= CreateReadOnlyList(locations));
  }

  /**
   * This source returns a string such as "TZDB: 2013b (mapping: 8274)" corresponding to the versions of the tz
   * database and the CLDR Windows zones mapping file.
   *
   * Note that there is no need to parse this string to extract any of the above information, as it is available
   * directly from the {@link TzdbDateTimeZoneSource.TzdbVersion} and {@link WindowsZones.Version} properties.
   */
  get VersionId(): string {
    return `TZDB: ${this._version}`;
  }

  // Not ported: FromStream(Stream) (no streams in JS); use fromBytes or fromBase64.

  /**
   * Creates an instance from the bytes of a file in the custom Noda Time format (an `.nzd` file).
   *
   * See the user guide for instructions on how to generate an updated time zone database file from a copy of the
   * (textual) tz database.
   *
   * noda-js: replaces NodaTime's `FromStream(Stream)`.
   * @param bytes The time zone data
   * @returns A `TzdbDateTimeZoneSource` providing information from the given data.
   * @throws {InvalidNodaDataError} The data is invalid time zone data, or data which cannot
   * be read by this version of Noda Time.
   */
  static FromBytes(bytes: Uint8Array): TzdbDateTimeZoneSource {
    Preconditions.CheckNotNull(bytes, "bytes");
    return new TzdbDateTimeZoneSource(TzdbStreamData.FromBytes(bytes));
  }

  /**
   * Creates an instance from the base64 encoding of a file in the custom Noda Time format (an `.nzd` file).
   *
   * noda-js: replaces NodaTime's `FromStream(Stream)`.
   * @param text The base64-encoded time zone data
   * @returns A `TzdbDateTimeZoneSource` providing information from the given data.
   * @throws {InvalidNodaDataError} The data is invalid time zone data, or data which cannot
   * be read by this version of Noda Time.
   */
  static FromBase64(text: string): TzdbDateTimeZoneSource {
    Preconditions.CheckNotNull(text, "text");
    return TzdbDateTimeZoneSource.FromBytes(DecodeBase64(text));
  }

  /** @internal */
  static NewSource(source: TzdbStreamData): TzdbDateTimeZoneSource {
    return new TzdbDateTimeZoneSource(source);
  }

  private constructor(source: TzdbStreamData) {
    Preconditions.CheckNotNull(source, "source");
    this._source = source;
    const aliases = new Map<string, string[]>();
    const aliasPairs = [...this.CanonicalIdMap].filter(([key, value]) => key !== value).sort(([a], [b]) => CompareOrdinal(a, b));
    for (const [alias, canonical] of aliasPairs) {
      let group = aliases.get(canonical);
      if (group === undefined) {
        group = [];
        aliases.set(canonical, group);
      }
      group.push(alias);
    }
    this._aliases = CreateReadOnlyMap([...aliases].map(([canonical, group]) => [canonical, CreateReadOnlyList(group)] as const));
    this._version = `${source.TzdbVersion} (mapping: ${source.WindowsMapping.Version})`;
  }

  /**
   * Builds the dictionary returned by {@link TzdbDateTimeZoneSource.TzdbToWindowsIds}; this is called lazily.
   * This method assumes the source is valid, for uniqueness purposes etc.
   */
  private BuildTzdbToWindowsIdMap(): ReadonlyMap<string, string> {
    const mutable = new Map<string, string>();
    // First map everything from the WindowsZones.
    for (const zone of this.WindowsMapping.MapZones.filter((mz) => mz.Territory !== MapZone.PrimaryTerritory)) {
      for (const tzdbId of zone.TzdbIds) {
        mutable.set(tzdbId, zone.WindowsId);
      }
    }

    const aliases = [...this.CanonicalIdMap].filter(([key, value]) => key !== value);

    // Now map any missing canonical IDs based on aliases
    for (const [key, value] of aliases
      // Only find aliases where the canonical ID isn't in the map
      .filter(([, value]) => !mutable.has(value))
      // Order by alias for predictability
      // (noda-js: C#'s OrderBy here uses the default (culture-sensitive) string comparer; the IDs are ASCII,
      // and we use an ordinal comparison.)
      .sort(([a], [b]) => CompareOrdinal(a, b))) {
      // OrderBy is effectively greedy, so our earlier check for may not still be valid.
      // (An earlier alias may have provided an ID.)
      const windowsId = mutable.get(key);
      if (!mutable.has(value) && windowsId !== undefined) {
        mutable.set(value, windowsId);
      }
    }

    // Finally map any missing aliases based on canonical IDs
    for (const [key, value] of aliases
      // Only find aliases where the alias ID isn't in the map
      .filter(([key]) => !mutable.has(key))) {
      // Add a mapping based on the canonical mapping, if it's present.
      const windowsId = mutable.get(value);
      if (windowsId !== undefined) {
        mutable.set(key, windowsId);
      }
    }
    return mutable;
  }

  /**
   * Builds the dictionary returned by {@link TzdbDateTimeZoneSource.WindowsToTzdbIds}; this is called lazily.
   */
  private BuildWindowsToTzdbId(): ReadonlyMap<string, string> {
    const result = new Map<string, string>();
    for (const [key, value] of this.WindowsMapping.PrimaryMapping) {
      const canonical = this.CanonicalIdMap.get(value);
      if (canonical === undefined) {
        // C# would throw KeyNotFoundException from the dictionary indexer.
        throw new InvalidNodaDataError(`Windows mapping uses TZDB ID ${value} which is missing`);
      }
      result.set(key, canonical);
    }
    return result;
  }

  /** @inheritdoc */
  ForId(id: string): DateTimeZone {
    const canonicalId = this.CanonicalIdMap.get(Preconditions.CheckNotNull(id, "id"));
    if (canonicalId === undefined) {
      throw new ArgumentError(`Time zone with ID ${id} not found in source ${this._version}`, "id");
    }
    return this._source.CreateZone(id, canonicalId);
  }

  /** @inheritdoc */
  GetIds(): readonly string[] {
    return [...this.CanonicalIdMap.keys()];
  }

  /**
   * @inheritdoc
   *
   * noda-js: the system time zone is the host's default `Intl` time zone
   * (`Intl.DateTimeFormat().resolvedOptions().timeZone`), mapped as {@link TzdbDateTimeZoneSource.MapTimeZoneInfoId} describes.
   */
  GetSystemDefaultId(): string | null {
    return this.MapTimeZoneInfoId(GetIntlSystemTimeZoneId());
  }

  /**
   * Maps a system time zone ID to a TZDB ID: a Windows ID is mapped through the primary Windows mapping,
   * and a TZDB ID known to this source is returned as-is.
   *
   * noda-js: takes the system zone's ID rather than a `TimeZoneInfo`. NodaTime's final fallback of guessing the
   * zone by comparing transitions isn't ported, so an unknown ID maps to null.
   * @internal
   */
  MapTimeZoneInfoId(timeZoneId: string | null): string | null {
    // Unusual, but can happen in some Mono installations.
    if (timeZoneId === null) {
      return null;
    }
    const id = timeZoneId;
    // First see if it's a Windows time zone ID.
    const result = this._source.WindowsMapping.PrimaryMapping.get(id);
    if (result !== undefined) {
      return result;
    }
    // Next see if it's already a TZDB ID (e.g. .NET Core running on Linux or Mac).
    if (this.CanonicalIdMap.has(id)) {
      return id;
    }
    // Maybe it's a Windows zone we don't have a mapping for, or we're on a Mono system
    // where TimeZoneInfo.Local.Id returns "Local" but can actually do the mappings.
    // Not ported: GuessZoneIdByTransitions (needs a TimeZoneInfo to compare offsets with).
    return null;
  }

  // Not ported: guesses, GuessZoneIdByTransitions, GuessZoneIdByTransitionsUncached (they work on a BCL TimeZoneInfo)

  /**
   * Gets just the TZDB version (e.g. "2013a") of the source data.
   */
  get TzdbVersion(): string {
    return this._source.TzdbVersion;
  }

  /**
   * Gets the Windows time zone mapping information provided in the CLDR
   * supplemental "windowsZones.xml" file.
   */
  get WindowsMapping(): WindowsZones {
    return this._source.WindowsMapping;
  }

  /**
   * Returns a dictionary mapping TZDB IDs to Windows IDs.
   *
   * Where a TZDB alias isn't present directly in the Windows mapping, but its canonical ID is,
   * the dictionary will contain an entry for the alias as well. For example, the TZDB ID
   * "Africa/Asmara" is an alias for "Africa/Nairobi", which has a Windows ID of "E. Africa Standard Time".
   * "Africa/Asmara" doesn't appear in the Windows mapping directly, but it will still be present in the
   * returned dictionary.
   *
   * Where a TZDB canonical ID isn't present in the Windows mapping, but an alias is, the dictionary
   * will contain an entry for the canonical ID as well. For example, the Windows mapping uses the
   * TZDB ID "Asia/Calcutta" for "India Standard Time". This is an alias for "Asia/Kolkata" in TZDB,
   * so the returned dictionary will have an entry mapping "Asia/Kolkata" to "Asia/Calcutta".
   * If multiple aliases for the same canonical ID have entries in the Windows mapping with different
   * Windows IDs, the alias that is earliest in lexicographical ordering determines the value for the entry.
   *
   * If a canonical ID is not present in the mapping, nor any of its aliases, it will not be present in
   * the returned dictionary.
   */
  get TzdbToWindowsIds(): ReadonlyMap<string, string> {
    return (this._tzdbToWindowsId ??= CreateReadOnlyMap(this.BuildTzdbToWindowsIdMap()));
  }

  /**
   * Returns a dictionary mapping Windows IDs to canonical TZDB IDs, using the
   * primary mapping in each {@link MapZone}.
   *
   * Sometimes the Windows mapping contains values which are not canonical TZDB IDs.
   * Every value in the returned dictionary is a canonical ID. For example, the Windows
   * mapping contains as "Asia/Calcutta" for the Windows ID "India Standard Time", but
   * "Asia/Calcutta" is an alias for "Asia/Kolkata". The entry for "India Standard Time"
   * in the returned dictionary therefore has "Asia/Kolkata" as the value.
   */
  get WindowsToTzdbIds(): ReadonlyMap<string, string> {
    return (this._windowsToTzdbId ??= CreateReadOnlyMap(this.BuildWindowsToTzdbId()));
  }

  /**
   * Validates that the data within this source is consistent with itself.
   *
   * Source data is not validated automatically when it's loaded, but any source
   * loaded from data produced by `NodaTime.TzdbCompiler` (including the data shipped with Noda Time)
   * will already have been validated via this method when it was originally produced. This method should
   * only normally be called explicitly if you have data from a source you're unsure of.
   * @throws {InvalidNodaDataError} The source data is invalid. The source may not function
   * correctly.
   */
  Validate(): void {
    // Check that each entry has a canonical value. (Every mapping x to y
    // should be such that y maps to itself.)
    for (const [key, value] of this.CanonicalIdMap) {
      const canonical = this.CanonicalIdMap.get(value);
      if (canonical === undefined) {
        throw new InvalidNodaDataError(`Mapping for entry ${key} (${value}) is missing`);
      }
      if (value !== canonical) {
        throw new InvalidNodaDataError(`Mapping for entry ${key} (${value}) is not canonical (${value} maps to ${canonical})`);
      }
    }

    // Check that every Windows mapping has a primary territory
    for (const mapZone of this.WindowsMapping.MapZones) {
      // Simplest way of checking is to find the primary mapping...
      if (!this._source.WindowsMapping.PrimaryMapping.has(mapZone.WindowsId)) {
        throw new InvalidNodaDataError(`Windows mapping for standard ID ${mapZone.WindowsId} has no primary territory`);
      }
    }

    // Check Windows mappings:
    // - Each MapZone uses TZDB IDs that are known to this source,
    // - Each TZDB ID only occurs once except for the primary territory
    // - Every ID has a primary territory
    // - Within each ID, the territories are unique
    // - Each primary territory TZDB ID occurs as a non-primary territory
    const mappedTzdbIds = new Set<string>();
    for (const mapZone of this.WindowsMapping.MapZones) {
      for (const id of mapZone.TzdbIds) {
        if (!this.CanonicalIdMap.has(id)) {
          throw new InvalidNodaDataError(`Windows mapping uses TZDB ID ${id} which is missing`);
        }
        // The primary territory ID is also present as a non-primary territory,
        // so don't include it in duplicate detection. Everything else should be unique.
        if (mapZone.Territory !== MapZone.PrimaryTerritory) {
          if (mappedTzdbIds.has(id)) {
            throw new InvalidNodaDataError(`Windows mapping has multiple entries for TZDB ID ${id}`);
          }
          mappedTzdbIds.add(id);
        }
      }
    }
    // WindowsMapping.MapZones.ToLookup(mapZone => mapZone.WindowsId)
    const territoriesByWindowsId = new Map<string, MapZone[]>();
    for (const mapZone of this.WindowsMapping.MapZones) {
      let group = territoriesByWindowsId.get(mapZone.WindowsId);
      if (group === undefined) {
        group = [];
        territoriesByWindowsId.set(mapZone.WindowsId, group);
      }
      group.push(mapZone);
    }
    for (const [key, group] of territoriesByWindowsId) {
      if (new Set(group.map((zone) => zone.Territory)).size !== group.length) {
        throw new InvalidNodaDataError(`Windows mapping has duplicate territories entries for Windows ID ${key}`);
      }
      const primary = group.find((zone) => zone.Territory === MapZone.PrimaryTerritory);
      if (primary === undefined) {
        throw new InvalidNodaDataError(`Windows mapping has no primary territory entry for Windows ID ${key}`);
      }
      // primary.TzdbIds.Single()
      if (primary.TzdbIds.length !== 1) {
        throw new InvalidNodaDataError(`Windows mapping primary territory entry for Windows ID ${key} does not have exactly one TZDB ID`);
      }
      const primaryTzdb = primary.TzdbIds[0]!;
      if (!group.some((zone) => zone.Territory !== MapZone.PrimaryTerritory && zone.TzdbIds.indexOf(primaryTzdb) !== -1)) {
        throw new InvalidNodaDataError(
          `Windows mapping primary territory entry for Windows ID ${key} has TZDB ID ${primaryTzdb} which does not occur in a non-primary territory`,
        );
      }
    }

    // Check that each zone location has a valid zone ID
    if (this.ZoneLocations !== null) {
      for (const location of this.ZoneLocations) {
        if (!this.CanonicalIdMap.has(location.ZoneId)) {
          throw new InvalidNodaDataError(`Zone location ${location.CountryName} uses zone ID ${location.ZoneId} which is missing`);
        }
      }
    }
    if (this.Zone1970Locations !== null) {
      for (const location of this.Zone1970Locations) {
        if (!this.CanonicalIdMap.has(location.ZoneId)) {
          throw new InvalidNodaDataError(`Zone 1970 location ${location.Countries[0]!.Name} uses zone ID ${location.ZoneId} which is missing`);
        }
      }
    }
  }
}

/** StringComparer.Ordinal */
function CompareOrdinal(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

/** noda-js: the host's default time zone ID, or null if it doesn't have one. */
function GetIntlSystemTimeZoneId(): string | null {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone ?? null;
  } catch {
    return null;
  }
}

/** noda-js: decodes base64 text to bytes. */
function DecodeBase64(text: string): Uint8Array {
  // eslint-disable-next-line es-x/no-uint8array-frombase64 -- feature-detected, with a fallback below
  const fromBase64 = (Uint8Array as unknown as { fromBase64?: (text: string) => Uint8Array }).fromBase64;
  if (typeof fromBase64 === "function") {
    return fromBase64.call(Uint8Array, text);
  }
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
