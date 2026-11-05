// Ported from NodaTime 3.3.0: src/NodaTime/Extensions/DateTimeZoneProviderExtensions.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Preconditions } from "../internal.ts";
import type { DateTimeZone, IDateTimeZoneProvider } from "../internal.ts";

// Extensions for IDateTimeZoneProvider

/**
 * Returns a lazily-evaluated sequence of time zones from the specified provider,
 * in the same order in which the IDs are returned by the provider.
 *
 * @param provider The provider to fetch time zones from.
 * @returns All the time zones from the provider.
 */
export function GetAllZones(provider: IDateTimeZoneProvider): Iterable<DateTimeZone> {
  Preconditions.CheckNotNull(provider, "provider");
  return (function* () {
    for (const id of provider.Ids) {
      yield provider.get(id);
    }
  })();
}
