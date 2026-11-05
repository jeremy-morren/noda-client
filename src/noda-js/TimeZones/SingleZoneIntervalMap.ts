// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/SingleZoneIntervalMap.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { IZoneIntervalMap, Instant, Offset, ZoneInterval } from "../internal.ts";

/**
 * Implementation of IZoneIntervalMap which just returns a single interval (provided on construction) regardless of
 * the instant requested.
 * @internal
 */
export class SingleZoneIntervalMap implements IZoneIntervalMap {
  private readonly _interval: ZoneInterval;

  get MinOffset(): Offset {
    return this._interval.WallOffset;
  }

  get MaxOffset(): Offset {
    return this._interval.WallOffset;
  }

  // noda-js: the C# constructor is internal; the class itself is internal, so the constructor is kept
  // alongside the mechanical factory.
  constructor(interval: ZoneInterval) {
    this._interval = interval;
  }

  /** @internal */
  static NewInterval(interval: ZoneInterval): SingleZoneIntervalMap {
    return new SingleZoneIntervalMap(interval);
  }

  GetZoneInterval(_instant: Instant): ZoneInterval {
    return this._interval;
  }
}
