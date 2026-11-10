// noda-js: new code.
/// <reference lib="es2020.bigint" />
//
// A BigInt-backed drop-in for the members of long.js's `Long` that noda-js uses, with long.js's exact semantics
// (test/long/LongBigInt.test.ts). The only BigInt user in src/: loading it calls no BigInt, and it has no `1n` literals.

import type LongJs from "long";

/** What long.js accepts wherever it takes another value (its `LongLike`). */
type LongLike = Long | number | bigint | string | { low: number; high: number; unsigned: boolean };

const TWO_PWR_63_DBL = 9223372036854775808;

// The constants, made by Init().
let Zero: bigint;
let Big32: bigint;
let MinSafe: bigint;
let MaxSafe: bigint;
let ZeroLong: Long | undefined;
let OneLong: Long;
let NegOneLong: Long;
let MaxLong: Long;
let MinLong: Long;

/** Makes the constants, on the first call. Every static member calls this, so instance members can use them. */
function Init(): void {
  if (ZeroLong === undefined) {
    Zero = BigInt(0);
    Big32 = BigInt(32);
    MinSafe = BigInt(-9007199254740991);
    MaxSafe = BigInt(9007199254740991);
    ZeroLong = Long.Of(Zero);
    OneLong = Long.Of(BigInt(1));
    NegOneLong = Long.Of(BigInt(-1));
    MaxLong = Long.fromBits(0xffffffff | 0, 0x7fffffff | 0);
    MinLong = Long.fromBits(0, 0x80000000 | 0);
  }
}

/** The 64-bit two's-complement value of an integer (wrapping, as long.js's arithmetic does). */
function Wrap(value: bigint): bigint {
  return BigInt.asIntN(64, value);
}

/** The value of a LongLike (long.js's fromValue). */
function ValueOf(value: LongLike): bigint {
  if (value instanceof Long) {
    return value.value;
  }
  if (typeof value === "number") {
    return Long.fromNumber(value).value;
  }
  if (typeof value === "bigint") {
    return Wrap(value);
  }
  if (typeof value === "string") {
    return Long.fromString(value).value;
  }
  return Long.fromBits(value.low, value.high, value.unsigned).value;
}

function Unsupported(): never {
  throw new Error("noda-js's BigInt Long only supports signed values.");
}

/** A signed 64-bit two's-complement integer, as long.js's `Long` (the members noda-js uses). */
export default class Long {
  /** @internal The value, always within the signed 64-bit range. */
  readonly value: bigint;

  private constructor(value: bigint) {
    this.value = value;
  }

  /** @internal A Long of a value within the signed 64-bit range. */
  static Of(value: bigint): Long {
    return new Long(value);
  }

  static get ZERO(): Long {
    Init();
    return ZeroLong!;
  }

  static get ONE(): Long {
    Init();
    return OneLong;
  }

  static get NEG_ONE(): Long {
    Init();
    return NegOneLong;
  }

  static get MAX_VALUE(): Long {
    Init();
    return MaxLong;
  }

  static get MIN_VALUE(): Long {
    Init();
    return MinLong;
  }

  /** The Long of a 32-bit integer (value | 0). */
  static fromInt(value: number, unsigned?: boolean): Long {
    if (unsigned) {
      Unsupported();
    }
    Init();
    return new Long(BigInt(value | 0));
  }

  /** The Long nearest a number: truncated towards zero, saturating at MIN_VALUE and MAX_VALUE; NaN gives ZERO. */
  static fromNumber(value: number, unsigned?: boolean): Long {
    if (unsigned) {
      Unsupported();
    }
    Init();
    if (isNaN(value)) {
      return ZeroLong!;
    }
    if (value <= -TWO_PWR_63_DBL) {
      return MinLong;
    }
    if (value + 1 >= TWO_PWR_63_DBL) {
      return MaxLong;
    }
    return new Long(BigInt(Math.trunc(value)));
  }

  /** The Long of the given low and high 32 bits (each taken as a 32-bit integer). */
  static fromBits(lowBits: number, highBits: number, unsigned?: boolean): Long {
    if (unsigned) {
      Unsupported();
    }
    Init();
    return new Long((BigInt(highBits | 0) << Big32) | BigInt(lowBits >>> 0));
  }

  /** The Long of a string in the given radix, parsed exactly as long.js parses it. */
  static fromString(str: string, unsigned?: boolean | number, radix?: number): Long {
    if (str.length === 0) {
      throw new Error("empty string");
    }
    Init();
    if (typeof unsigned === "number") {
      // For goog.math.long compatibility (as long.js).
      radix = unsigned;
    } else if (unsigned) {
      Unsupported();
    }
    if (str === "NaN" || str === "Infinity" || str === "+Infinity" || str === "-Infinity") {
      return Long.ZERO;
    }
    radix = radix || 10;
    if (radix < 2 || 36 < radix) {
      throw new RangeError("radix");
    }
    const p = str.indexOf("-");
    if (p > 0) {
      throw new Error("interior hyphen");
    } else if (p === 0) {
      return Long.fromString(str.substring(1), false, radix).neg();
    }
    const radixToPower = Long.fromNumber(Math.pow(radix, 8)).value;
    let result = Zero;
    for (let i = 0; i < str.length; i += 8) {
      const size = Math.min(8, str.length - i);
      const value = Long.fromNumber(parseInt(str.substring(i, i + size), radix)).value;
      const power = size < 8 ? Long.fromNumber(Math.pow(radix, size)).value : radixToPower;
      result = Wrap(result * power + value);
    }
    return new Long(result);
  }

  /** The high 32 bits, as a signed 32-bit integer. */
  get high(): number {
    return Number(BigInt.asIntN(32, this.value >> Big32));
  }

  /** The low 32 bits, as a signed 32-bit integer. */
  get low(): number {
    return Number(BigInt.asIntN(32, this.value));
  }

  add(addend: LongLike): Long {
    return new Long(Wrap(this.value + ValueOf(addend)));
  }

  sub(subtrahend: LongLike): Long {
    return new Long(Wrap(this.value - ValueOf(subtrahend)));
  }

  mul(multiplier: LongLike): Long {
    return new Long(Wrap(this.value * ValueOf(multiplier)));
  }

  /** Division truncating towards zero (MIN_VALUE / -1 wraps to MIN_VALUE). Throws for a zero divisor. */
  div(divisor: LongLike): Long {
    const d = ValueOf(divisor);
    if (d === Zero) {
      throw new Error("division by zero");
    }
    return new Long(Wrap(this.value / d));
  }

  /** The remainder of {@link div}, with the dividend's sign. Throws for a zero divisor. */
  mod(divisor: LongLike): Long {
    const d = ValueOf(divisor);
    if (d === Zero) {
      throw new Error("division by zero");
    }
    return new Long(this.value % d);
  }

  /** -this (wrapping: -MIN_VALUE is MIN_VALUE). */
  neg(): Long {
    return new Long(Wrap(-this.value));
  }

  eq(other: LongLike): boolean {
    return this.value === ValueOf(other);
  }

  /** -1, 0 or 1 as this is less than, equal to or greater than other. */
  compare(other: LongLike): number {
    const o = ValueOf(other);
    return this.value < o ? -1 : this.value > o ? 1 : 0;
  }

  lt(other: LongLike): boolean {
    return this.value < ValueOf(other);
  }

  gt(other: LongLike): boolean {
    return this.value > ValueOf(other);
  }

  gte(other: LongLike): boolean {
    return this.value >= ValueOf(other);
  }

  isZero(): boolean {
    return this.value === Zero;
  }

  isNegative(): boolean {
    return this.value < Zero;
  }

  /** Whether the value is within ±(2^53 - 1). */
  isSafeInteger(): boolean {
    return this.value >= MinSafe && this.value <= MaxSafe;
  }

  /** Arithmetic right shift by numBits & 63. */
  shr(numBits: number | Long): Long {
    const bits = (typeof numBits === "number" ? numBits : numBits.toInt()) & 63;
    return bits === 0 ? this : new Long(this.value >> BigInt(bits));
  }

  /** The low 32 bits, as a signed 32-bit integer. */
  toInt(): number {
    return this.low;
  }

  /** The nearest double. */
  toNumber(): number {
    return Number(this.value);
  }

  /** The value in the given radix (2-36, default 10), lower case, with a leading `-` when negative. */
  toString(radix?: number): string {
    radix = radix || 10;
    if (radix < 2 || 36 < radix) {
      throw new RangeError("radix");
    }
    return this.value.toString(radix);
  }
}

// Checks this is a drop-in for long.js's Long: each member noda-js uses has long.js's signature.
type Swap<T> = T extends LongJs ? Long : T;
type Mirror<Source, Members extends keyof Source> = {
  [K in Members]: Source[K] extends (...args: infer A) => infer R ? (...args: { [I in keyof A]: Swap<A[I]> }) => Swap<R> : Swap<Source[K]>;
};
type InstanceMembers = "high" | "low" | "add" | "sub" | "mul" | "div" | "mod" | "neg" | "eq" | "compare" | "lt" | "gt" | "gte" |
  "isZero" | "isNegative" | "isSafeInteger" | "shr" | "toInt" | "toNumber" | "toString";
type StaticMembers = "ZERO" | "ONE" | "NEG_ONE" | "MAX_VALUE" | "MIN_VALUE" | "fromInt" | "fromNumber" | "fromBits" | "fromString";
type AssertDropIn<T extends Mirror<LongJs, InstanceMembers>, S extends Mirror<typeof LongJs, StaticMembers>> = [T, S];
type LongBigIntIsDropIn = AssertDropIn<Long, typeof Long>;
