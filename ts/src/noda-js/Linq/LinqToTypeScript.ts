// The comparer types of linq-to-typescript 12.1.1 (https://github.com/arogozine/LinqToTypeScript; in its npm
// package, types/types/IComparer.d.ts and types/types/IEqualityComparer.d.ts), copied verbatim so that
// noda-js/linq's comparers fit linq-to-typescript's methods without depending on it. They only type this
// entry point's exports and aren't exported from it.
//
// Copyright (c) 2021 Alexandre Rogozine. Licensed under the MIT License; see NOTICE.txt.

/**
 * Compares two numbers for sorting
 */
export type IComparer<TKey> = (x: TKey, y: TKey) => number;

/**
 * Equality Comparison for two values
 */
export type IEqualityComparer<T> = (x: T, y: T) => boolean;
