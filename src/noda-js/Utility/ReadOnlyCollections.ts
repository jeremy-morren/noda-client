// noda-js: read-only collections, standing in for .NET's ReadOnlyDictionary / ReadOnlyCollection.
// NodaTime exposes several maps and lists that throw NotSupportedException when modified (e.g.
// TzdbDateTimeZoneSource.CanonicalIdMap). A TS `ReadonlyMap` / `readonly T[]` is only read-only at compile
// time, so the shared data (e.g. the bundled tzdb source) could otherwise be corrupted at runtime.

import { NewNotSupportedException, type NotSupportedException } from "../internal.ts";

/**
 * A Map whose mutators throw NotSupportedException, like .NET's ReadOnlyDictionary.
 * @internal
 */
export class ReadOnlyMap<K, V> extends Map<K, V> {
  constructor(entries: Iterable<readonly [K, V]>) {
    super();
    for (const [key, value] of entries) {
      super.set(key, value);
    }
  }

  override set(_key: K, _value: V): this {
    throw NewNotSupportedException("Collection is read-only.");
  }

  override delete(_key: K): boolean {
    throw NewNotSupportedException("Collection is read-only.");
  }

  override clear(): void {
    throw NewNotSupportedException("Collection is read-only.");
  }
}

/** Returns a read-only copy of a map. @internal */
export function CreateReadOnlyMap<K, V>(map: Iterable<readonly [K, V]>): ReadonlyMap<K, V> {
  return map instanceof ReadOnlyMap ? map : new ReadOnlyMap(map);
}

/** Returns a frozen copy of a list (modifying it throws a TypeError in strict-mode code). @internal */
export function CreateReadOnlyList<T>(items: Iterable<T>): readonly T[] {
  return Object.freeze(Array.from(items));
}
