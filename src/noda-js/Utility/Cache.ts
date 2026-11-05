// Ported from NodaTime 3.3.0: src/NodaTime/Utility/Cache.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

/**
 * Implements a thread-safe cache of a fixed size, with a single computation function.
 * (That happens to be all we need at the time of writing.)
 *
 * For simplicity's sake, eviction is currently on a least-recently-added basis (not LRU). This
 * may change in the future.
 *
 * @typeParam TKey Type of key
 * @typeParam TValue Type of value
 * @internal
 */
export class Cache<TKey, TValue> {
  private readonly _size: number;
  private readonly _valueFactory: (key: TKey) => TValue;
  // List of keys in (rough) insertion order. Used for eviction ordering.
  // The same key may appear in the list multiple times.
  private readonly _keyList: TKey[];
  private readonly _dictionary: Map<TKey, TValue>;

  private constructor(size: number, valueFactory: (key: TKey) => TValue) {
    this._size = size;
    this._valueFactory = valueFactory;
    this._dictionary = new Map<TKey, TValue>();
    this._keyList = [];
  }

  /**
   * C#: `internal Cache(int size, Func<TKey, TValue> valueFactory, IEqualityComparer<TKey> keyComparer)`.
   * The key comparer is ignored: NodaTime only uses ordinal string comparison and reference equality,
   * which is what a JS Map does (SameValueZero).
   */
  static NewSizeValueFactoryKeyComparer<TKey, TValue>(size: number, valueFactory: (key: TKey) => TValue, keyComparer?: unknown): Cache<TKey, TValue> {
    void keyComparer;
    return new Cache<TKey, TValue>(size, valueFactory);
  }

  /**
   * Fetches a value from the cache, populating it if necessary.
   * @param key Key to fetch
   * @returns The value associated with the key.
   */
  GetOrAdd(key: TKey): TValue {
    if (this._dictionary.has(key)) {
      return this._dictionary.get(key) as TValue;
    }
    // Add the key to the eviction queue is we're *probably* going to be adding it now.
    // There's no easy way of telling whether a particular call to GetOrAdd has added the key.
    this._keyList.push(key);
    const value = this._valueFactory(key);
    this._dictionary.set(key, value);

    // Trim to size if necessary, bearing in mind that other threads may be doing
    // the same thing at the same time, and that there may be multiple entries for a particular key.
    while (this._dictionary.size > this._size && this._keyList.length > 0) {
      const keyToRemove = this._keyList.shift() as TKey;
      this._dictionary.delete(keyToRemove);
    }
    return value;
  }

  /** Returns the number of entries currently in the cache, primarily for diagnostic purposes. */
  get Count(): number {
    return this._dictionary.size;
  }

  /** Returns a copy of the keys in the cache as a list, for diagnostic purposes. */
  get Keys(): TKey[] {
    return [...this._dictionary.keys()];
  }

  /**
   * Clears the cache. This is never surfaced publicly (directly or indirectly) - it's just
   * for testing.
   */
  Clear(): void {
    // There's no Clear method on ConcurrentQueue, so we need to iterate over
    // it.
    this._keyList.length = 0;
    this._dictionary.clear();
  }
}
