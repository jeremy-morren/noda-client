// noda-js: a small exact signed integer of any size, for the few NodaTime code paths that compute with decimal or
// BigInteger: Duration values whose nanosecond count is beyond the long range (Duration's range is about
// +/- 1.45e21 nanoseconds, or 2^70), and the products and quotients NodaTime computes in decimal there.
// It is only used on those rare paths; everything else uses numbers, or Long (the long.js package) for C# long values.
//
// Values are held as a sign and a magnitude in little-endian base-2^16 limbs, so limb products (and sums of them)
// stay exact in doubles. Division is binary long division: simple, and fast enough for ~170-bit values.
// Leaf module: imports only other leaf modules.

import Long from "long";
import type { Int64Value } from "./Numbers.ts";
import { OverflowError } from "./SystemExceptions.ts";

const Base = 0x10000;

/** Magnitude comparison. */
function CompareMagnitudes(a: readonly number[], b: readonly number[]): number {
  if (a.length !== b.length) {
    return a.length < b.length ? -1 : 1;
  }
  for (let i = a.length - 1; i >= 0; i--) {
    if (a[i] !== b[i]) {
      return a[i]! < b[i]! ? -1 : 1;
    }
  }
  return 0;
}

/** Removes most significant zero limbs (in place). */
function Trim(limbs: number[]): number[] {
  while (limbs.length > 0 && limbs[limbs.length - 1] === 0) {
    limbs.pop();
  }
  return limbs;
}

function AddMagnitudes(a: readonly number[], b: readonly number[]): number[] {
  const result: number[] = [];
  let carry = 0;
  for (let i = 0; i < Math.max(a.length, b.length) || carry !== 0; i++) {
    const sum = (a[i] ?? 0) + (b[i] ?? 0) + carry;
    result.push(sum % Base);
    carry = sum >= Base ? 1 : 0;
  }
  return Trim(result);
}

/** a - b, where a >= b. */
function SubtractMagnitudes(a: readonly number[], b: readonly number[]): number[] {
  const result: number[] = [];
  let borrow = 0;
  for (let i = 0; i < a.length; i++) {
    let difference = a[i]! - (b[i] ?? 0) - borrow;
    borrow = difference < 0 ? 1 : 0;
    if (difference < 0) {
      difference += Base;
    }
    result.push(difference);
  }
  return Trim(result);
}

function MultiplyMagnitudes(a: readonly number[], b: readonly number[]): number[] {
  const result: number[] = [];
  for (let i = 0; i < a.length + b.length; i++) {
    result.push(0);
  }
  for (let i = 0; i < a.length; i++) {
    let carry = 0;
    for (let j = 0; j < b.length; j++) {
      // At most (2^16-1)^2 + 2 * (2^16-1) < 2^32: exact.
      const product = a[i]! * b[j]! + result[i + j]! + carry;
      result[i + j] = product % Base;
      carry = Math.floor(product / Base);
    }
    result[i + b.length] = carry;
  }
  return Trim(result);
}

/** Truncating division of magnitudes: [quotient, remainder]. b must be non-zero. */
function DivideMagnitudes(a: readonly number[], b: readonly number[]): [number[], number[]] {
  if (CompareMagnitudes(a, b) < 0) {
    return [[], a.slice()];
  }
  const quotient: number[] = a.map(() => 0);
  let remainder: number[] = [];
  for (let i = a.length * 16 - 1; i >= 0; i--) {
    // remainder = remainder * 2 + bit i of a
    let carry = (a[i >>> 4]! >>> (i & 15)) & 1;
    for (let j = 0; j < remainder.length; j++) {
      const doubled = remainder[j]! * 2 + carry;
      remainder[j] = doubled & 0xffff;
      carry = doubled >>> 16;
    }
    if (carry !== 0) {
      remainder.push(carry);
    }
    if (CompareMagnitudes(remainder, b) >= 0) {
      remainder = SubtractMagnitudes(remainder, b);
      quotient[i >>> 4] = quotient[i >>> 4]! | (1 << (i & 15));
    }
  }
  return [Trim(quotient), remainder];
}

/**
 * An exact signed integer of any size. Immutable.
 * @internal
 */
export class WideInteger {
  /** Whether the value is negative (never true for zero). */
  readonly Negative: boolean;
  /** The magnitude, in little-endian base-2^16 limbs, with no most significant zero limbs (so zero has none). */
  private readonly _limbs: readonly number[];

  private constructor(negative: boolean, limbs: readonly number[]) {
    this.Negative = negative && limbs.length > 0;
    this._limbs = limbs;
  }

  static readonly Zero: WideInteger = new WideInteger(false, []);

  /** The exact value of an integral number (of any magnitude). */
  static FromNumber(value: number): WideInteger {
    if (!Number.isInteger(value)) {
      throw new RangeError(`Expected an integer; got ${value}`);
    }
    const limbs: number[] = [];
    let magnitude = Math.abs(value);
    while (magnitude > 0) {
      const limb = magnitude % Base;
      limbs.push(limb);
      magnitude = (magnitude - limb) / Base;
    }
    return new WideInteger(value < 0, limbs);
  }

  /** The exact value of a signed Long. */
  static FromLong(value: Long): WideInteger {
    const negative = value.isNegative();
    // (The negation of long.MinValue is itself, whose bits read as unsigned are its magnitude, 2^63.)
    const magnitude = negative ? value.neg() : value;
    const low = magnitude.low >>> 0, high = magnitude.high >>> 0;
    return new WideInteger(negative, Trim([low & 0xffff, low >>> 16, high & 0xffff, high >>> 16]));
  }

  /** The exact value of an Int64Value. */
  static FromInt64(value: Int64Value): WideInteger {
    return typeof value === "number" ? WideInteger.FromNumber(value) : WideInteger.FromLong(value);
  }

  /** 10^exponent. */
  static PowerOfTen(exponent: number): WideInteger {
    let result = WideInteger.FromNumber(1);
    const ten = WideInteger.FromNumber(10);
    for (let i = 0; i < exponent; i++) {
      result = result.Multiply(ten);
    }
    return result;
  }

  get IsZero(): boolean {
    return this._limbs.length === 0;
  }

  get IsOdd(): boolean {
    return this._limbs.length > 0 && (this._limbs[0]! & 1) === 1;
  }

  /** -1, 0 or 1. */
  get Sign(): number {
    return this.IsZero ? 0 : this.Negative ? -1 : 1;
  }

  Negate(): WideInteger {
    return new WideInteger(!this.Negative, this._limbs);
  }

  Abs(): WideInteger {
    return this.Negative ? this.Negate() : this;
  }

  Add(other: WideInteger): WideInteger {
    if (this.Negative === other.Negative) {
      return new WideInteger(this.Negative, AddMagnitudes(this._limbs, other._limbs));
    }
    const comparison = CompareMagnitudes(this._limbs, other._limbs);
    return comparison >= 0
      ? new WideInteger(this.Negative, SubtractMagnitudes(this._limbs, other._limbs))
      : new WideInteger(other.Negative, SubtractMagnitudes(other._limbs, this._limbs));
  }

  Subtract(other: WideInteger): WideInteger {
    return this.Add(other.Negate());
  }

  Multiply(other: WideInteger): WideInteger {
    return new WideInteger(this.Negative !== other.Negative, MultiplyMagnitudes(this._limbs, other._limbs));
  }

  /**
   * Truncating division, as C# integer division: the quotient is rounded towards zero, and the remainder has the
   * sign of the dividend.
   */
  DivRem(divisor: WideInteger): [quotient: WideInteger, remainder: WideInteger] {
    if (divisor.IsZero) {
      throw new RangeError("Division by zero");
    }
    const [quotient, remainder] = DivideMagnitudes(this._limbs, divisor._limbs);
    return [new WideInteger(this.Negative !== divisor.Negative, quotient), new WideInteger(this.Negative, remainder)];
  }

  CompareTo(other: WideInteger): number {
    if (this.Negative !== other.Negative) {
      return this.Negative ? -1 : 1;
    }
    const comparison = CompareMagnitudes(this._limbs, other._limbs);
    return this.Negative ? -comparison : comparison;
  }

  /** Compares the absolute values. */
  CompareMagnitudeTo(other: WideInteger): number {
    return CompareMagnitudes(this._limbs, other._limbs);
  }

  /** The value as a number: exact up to 2^53 in magnitude. */
  ToNumber(): number {
    let result = 0;
    for (let i = this._limbs.length - 1; i >= 0; i--) {
      result = result * Base + this._limbs[i]!;
    }
    return this.Negative ? -result : result;
  }

  /**
   * The value as a C# long, in the Int64Value form.
   * @throws {OverflowError} The value is outside the range of a C# long.
   */
  ToInt64(): Int64Value {
    const limbs = this._limbs;
    if (limbs.length <= 3) {
      return this.ToNumber();
    }
    // 2^63 is the largest magnitude (only for a negative value).
    if (limbs.length > 4 || limbs[3]! > 0x8000 ||
      (limbs[3] === 0x8000 && (!this.Negative || limbs[0] !== 0 || limbs[1] !== 0 || limbs[2] !== 0))) {
      throw new OverflowError("Value was either too large or too small for an Int64.");
    }
    const magnitude = Long.fromBits(limbs[0]! | (limbs[1]! << 16), limbs[2]! | (limbs[3]! << 16));
    const value = this.Negative ? magnitude.neg() : magnitude;
    return value.isSafeInteger() ? value.toNumber() : value;
  }

  /** The decimal representation of the value. */
  toString(): string {
    if (this.IsZero) {
      return "0";
    }
    let digits = "";
    let magnitude: number[] = this._limbs.slice();
    const tenThousand = [10000];
    while (magnitude.length > 0) {
      const [quotient, remainder] = DivideMagnitudes(magnitude, tenThousand);
      const chunk = String(remainder[0] ?? 0);
      magnitude = quotient;
      digits = (magnitude.length > 0 ? "0000".substring(chunk.length) + chunk : chunk) + digits;
    }
    return (this.Negative ? "-" : "") + digits;
  }
}
