// Ported from NodaTime 3.3.7: src/NodaTime.Test/Utility/CacheTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { Cache } from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Utility/CacheTest.generated.ts";

let factoryCallCount = 0;

/**
 * Creates a cache of size 3, from string to int, case-insensitive, where the value
 * associated with a key is its length. The factory call count is reset to 0, and incremented
 * each time the value factory is called.
 * (noda-js: Cache ignores the key comparer; these tests don't depend on it.)
 */
function createCache(): Cache<string, number> {
  factoryCallCount = 0;
  return Cache.NewSizeValueFactoryKeyComparer<string, number>(
    3,
    text => {
      factoryCallCount++;
      return text.length;
    },
    "OrdinalIgnoreCase",
  );
}

port(fixture, {
  Clear() {
    const cache = createCache();
    cache.GetOrAdd("A");
    expect(cache.Count).toBe(1);
    cache.Clear();
    expect(cache.Count).toBe(0);
    expect(cache.Keys).toEqual([]);
  },

  GetOrAdd_NewEntry() {
    const cache = createCache();
    expect(cache.Count).toBe(0);
    expect(cache.GetOrAdd("A")).toBe(1);
    expect(cache.Count).toBe(1);
    expect(factoryCallCount).toBe(1);
    expect(cache.Keys).toEqual(["A"]);
  },

  GetOrAdd_ExistingEntry() {
    const cache = createCache();
    expect(cache.GetOrAdd("A")).toBe(1);
    expect(cache.GetOrAdd("A")).toBe(1);
    expect(cache.GetOrAdd("A")).toBe(1);
    expect(factoryCallCount).toBe(1);
    expect(cache.Keys).toEqual(["A"]);
  },

  GetOrAdd_ReplacementEntry() {
    const cache = createCache();
    expect(cache.GetOrAdd("A")).toBe(1);
    expect(cache.GetOrAdd("BB")).toBe(2);
    expect(cache.GetOrAdd("CCC")).toBe(3);
    expect([...cache.Keys].sort()).toEqual(["A", "BB", "CCC"]);
    expect(cache.GetOrAdd("DDDD")).toBe(4);
    expect([...cache.Keys].sort()).toEqual(["BB", "CCC", "DDDD"]);
    expect(cache.Count).toBe(3);
    expect(factoryCallCount).toBe(4);
  },
});
