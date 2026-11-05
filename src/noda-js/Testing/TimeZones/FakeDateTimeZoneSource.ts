// Ported from NodaTime 3.3.7: src/NodaTime.Testing/TimeZones/FakeDateTimeZoneSource.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZoneCache, Preconditions } from "../../internal.ts";
import type { DateTimeZone, IDateTimeZoneProvider, IDateTimeZoneSource } from "../../internal.ts";
import { NewArgumentException, NewInvalidOperationException } from "../../internal.ts";

/**
 * Builder for {@link FakeDateTimeZoneSource}, allowing the built object to
 * be immutable, but constructed via object/collection initializers.
 * (C#: FakeDateTimeZoneSource.Builder)
 */
export class FakeDateTimeZoneSourceBuilder implements Iterable<DateTimeZone> {
  private readonly _bclIdsToZoneIds = new Map<string, string>();
  private readonly _zones: DateTimeZone[] = [];

  /**
   * Gets the dictionary mapping BCL `TimeZoneInfo` IDs to the canonical IDs
   * served within the provider being built.
   *
   * noda-js: the "BCL" IDs are matched against the host's default `Intl` time zone ID
   * in {@link FakeDateTimeZoneSource.GetSystemDefaultId}.
   */
  get BclIdsToZoneIds(): Map<string, string> {
    return this._bclIdsToZoneIds;
  }

  /**
   * Gets the list of zones, exposed as a property for use when a test needs to set properties as
   * well as adding zones.
   */
  get Zones(): DateTimeZone[] {
    return this._zones;
  }

  /**
   * Gets the version ID to advertise; defaults to "TestZones".
   */
  VersionId: string;

  /**
   * Creates a new builder.
   */
  constructor() {
    this.VersionId = "TestZones";
  }

  /**
   * Adds a time zone to the builder.
   * @param zone The zone to add.
   */
  Add(zone: DateTimeZone): void {
    Preconditions.CheckNotNull(zone, "zone");
    this._zones.push(zone);
  }

  /**
   * Returns the zones within the builder. This mostly exists
   * to enable collection initializers.
   * @returns An iterator over the zones in this builder.
   */
  [Symbol.iterator](): Iterator<DateTimeZone> {
    return this._zones[Symbol.iterator]();
  }

  /**
   * Builds a time zone source from this builder. The returned
   * builder will be independent of this builder; further changes
   * to this builder will not be reflected in the returned source.
   *
   * This method performs some sanity checks, and throws exceptions if
   * they're violated. Those exceptions are not documented here, and you
   * shouldn't be catching them anyway. (This is aimed at testing...)
   * @returns The newly-built time zone source.
   */
  Build(): FakeDateTimeZoneSource {
    // zones.ToDictionary(zone => zone.Id)
    const zoneMap = new Map<string, DateTimeZone>();
    for (const zone of this._zones) {
      if (zoneMap.has(zone.Id)) {
        throw NewArgumentException(`An item with the same key has already been added. Key: ${zone.Id}`);
      }
      zoneMap.set(zone.Id, zone);
    }
    for (const [key, value] of this._bclIdsToZoneIds) {
      Preconditions.CheckNotNull(value, "value");
      if (!zoneMap.has(value)) {
        throw NewInvalidOperationException(`Mapping for BCL ${key}/${value} has no corresponding zone.`);
      }
    }
    const bclIdMapClone = new Map<string, string>(this._bclIdsToZoneIds);
    return FakeDateTimeZoneSource.NewVersionIdZonesBclToZoneIds(this.VersionId, zoneMap, bclIdMapClone);
  }
}

/**
 * A time zone source for test purposes.
 * Create instances via {@link FakeDateTimeZoneSource.Builder}.
 */
export class FakeDateTimeZoneSource implements IDateTimeZoneSource {
  /** Nested type: FakeDateTimeZoneSource.Builder */
  static readonly Builder = FakeDateTimeZoneSourceBuilder;

  private readonly _zones: ReadonlyMap<string, DateTimeZone>;
  private readonly _bclToZoneIds: ReadonlyMap<string, string>;

  /** @internal */
  static NewVersionIdZonesBclToZoneIds(
    versionId: string,
    zones: ReadonlyMap<string, DateTimeZone>,
    bclToZoneIds: ReadonlyMap<string, string>,
  ): FakeDateTimeZoneSource {
    return new FakeDateTimeZoneSource(versionId, zones, bclToZoneIds);
  }

  private constructor(versionId: string, zones: ReadonlyMap<string, DateTimeZone>, bclToZoneIds: ReadonlyMap<string, string>) {
    this.VersionId = versionId;
    this._zones = zones;
    this._bclToZoneIds = bclToZoneIds;
  }

  /**
   * Creates a time zone provider ({@link DateTimeZoneCache}) from this source.
   * @returns A provider backed by this source.
   */
  ToProvider(): IDateTimeZoneProvider {
    return new DateTimeZoneCache(this);
  }

  /** @inheritdoc */
  GetIds(): readonly string[] {
    return [...this._zones.keys()];
  }

  /** @inheritdoc */
  readonly VersionId: string;

  /** @inheritdoc */
  ForId(id: string): DateTimeZone {
    Preconditions.CheckNotNull(id, "id");
    const zone = this._zones.get(id);
    if (zone !== undefined) {
      return zone;
    }
    throw NewArgumentException(`Unknown ID: ${id}`);
  }

  /**
   * @inheritdoc
   *
   * noda-js: the host's default `Intl` time zone ID takes the place of `TimeZoneInfo.Local.Id`.
   */
  GetSystemDefaultId(): string | null {
    let id: string | undefined;
    try {
      id = Intl.DateTimeFormat().resolvedOptions().timeZone;
    } catch {
      id = undefined;
    }
    // We don't care about the return value of TryGetValue - if it's false,
    // canonicalId will be null, which is what we want.
    return id === undefined ? null : (this._bclToZoneIds.get(id) ?? null);
  }
}
