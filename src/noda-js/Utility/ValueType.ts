// noda-js: shared behaviour for NodaTime's value types.

/**
 * Throws a TypeError. Every value type's valueOf() calls this, so that relational operators
 * (`a < b`) and arithmetic fail loudly instead of comparing something meaningless. Use
 * compareTo() / equals() instead.
 * @internal
 */
export function ThrowValueOf(typeName: string): never {
  throw new TypeError(`${typeName} cannot be converted to a primitive; use compareTo() or equals() instead of relational operators.`);
}
