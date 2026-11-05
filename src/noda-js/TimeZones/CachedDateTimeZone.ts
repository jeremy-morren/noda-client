// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/CachedDateTimeZone.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CachingZoneIntervalMap, DateTimeZone, Preconditions } from "../internal.ts";
import type { IZoneIntervalMap, Instant, ZoneInterval } from "../internal.ts";

/**
 *  Provides a {@link DateTimeZone} wrapper class that implements a simple cache to
 *  speed up the lookup of transitions.
 *
 * The cache supports multiple caching strategies which are implemented in nested subclasses of
 * this one. Until we have a better sense of what the usage behavior is, we cannot tune the
 * cache. It is possible that we may support multiple strategies selectable at runtime so the
 * user can tune the performance based on their knowledge of how they are using the system.
 *
 * In fact, only one cache type is currently implemented: an MRU cache existed before
 * the GetZoneIntervalPair call was created in DateTimeZone, but as it wasn't being used, it
 * was more effort than it was worth to update. The mechanism is still available for future
 * expansion though.
 * @internal
 */
export class CachedDateTimeZone extends DateTimeZone {
  private readonly _map: IZoneIntervalMap;

  /**
   * Gets the cached time zone.
   */
  readonly TimeZone: DateTimeZone;

  /**
   * Initializes a new instance of the {@link CachedDateTimeZone} class.
   *
   * @param timeZone The time zone to cache.
   * @param map The caching map
   */
  private constructor(timeZone: DateTimeZone, map: IZoneIntervalMap) {
    super(timeZone.Id, false, timeZone.MinOffset, timeZone.MaxOffset);
    this.TimeZone = timeZone;
    this._map = map;
  }

  /**
   * Returns a cached time zone for the given time zone.
   *
   * If the time zone is already cached or it is fixed then it is returned unchanged.
   *
   * @param timeZone The time zone to cache.
   * @returns The cached time zone.
   */
  static ForZone(timeZone: DateTimeZone): DateTimeZone {
    Preconditions.CheckNotNull(timeZone, "timeZone");
    if (timeZone instanceof CachedDateTimeZone || timeZone.IsFixed) {
      return timeZone;
    }
    return new CachedDateTimeZone(timeZone, CachingZoneIntervalMap.CacheMap(timeZone));
  }

  /**
   * Delegates fetching a zone interval to the caching map.
   */
  override GetZoneInterval(instant: Instant): ZoneInterval {
    return this._map.GetZoneInterval(instant);
  }
}
