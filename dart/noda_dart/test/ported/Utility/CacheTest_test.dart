// Ported from NodaTime 6e024dde: src/NodaTime.Test/Utility/CacheTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Utility/Cache.dart';
import 'package:noda_dart/src/Utility/Comparers.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Utility/CacheTest.generated.dart' as scenarios;

int factoryCallCount = 0;

void main() {
  port(scenarios.fixture, {
    'Clear': (args) {
      var cache = CreateCache();
      cache.GetOrAdd('A');
      Assert.AreEqual(1, cache.Count);
      cache.Clear();
      Assert.AreEqual(0, cache.Count);
      CollectionAssert.IsEmpty(cache.Keys);
    },

    'GetOrAdd_NewEntry': (args) {
      var cache = CreateCache();
      Assert.AreEqual(0, cache.Count);
      Assert.AreEqual(1, cache.GetOrAdd('A'));
      Assert.AreEqual(1, cache.Count);
      Assert.AreEqual(1, factoryCallCount);
      CollectionAssert.AreEqual(['A'], cache.Keys);
    },

    'GetOrAdd_ExistingEntry': (args) {
      var cache = CreateCache();
      Assert.AreEqual(1, cache.GetOrAdd('A'));
      Assert.AreEqual(1, cache.GetOrAdd('A'));
      Assert.AreEqual(1, cache.GetOrAdd('A'));
      Assert.AreEqual(1, factoryCallCount);
      CollectionAssert.AreEqual(['A'], cache.Keys);
    },

    'GetOrAdd_ReplacementEntry': (args) {
      var cache = CreateCache();
      Assert.AreEqual(1, cache.GetOrAdd('A'));
      Assert.AreEqual(2, cache.GetOrAdd('BB'));
      Assert.AreEqual(3, cache.GetOrAdd('CCC'));
      CollectionAssert.AreEqual(['A', 'BB', 'CCC'], cache.Keys.toList()..sort());
      Assert.AreEqual(4, cache.GetOrAdd('DDDD'));
      CollectionAssert.AreEqual(['BB', 'CCC', 'DDDD'], cache.Keys.toList()..sort());
      Assert.AreEqual(3, cache.Count);
      Assert.AreEqual(4, factoryCallCount);
    },
  });
}

/// Creates a cache of size 3, from string to int, case-insensitive, where the value
/// associated with a key is its length. The factory call count is reset to 0, and incremented
/// each time the value factory is called.
Cache<String, int> CreateCache() {
  factoryCallCount = 0;
  return Cache<String, int>.NewSizeValueFactoryKeyComparer(3, (text) {
    factoryCallCount++;
    return text.length;
  }, OrdinalIgnoreCaseComparer());
}

/// noda_dart: .NET's `StringComparer.OrdinalIgnoreCase` (ordinal comparison of the upper-cased strings).
final class OrdinalIgnoreCaseComparer implements IEqualityComparer<String> {
  @override
  bool Equals(String x, String y) => x.toUpperCase() == y.toUpperCase();

  @override
  int GetHashCode(String obj) => obj.toUpperCase().hashCode;
}
