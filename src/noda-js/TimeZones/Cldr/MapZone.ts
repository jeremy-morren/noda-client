// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/Cldr/MapZone.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CreateReadOnlyList, Preconditions } from "../../internal.ts";
import type { IDateTimeZoneReader, IEquatable } from "../../internal.ts";

/**
 * Represents a single `<mapZone>` element in the CLDR Windows zone mapping file.
 *
 * Equality is defined in a component-wise fashion. When comparing two values for equality, the {@link MapZone.TzdbIds} properties
 * must return the same IDs in the same order for the values to be considered equal.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class MapZone implements IEquatable<MapZone> {
  /**
   * Identifier used for the primary territory of each Windows time zone. A zone mapping with
   * this territory will always have a single entry. The value of this constant is "001".
   */
  static readonly PrimaryTerritory = "001";
  /**
   * Identifier used for the "fixed offset" territory. A zone mapping with
   * this territory will always have a single entry. The value of this constant is "ZZ".
   */
  static readonly FixedOffsetTerritory = "ZZ";

  private readonly _windowsId: string;

  /**
   * Gets the Windows system time zone identifier for this mapping, such as "Central Standard Time".
   *
   * Most Windows system time zone identifiers use the name for the "standard" part of the zone as
   * the overall identifier. Don't be fooled: just because a time zone includes "standard" in its identifier
   * doesn't mean that it doesn't observe daylight saving time.
   */
  get WindowsId(): string {
    return this._windowsId;
  }

  private readonly _territory: string;

  /**
   * Gets the territory code for this mapping.
   *
   * This is typically either "001" to indicate that it's the primary territory for this ID, or
   * "ZZ" to indicate a fixed-offset ID, or a different two-character capitalized code
   * which indicates the geographical territory.
   */
  get Territory(): string {
    return this._territory;
  }

  private readonly _tzdbIds: readonly string[];

  /**
   * Gets a read-only non-empty collection of TZDB zone identifiers for this mapping, such as
   * "America/Chicago" and "America/Matamoros" (both of which are TZDB zones associated with the "Central Standard Time"
   * Windows system time zone).
   *
   * For the primary and fixed-offset territory IDs ("001" and "ZZ") this always
   * contains exactly one time zone ID. The IDs returned are not necessarily canonical in TZDB.
   */
  get TzdbIds(): readonly string[] {
    return this._tzdbIds;
  }

  /**
   * Creates a new mapping entry.
   *
   * This constructor is only public for the sake of testability.
   * @param windowsId Windows system time zone identifier. Must not be null.
   * @param territory Territory code. Must not be null.
   * @param tzdbIds List of territory codes. Must not be null, and must not
   * contains null values.
   */
  constructor(windowsId: string, territory: string, tzdbIds: readonly string[]) {
    this._windowsId = Preconditions.CheckNotNull(windowsId, "windowsId");
    this._territory = Preconditions.CheckNotNull(territory, "territory");
    this._tzdbIds = CreateReadOnlyList(Preconditions.CheckNotNull(tzdbIds, "tzdbIds"));
  }

  /**
   * Private constructor to avoid unnecessary list copying (and validation) when deserializing.
   */
  private static NewWindowsIdTerritoryTzdbIds(windowsId: string, territory: string, tzdbIds: readonly string[]): MapZone {
    const mapZone = Object.create(MapZone.prototype) as { _windowsId: string; _territory: string; _tzdbIds: readonly string[] };
    mapZone._windowsId = windowsId;
    mapZone._territory = territory;
    mapZone._tzdbIds = CreateReadOnlyList(tzdbIds);
    return mapZone as unknown as MapZone;
  }

  /**
   * Reads a mapping from a reader.
   * @internal
   */
  static Read(reader: IDateTimeZoneReader): MapZone {
    const windowsId = reader.ReadString();
    const territory = reader.ReadString();
    const count = reader.ReadCount();
    const tzdbIds = new Array<string>(count);
    for (let i = 0; i < count; i++) {
      tzdbIds[i] = reader.ReadString();
    }
    return MapZone.NewWindowsIdTerritoryTzdbIds(windowsId, territory, tzdbIds);
  }

  // Not ported: Write(IDateTimeZoneWriter) (DateTimeZoneWriter is not ported)

  /**
   * Compares two {@link MapZone} values for equality.
   * See the type documentation for a description of equality semantics.
   * (Merges NodaTime's Equals(MapZone) and Equals(object).)
   * @param other The value to compare this map zone with.
   * @returns True if the given value is another map zone equal to this one; false otherwise.
   */
  Equals(other: MapZone): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return (
      other instanceof MapZone &&
      this.WindowsId === other.WindowsId &&
      this.Territory === other.Territory &&
      this.TzdbIds.length === other.TzdbIds.length &&
      this.TzdbIds.every((id, i) => id === other.TzdbIds[i])
    );
  }

  // Not ported: GetHashCode (see docs/porting-conventions.md)

  /**
   * Returns a string that represents this instance.
   * @returns The value of the current instance, for diagnostic purposes.
   */
  toString(): string {
    return `Windows ID: ${this.WindowsId}; Territory: ${this.Territory}; TzdbIds: ${this.TzdbIds.join(" ")}`;
  }
}
