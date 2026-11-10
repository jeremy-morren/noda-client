// Ported from NodaTime 6e024dde: src/NodaTime/Utility/Cache.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:collection';

import 'package:meta/meta.dart';

import 'Comparers.dart';

/// Implements a thread-safe cache of a fixed size, with a single computation function.
/// (That happens to be all we need at the time of writing.)
///
/// For simplicity's sake, eviction is currently on a least-recently-added basis (not LRU). This
/// may change in the future.
///
/// [TKey]: Type of key
/// [TValue]: Type of value
@internal
final class Cache<TKey extends Object, TValue> {
  final int _size;
  final TValue Function(TKey key) _valueFactory;
  // List of keys in (rough) insertion order. Used for eviction ordering.
  // The same key may appear in the list multiple times.
  final Queue<TKey> _keyList;
  final Map<TKey, TValue> _dictionary;

  // Dart: isolates don't share memory, so ConcurrentQueue and ConcurrentDictionary are a Queue and a LinkedHashMap
  // (comparing keys with keyComparer).
  Cache.NewSizeValueFactoryKeyComparer(int size, TValue Function(TKey key) valueFactory, IEqualityComparer<TKey> keyComparer)
      : _size = size,
        _valueFactory = valueFactory,
        _dictionary = LinkedHashMap<TKey, TValue>(equals: keyComparer.Equals, hashCode: keyComparer.GetHashCode),
        _keyList = Queue<TKey>();

  /// Fetches a value from the cache, populating it if necessary.
  ///
  /// [key]: Key to fetch
  ///
  /// Returns the value associated with the key.
  TValue GetOrAdd(TKey key) {
    if (_dictionary.containsKey(key)) {
      return _dictionary[key] as TValue;
    }
    // Add the key to the eviction queue is we're *probably* going to be adding it now.
    // There's no easy way of telling whether a particular call to GetOrAdd has added the key.
    _keyList.addLast(key);
    TValue value = _dictionary.putIfAbsent(key, () => _valueFactory(key));

    // Trim to size if necessary, bearing in mind that other threads may be doing
    // the same thing at the same time, and that there may be multiple entries for a particular key.
    while (_dictionary.length > _size && _keyList.isNotEmpty) {
      TKey keyToRemove = _keyList.removeFirst();
      _dictionary.remove(keyToRemove);
    }
    return value;
  }

  /// Returns the number of entries currently in the cache, primarily for diagnostic purposes.
  int get Count => _dictionary.length;

  /// Returns a copy of the keys in the cache as a list, for diagnostic purposes.
  List<TKey> get Keys => _dictionary.keys.toList();

  /// Clears the cache. This is never surfaced publicly (directly or indirectly) - it's just
  /// for testing.
  void Clear() {
    // There's no Clear method on ConcurrentQueue, so we need to iterate over
    // it.
    while (_keyList.isNotEmpty) {
      _keyList.removeFirst();
    }
    _dictionary.clear();
  }
}
