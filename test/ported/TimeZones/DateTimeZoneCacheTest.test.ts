// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/DateTimeZoneCacheTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: DateTimeZoneProviders.Tzdb is the bundled `tzdb` provider; the indexer provider[id] is get(id). The C#
// `params string[] ids` of the test sources is an array argument (so the "null sequence" test can pass null).

import { expect } from "vitest";
import {
  ArgumentNullError,
  DateTimeZone,
  DateTimeZoneCache,
  DateTimeZoneNotFoundError,
  InvalidDateTimeZoneSourceError,
  NodaConstants,
  Offset,
  SingleTransitionDateTimeZone,
  type IDateTimeZoneSource,
} from "../../../src/noda-js/internal.ts";
import { tzdb } from "../../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/DateTimeZoneCacheTest.generated.ts";

/**
 * A deterministic stand-in for C# string.GetHashCode() (which is randomized per process in .NET, so the test can't
 * depend on its value): Java's String.hashCode, as a 32-bit signed integer.
 */
function stringHashCode(value: string): number {
  let hash = 0;
  for (let i = 0; i < value.length; i++) {
    hash = (Math.imul(hash, 31) + value.charCodeAt(i)) | 0;
  }
  return hash;
}

class TestDateTimeZoneSource implements IDateTimeZoneSource {
  lastRequestedId: string | null = null;
  private readonly ids: readonly (string | null)[] | null;

  constructor(ids: readonly (string | null)[] | null) {
    this.ids = ids;
    this.VersionId = "test version";
  }

  GetIds(): Iterable<string> {
    return this.ids as Iterable<string>;
  }

  ForId(id: string): DateTimeZone {
    this.lastRequestedId = id;
    return new SingleTransitionDateTimeZone(NodaConstants.UnixEpoch, Offset.Zero, Offset.FromHours(stringHashCode(id) % 18), id);
  }

  VersionId: string;

  GetSystemDefaultId(): string | null {
    return "map";
  }
}

// A test source that returns null from ForId and GetSystemDefaultId()
class NullReturningTestDateTimeZoneSource extends TestDateTimeZoneSource {
  constructor(ids: readonly (string | null)[] | null) {
    super(ids);
  }

  override ForId(id: string): DateTimeZone {
    // Still remember what was requested.
    super.ForId(id);
    return null!;
  }

  override GetSystemDefaultId(): string | null {
    return null;
  }
}

port(fixture, {
  Construction_NullProvider() {
    assertThrows(ArgumentNullError, () => new DateTimeZoneCache(null!));
  },

  InvalidSource_NullVersionId() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    source.VersionId = null!;
    assertThrows(InvalidDateTimeZoneSourceError, () => new DateTimeZoneCache(source));
  },

  InvalidSource_NullIdSequence() {
    const ids: string[] = null!;
    const source = new TestDateTimeZoneSource(ids);
    assertThrows(InvalidDateTimeZoneSourceError, () => new DateTimeZoneCache(source));
  },

  InvalidSource_ReturnsNullForAdvertisedId() {
    const source = new NullReturningTestDateTimeZoneSource(["foo", "bar"]);
    const cache = new DateTimeZoneCache(source);
    assertThrows(InvalidDateTimeZoneSourceError, () => cache.GetZoneOrNull("foo"));
  },

  InvalidProvider_NullIdWithinSequence() {
    const source = new TestDateTimeZoneSource(["Test1", null!]);
    assertThrows(InvalidDateTimeZoneSourceError, () => new DateTimeZoneCache(source));
  },

  CachingForPresentValues() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    const provider = new DateTimeZoneCache(source);
    const zone1a = provider.Get("Test1");
    expect(zone1a).not.toBeNull();
    expect(source.lastRequestedId).toBe("Test1");

    // Hit up the cache (and thus the source) for Test2
    expect(provider.Get("Test2")).not.toBeNull();
    expect(source.lastRequestedId).toBe("Test2");

    // Ask for Test1 again
    const zone1b = provider.Get("Test1");
    // We won't have consulted the source again
    expect(source.lastRequestedId).toBe("Test2");

    expect(zone1b).toBe(zone1a);
  },

  SourceIsNotAskedForUtcIfNotAdvertised() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    const provider = new DateTimeZoneCache(source);
    const zone = provider.Get(DateTimeZone.UtcId);
    expect(zone).not.toBeNull();
    expect(source.lastRequestedId).toBeNull();
  },

  SourceIsAskedForUtcIfAdvertised() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2", "UTC"]);
    const provider = new DateTimeZoneCache(source);
    const zone = provider.Get(DateTimeZone.UtcId);
    expect(zone).not.toBeNull();
    expect(source.lastRequestedId).toBe("UTC");
  },

  SourceIsNotAskedForUnknownIds() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    const provider = new DateTimeZoneCache(source);
    assertThrows(DateTimeZoneNotFoundError, () => provider.Get("Unknown"));
    expect(source.lastRequestedId).toBeNull();
  },

  UtcIsReturnedInIdsIfAdvertisedByProvider() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2", "UTC"]);
    const provider = new DateTimeZoneCache(source);
    expect(provider.Ids.includes(DateTimeZone.UtcId)).toBe(true);
  },

  UtcIsNotReturnedInIdsIfNotAdvertisedByProvider() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    const provider = new DateTimeZoneCache(source);
    expect(provider.Ids.includes(DateTimeZone.UtcId)).toBe(false);
  },

  FixedOffsetSucceedsWhenNotAdvertised() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    const provider = new DateTimeZoneCache(source);
    const id = "UTC+05:30";
    const zone = provider.Get(id);
    assertNodaEqual(zone, DateTimeZone.ForOffset(Offset.FromHoursAndMinutes(5, 30)));
    expect(zone.Id).toBe(id);
    expect(source.lastRequestedId).toBeNull();
  },

  FixedOffsetConsultsSourceWhenAdvertised() {
    const id = "UTC+05:30";
    const source = new TestDateTimeZoneSource(["Test1", "Test2", id]);
    const provider = new DateTimeZoneCache(source);
    const zone = provider.Get(id);
    expect(zone.Id).toBe(id);
    expect(source.lastRequestedId).toBe(id);
  },

  FixedOffsetUncached() {
    const id = "UTC+05:26";
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    const provider = new DateTimeZoneCache(source);
    const zone1 = provider.Get(id);
    const zone2 = provider.Get(id);
    expect(zone1).not.toBe(zone2);
    assertNodaEqual(zone2, zone1);
  },

  FixedOffsetZeroReturnsUtc() {
    const id = "UTC+00:00";
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    const provider = new DateTimeZoneCache(source);
    const zone = provider.Get(id);
    assertNodaEqual(zone, DateTimeZone.Utc);
    expect(source.lastRequestedId).toBeNull();
  },

  Tzdb_Indexer_InvalidFixedOffset() {
    assertThrows(DateTimeZoneNotFoundError, () => tzdb.Get("UTC+5Months"));
  },

  NullIdRejected() {
    const provider = new DateTimeZoneCache(new TestDateTimeZoneSource(["Test1", "Test2"]));
    assertThrows(ArgumentNullError, () => provider.Get(null!));
  },

  EmptyIdAccepted() {
    const provider = new DateTimeZoneCache(new TestDateTimeZoneSource(["Test1", "Test2"]));
    assertThrows(DateTimeZoneNotFoundError, () => provider.Get(""));
  },

  VersionIdPassThrough() {
    const source = new TestDateTimeZoneSource(["Test1", "Test2"]);
    source.VersionId = "foo";
    const provider = new DateTimeZoneCache(source);
    expect(provider.VersionId).toBe("foo");
  },

  // Test for issue 7 in bug tracker
  Tzdb_IterateOverIds() {
    // According to bug, this would go bang
    const count = [...tzdb.Ids].length;

    expect(count > 1).toBe(true);
    const utcCount = [...tzdb.Ids].filter(id => id === DateTimeZone.UtcId).length;
    expect(utcCount).toBe(1);
  },

  Tzdb_Indexer_UtcId() {
    assertNodaEqual(tzdb.Get(DateTimeZone.UtcId), DateTimeZone.Utc);
  },

  Tzdb_Indexer_AmericaLosAngeles() {
    const americaLosAngeles = "America/Los_Angeles";
    const actual = tzdb.Get(americaLosAngeles);
    expect(actual).not.toBeNull();
    expect(actual.Equals(DateTimeZone.Utc)).toBe(false);
    expect(actual.Id).toBe(americaLosAngeles);
  },

  Tzdb_Ids_All() {
    const actual = tzdb.Ids;
    const actualCount = [...actual].length;
    expect(actualCount > 1).toBe(true);
    // C# Single(): exactly one match.
    const matches = [...actual].filter(id => id === DateTimeZone.UtcId);
    expect(matches.length).toBe(1);
    expect(matches[0]).toBe(DateTimeZone.UtcId);
  },

  /**
   * Simply tests that every ID in the built-in database can be fetched. This is also
   * helpful for diagnostic debugging when we want to check that some potential
   * invariant holds for all time zones...
   */
  Tzdb_Indexer_AllIds() {
    for (const id of tzdb.Ids) {
      expect(tzdb.Get(id)).not.toBeNull();
    }
  },

  GetSystemDefault_SourceReturnsNullId() {
    const source = new NullReturningTestDateTimeZoneSource(["foo", "bar"]);
    const cache = new DateTimeZoneCache(source);
    assertThrows(DateTimeZoneNotFoundError, () => cache.GetSystemDefault());
  },
});
