// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/DateTimeZoneCache.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZoneNotFoundException, FixedDateTimeZone, InvalidDateTimeZoneSourceException, Preconditions } from "../internal.ts";
import type { DateTimeZone, IDateTimeZoneProvider, IDateTimeZoneSource } from "../internal.ts";

/**
 * Provides an implementation of {@link IDateTimeZoneProvider} that caches results from an
 * {@link IDateTimeZoneSource}.
 *
 * The process of loading or creating time zones may be an expensive operation. This class implements an
 * unlimited-size non-expiring cache over a time zone source, and adapts an implementation of the
 * `IDateTimeZoneSource` interface to an `IDateTimeZoneProvider`.
 *
 * All members of this type are thread-safe as long as the underlying `IDateTimeZoneSource`
 * implementation is thread-safe.
 */
export class DateTimeZoneCache implements IDateTimeZoneProvider {
  private readonly _source: IDateTimeZoneSource;
  private readonly _timeZoneMap = new Map<string, DateTimeZone | null>();

  private readonly _versionId: string;

  /**
   * Gets the version ID of this provider. This is simply the {@link IDateTimeZoneSource.VersionId} returned by
   * the underlying source.
   */
  get VersionId(): string {
    return this._versionId;
  }

  private readonly _ids: readonly string[];

  /** @inheritdoc */
  get Ids(): readonly string[] {
    return this._ids;
  }

  /**
   * Creates a provider backed by the given {@link IDateTimeZoneSource}.
   *
   * Note that the source will never be consulted for requests for the fixed-offset timezones "UTC" and
   * "UTC+/-Offset" (a standard implementation will be returned instead). This is true even if these IDs are
   * advertised by the source.
   *
   * @param source The {@link IDateTimeZoneSource} for this provider.
   * @throws {InvalidDateTimeZoneSourceException} `source` violates its contract.
   */
  constructor(source: IDateTimeZoneSource) {
    this._source = Preconditions.CheckNotNull(source, "source");
    this._versionId = source.VersionId;
    if (this.VersionId === null || this.VersionId === undefined) {
      throw new InvalidDateTimeZoneSourceException("Source-returned version ID was null");
    }
    const providerIds = source.GetIds();
    if (providerIds === null || providerIds === undefined) {
      throw new InvalidDateTimeZoneSourceException("Source-returned ID sequence was null");
    }
    const idList = Array.from(providerIds);
    // Default sort compares UTF-16 code units: the equivalent of StringComparer.Ordinal.
    idList.sort();
    this._ids = Object.freeze(idList);
    // Populate the dictionary with null values meaning "the ID is valid, we haven't fetched the zone yet".
    for (const id of this.Ids) {
      if (id === null || id === undefined) {
        throw new InvalidDateTimeZoneSourceException("Source-returned ID sequence contained a null reference");
      }
      this._timeZoneMap.set(id, null);
    }
  }

  /** @inheritdoc */
  GetSystemDefault(): DateTimeZone {
    const id = this._source.GetSystemDefaultId();
    if (id === null || id === undefined) {
      throw new DateTimeZoneNotFoundException(`System default time zone is unknown to source ${this.VersionId}`);
    }
    return this.Get(id);
  }

  /** @inheritdoc */
  GetZoneOrNull(id: string): DateTimeZone | null {
    Preconditions.CheckNotNull(id, "id");
    return this.GetZoneFromSourceOrNull(id) ?? FixedDateTimeZone.GetFixedZoneOrNull(id);
  }

  private GetZoneFromSourceOrNull(id: string): DateTimeZone | null {
    if (!this._timeZoneMap.has(id)) {
      return null;
    }
    let zone = this._timeZoneMap.get(id)!;
    // Ask the source for the zone. Multiple threads *may* do the same thing, but
    // that's hidden from the user: only one thread will update the map, and
    // all other threads will use that value.
    if (zone === null) {
      zone = this._source.ForId(id);
      if (zone === null || zone === undefined) {
        throw new InvalidDateTimeZoneSourceException(
          `Time zone ${id} is supported by source ${this.VersionId} but not returned`);
      }
      this._timeZoneMap.set(id, zone);
      return zone;
    }
    return zone;
  }

  /**
   * Returns the time zone for the given ID. (NodaTime's indexer, `this[string id]`.)
   * @inheritdoc
   */
  Get(id: string): DateTimeZone {
    const zone = this.GetZoneOrNull(id);
    if (zone === null) {
      throw new DateTimeZoneNotFoundException(`Time zone ${id} is unknown to source ${this.VersionId}`);
    }
    return zone;
  }
}
