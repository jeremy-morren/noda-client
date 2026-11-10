// noda-js: new code. C# integer semantics on JS numbers; see docs/porting-conventions.md ("Numbers").

import { NewFormatException, NewOverflowException, type FormatException, type OverflowException } from "../internal.ts";
import Long from "./Long.ts";

/** An exact C# long: a number when it's a safe integer (never -0), otherwise a {@link Long}; one form per value. @internal */
export type Int64Value = number | Long;

/** @internal C# int (System.Int32) helpers. */
export const Int32 = {
  MinValue: -2147483648,
  MaxValue: 2147483647,
  /** Checked arithmetic result: throws OverflowException (as checked C# arithmetic does) if x isn't in the int range. */
  Checked(x: number): number {
    if (x < -2147483648 || x > 2147483647 || Number.isNaN(x)) {
      throw NewOverflowException();
    }
    return x;
  },
  /** C# integer division (truncating towards zero). */
  Div(a: number, b: number): number {
    return Math.trunc(a / b);
  },
  /** unchecked((int) x) */
  Wrap(x: number): number {
    return x | 0;
  },
} as const;

/** The JS number nearest to long.MaxValue (2^63). */
const TwoToThe63 = 9223372036854775808;

function Overflow(): never {
  throw NewOverflowException();
}

/** Converts a value to a Long (exactly). */
function ToLong(x: Int64Value): Long {
  return typeof x === "number" ? Long.fromNumber(x) : x;
}

/** The compact form of a Long. */
function Compact(x: Long): Int64Value {
  // (+ 0 turns -0 into 0, although Long.toNumber never returns -0.)
  return x.isSafeInteger() ? x.toNumber() : x;
}

function CheckedAdd(a: Long, b: Long): Long {
  const result = a.add(b);
  // Overflow iff both operands have the same sign and the result's sign differs.
  if (a.isNegative() === b.isNegative() && result.isNegative() !== a.isNegative()) {
    Overflow();
  }
  return result;
}

function CheckedSubtract(a: Long, b: Long): Long {
  const result = a.sub(b);
  // Overflow iff the operands have different signs and the result's sign differs from the minuend's.
  if (a.isNegative() !== b.isNegative() && result.isNegative() !== a.isNegative()) {
    Overflow();
  }
  return result;
}

function CheckedMultiply(a: Long, b: Long): Long {
  if (a.isZero() || b.isZero()) {
    return Long.ZERO;
  }
  const result = a.mul(b);
  // As Java's Math.multiplyExact. (Not dividing by -1, which long.js gets wrong: see Divide.)
  if ((a.eq(Long.MIN_VALUE) && b.eq(Long.NEG_ONE)) || (b.eq(Long.MIN_VALUE) && a.eq(Long.NEG_ONE)) ||
    (!b.eq(Long.NEG_ONE) && !result.div(b).eq(a))) {
    Overflow();
  }
  return result;
}

/** @internal C# long (System.Int64) helpers, for values held as numbers (safe integers) or in the {@link Int64Value} form. */
export const Int64 = {
  /** long.MinValue */
  get MinValue(): Long {
    return Long.MIN_VALUE;
  },
  /** long.MaxValue */
  get MaxValue(): Long {
    return Long.MAX_VALUE;
  },

  /** C# long division (truncating towards zero) on numbers. Exact when both operands are safe integers. */
  Div(a: number, b: number): number {
    return Math.trunc(a / b);
  },

  /** Converts a Long to the {@link Int64Value} form. */
  Compact,

  /** Converts an {@link Int64Value} to a Long. */
  ToLong,

  /** The JS number nearest to the value (exact up to 2^53). */
  ToNumber(x: Int64Value): number {
    return typeof x === "number" ? x : x.toNumber();
  },

  /** The invariant decimal representation of the value (as C# long.ToString(CultureInfo.InvariantCulture)). */
  ToString(x: Int64Value): string {
    return typeof x === "number" ? String(x) : x.toString();
  },

  /** Exact equality. */
  Equals(a: Int64Value, b: Int64Value): boolean {
    return typeof a === "number" || typeof b === "number" ? a === b : a.eq(b);
  },

  /** Exact comparison: negative, zero or positive as a is less than, equal to or greater than b. */
  Compare(a: Int64Value, b: Int64Value): number {
    if (typeof a === "number" && typeof b === "number") {
      return a < b ? -1 : a > b ? 1 : 0;
    }
    return ToLong(a).compare(ToLong(b));
  },

  /** Checked addition (throws OverflowException outside the long range). */
  Add(a: Int64Value, b: Int64Value): Int64Value {
    if (typeof a === "number" && typeof b === "number") {
      const result = a + b;
      if (Number.isSafeInteger(result)) {
        return result;
      }
    }
    return Compact(CheckedAdd(ToLong(a), ToLong(b)));
  },

  /** Checked subtraction (throws OverflowException outside the long range). */
  Subtract(a: Int64Value, b: Int64Value): Int64Value {
    if (typeof a === "number" && typeof b === "number") {
      const result = a - b;
      if (Number.isSafeInteger(result)) {
        return result;
      }
    }
    return Compact(CheckedSubtract(ToLong(a), ToLong(b)));
  },

  /** Checked multiplication (throws OverflowException outside the long range). */
  Multiply(a: Int64Value, b: Int64Value): Int64Value {
    if (typeof a === "number" && typeof b === "number") {
      // If the exact product is a safe integer, the double product is exact; otherwise it isn't a safe integer.
      const result = a * b;
      if (Number.isSafeInteger(result)) {
        return result + 0;
      }
    }
    return Compact(CheckedMultiply(ToLong(a), ToLong(b)));
  },

  /** C# long division (truncating towards zero). Throws OverflowException for long.MinValue / -1. b must be non-zero. */
  Divide(a: Int64Value, b: Int64Value): Int64Value {
    if (typeof a === "number" && typeof b === "number") {
      return Math.trunc(a / b) + 0;
    }
    const la = ToLong(a), lb = ToLong(b);
    if (lb.eq(Long.NEG_ONE)) {
      // Not la.div(lb): long.js's WebAssembly path mishandles divisors of -1.
      if (la.eq(Long.MIN_VALUE)) {
        Overflow();
      }
      return Compact(la.neg());
    }
    return Compact(la.div(lb));
  },

  /** C# long remainder (with the sign of the dividend). b must be non-zero. */
  Remainder(a: Int64Value, b: Int64Value): Int64Value {
    if (typeof a === "number" && typeof b === "number") {
      return (a % b) + 0;
    }
    const la = ToLong(a), lb = ToLong(b);
    if (lb.eq(Long.NEG_ONE)) {
      return 0;
    }
    return Compact(la.mod(lb));
  },

  /** Checked negation (throws OverflowException for long.MinValue). */
  Negate(x: Int64Value): Int64Value {
    if (typeof x === "number") {
      return 0 - x;
    }
    if (x.eq(Long.MIN_VALUE)) {
      Overflow();
    }
    return Compact(x.neg());
  },

  /**
   * Converts a public C# long argument (an integer number, 2^63 meaning long.MaxValue, or a decimal string) to an
   * {@link Int64Value}.
   * @throws {RangeError} A number isn't an integer within the long range.
   * @throws {FormatException} A string isn't a decimal integer.
   * @throws {OverflowException} A string is outside the long range.
   */
  FromArgument(value: number | string | Long, paramName: string): Int64Value {
    if (typeof value === "number") {
      if (Number.isSafeInteger(value)) {
        return value + 0;
      }
      if (!Number.isInteger(value) || value < -TwoToThe63 || value > TwoToThe63) {
        throw new RangeError(`Value for ${paramName} must be an integer within the range of a 64-bit integer: ${value}`);
      }
      return Long.fromNumber(value);
    }
    if (typeof value === "string") {
      return Int64.Parse(value);
    }
    return Compact(value);
  },

  /**
   * Parses a decimal integer exactly, as C# long.Parse with the invariant culture.
   * @throws {FormatException} The text isn't a decimal integer.
   * @throws {OverflowException} The value is outside the long range.
   */
  Parse(text: string): Int64Value {
    const match = /^([+-]?)0*(\d+)$/.exec(text);
    if (match === null) {
      throw NewFormatException(`The input string '${text}' was not in a correct format.`);
    }
    const negative = match[1] === "-";
    const digits = match[2]!;
    if (digits.length <= 15) {
      return negative ? 0 - Number(digits) : Number(digits);
    }
    const max = negative ? "9223372036854775808" : "9223372036854775807";
    if (digits.length > max.length || (digits.length === max.length && digits > max)) {
      throw NewOverflowException("Value was either too large or too small for an Int64.");
    }
    return Compact(Long.fromString(negative ? "-" + digits : digits));
  },
} as const;
