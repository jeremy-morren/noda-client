// noda-js/linq: the semantics shared by every comparer in the entry point, those of .NET's Comparer<T>.Default and
// EqualityComparer<T>.Default: null and undefined sort before any value and equal each other (and nothing else);
// otherwise the noda-js value's own CompareTo/Equals (or NodaTime's comparer) decides, errors included. Not
// exported from the entry point.

import type { ArgumentException } from "../internal.ts";
/** A noda-js class (the core's `implements IComparable<T>`), for `instanceof`. */
type ComparableType<T extends { CompareTo(other: unknown): number }> = Function & { readonly prototype: T };

/** A noda-js class (the core's `implements IEquatable<T>`), for `instanceof`. */
type EquatableType<T extends { Equals(other: unknown): boolean }> = Function & { readonly prototype: T };

/** `Comparer<T>.Default.Compare(x, y)` for a noda-js type with `CompareTo`. */
export function CompareComparable<T extends { CompareTo(other: unknown): number }>(
  type: ComparableType<T>, x: T | null | undefined, y: T | null | undefined): number {
  if (x === null || x === undefined) {
    return y === null || y === undefined ? 0 : -1;
  }
  if (y === null || y === undefined) {
    return 1;
  }
  if (x instanceof type) {
    // Throws ArgumentException if y isn't a T, or (e.g. LocalDate) is in another calendar, as in C#.
    return x.CompareTo(y);
  }
  // x isn't a T (only possible from untyped code). Compare the other way round, so that the core's CompareTo
  // rejects x as it does any foreign argument (ArgumentException), whatever y is.
  return -(type.prototype.CompareTo.call(y, x) as number);
}

/** `EqualityComparer<T>.Default.Equals(x, y)` for a noda-js type with `Equals`. */
export function EqualsEquatable<T extends { Equals(other: unknown): boolean }>(
  type: EquatableType<T>, x: T | null | undefined, y: T | null | undefined): boolean {
  if (x === null || x === undefined) {
    return y === null || y === undefined;
  }
  if (y === null || y === undefined) {
    return false;
  }
  // As the core's Equals: false (never an error) when either isn't a T.
  return x instanceof type && x.Equals(y);
}

/** Compares with one of NodaTime's comparers (`OffsetDateTime.Comparer.Local`, ...), nulls first. */
export function CompareWith<T>(
  comparer: { Compare(x: T, y: T): number }, x: T | null | undefined, y: T | null | undefined): number {
  if (x === null || x === undefined) {
    return y === null || y === undefined ? 0 : -1;
  }
  if (y === null || y === undefined) {
    return 1;
  }
  return comparer.Compare(x, y);
}

/** Equates with one of NodaTime's equality comparers (`OffsetDateTime.Comparer.Local`, ...); nulls equal each other. */
export function EqualsWith<T>(
  comparer: { Equals(x: T, y: T): boolean }, x: T | null | undefined, y: T | null | undefined): boolean {
  if (x === null || x === undefined) {
    return y === null || y === undefined;
  }
  if (y === null || y === undefined) {
    return false;
  }
  return comparer.Equals(x, y);
}
