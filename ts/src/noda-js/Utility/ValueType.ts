// noda-js: new code.

/** Throws a TypeError: value types' valueOf(), so `a < b` fails loudly (use CompareTo). @internal */
export function ThrowValueOf(typeName: string): never {
  throw new TypeError(`${typeName} cannot be converted to a primitive; use CompareTo() or Equals() instead of relational operators.`);
}
