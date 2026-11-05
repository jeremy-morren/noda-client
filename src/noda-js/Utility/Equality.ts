// noda-js: .NET's IEquatable<T> and IComparable<T> / IComparable, which NodaTime's value types implement.
// Internal only (not exported from any entry point): they document and type-check the equals/compareTo
// contract that every implementing class follows. See docs/porting-conventions.md ("Types and members").

/**
 * .NET's `IEquatable<T>.Equals(T)` together with the `object.Equals(object)` override.
 *
 * Implementations accept any value and check `instanceof` the class before looking at its fields, so
 * `equals(null)`, `equals(undefined)`, `equals({})` and `equals(someOtherNodaType)` all return false
 * without throwing (as `object.Equals(object)` does in C#).
 *
 * Not part of the public API (no entry point exports it), but deliberately not tagged internal: public declarations refer to it,
 * so it must stay in the published type declarations.
 */
export interface IEquatable<T> {
  /** IEquatable<T>.Equals(T): true if `other` is equal to this value. */
  Equals(other: T): boolean;
  /** object.Equals(object): true if `other` is a T equal to this value; false for anything else. */
  Equals(other: unknown): boolean;
}

/**
 * .NET's `IComparable<T>.CompareTo(T)` together with the non-generic `IComparable.CompareTo(object)`.
 *
 * Implementations return a positive number for `null` (and `undefined`): in .NET, null compares less
 * than any value. Any other value that isn't an instance of the class throws `ArgumentError` (C#'s
 * `ArgumentException` from the non-generic CompareTo).
 *
 * Not part of the public API (no entry point exports it), but deliberately not tagged internal: public declarations refer to it,
 * so it must stay in the published type declarations.
 */
export interface IComparable<T> {
  /** IComparable<T>.CompareTo(T): negative, zero or positive as this value is less than, equal to or greater than `other`. */
  CompareTo(other: T | null): number;
  /** IComparable.CompareTo(object): as above for a T; positive for null; throws ArgumentError for anything else. */
  CompareTo(other: unknown): number;
}
