// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/IZoneIntervalMap.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { Instant, Offset, ZoneInterval } from "../internal.ts";

/**
 * The core part of a DateTimeZone: mapping an Instant to an Interval.
 * Separating this out into an interface allows for flexible caching.
 *
 * Benchmarking shows that a delegate may be slightly faster here, but the difference
 * isn't very significant even for very fast calls (cache hits). The interface ends up
 * feeling slightly cleaner elsewhere in the code.
 *
 * Not part of the public API (no entry point exports it), but deliberately not tagged internal: public declarations refer to it,
 * so it must stay in the published type declarations.
 */
export interface IZoneIntervalMap {
  GetZoneInterval(instant: Instant): ZoneInterval;
  readonly MinOffset: Offset;
  readonly MaxOffset: Offset;
}
