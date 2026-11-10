// LongBigInt must give exactly long.js's results (and errors), on edge and random values.

import LongJs from "long";
import { describe, expect, it } from "vitest";
import LongBigInt from "../../src/noda-js/Utility/LongBigInt.ts";

type AnyLong = LongJs | LongBigInt;

// Deterministic (mulberry32), so a failure reproduces.
function Random(seed: number): () => number {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const random = Random(20261108);
const randomInt32 = (): number => (random() * 4294967296) | 0;

const edgeStrings = [
  "0", "1", "-1", "2", "-2", "3", "-3", "7", "10", "-10", "255", "256", "1000000",
  "2147483647", "-2147483648", "2147483648", "-2147483649", "2147483646",
  "4294967295", "4294967296", "4294967297", "-4294967295", "-4294967296", "-4294967297",
  "9007199254740991", "9007199254740992", "9007199254740993", "-9007199254740991", "-9007199254740992", "-9007199254740993",
  "18014398509481984", "-18014398509481985", "864000000000", "86400000000000", "-86400000000000",
  "9223372036854775807", "-9223372036854775808", "9223372036854775806", "-9223372036854775807",
  "4611686018427387904", "-4611686018427387904", "3037000499", "3037000500", "-3037000500",
];
const values: [LongJs, LongBigInt][] = edgeStrings.map((s) => [LongJs.fromString(s), LongBigInt.fromString(s)]);
for (let i = 0; i < 40; i++) {
  const low = randomInt32(), high = randomInt32();
  values.push([LongJs.fromBits(low, high), LongBigInt.fromBits(low, high)]);
}
for (let i = 0; i < 20; i++) {
  // Around 2^53 and 2^32, both signs.
  const near = (random() < 0.5 ? 1 : -1) * ((random() < 0.5 ? 9007199254740992 : 4294967296) + Math.floor(random() * 2048) - 1024);
  values.push([LongJs.fromNumber(near), LongBigInt.fromNumber(near)]);
}

/** long.js's WebAssembly division is wrong for high bits -2^31 divided by -1 (noda-js never divides by -1). */
function LongJsDivBug(a: LongJs, b: LongJs | number): boolean {
  return a.high === -0x80000000 && LongJs.NEG_ONE.eq(b);
}

function Describe(value: unknown): unknown {
  if (value instanceof LongJs || value instanceof LongBigInt) {
    const long = value as AnyLong;
    return { long: long.toString(), high: long.high, low: long.low };
  }
  if (typeof value === "number") {
    // Object.is semantics (-0, NaN) through a string.
    return Object.is(value, -0) ? "-0" : String(value);
  }
  return value;
}

function Outcome(fn: () => unknown): unknown {
  try {
    return Describe(fn());
  } catch {
    return "throws";
  }
}

function Same(name: string, js: () => unknown, big: () => unknown): void {
  expect(Outcome(big), name).toEqual(Outcome(js));
}

const numbers = [
  0, -0, 1, -1, 0.5, -0.5, 1.9, -1.9, 2147483647, -2147483648, 2147483648, -2147483649, 4294967295, 4294967296,
  -4294967296, 4294967296.7, 9007199254740991, -9007199254740991, 9007199254740992, -9007199254740992, 9007199254740994,
  1e15 + 0.5, -1e15 - 0.5, 1e18, -1e18, 9223372036854774784, -9223372036854774784, 9223372036854775807,
  9223372036854775808, -9223372036854775808, -9223372036854777856, 1e19, -1e19, 1e300, -1e300, Number.MAX_VALUE,
  -Number.MAX_VALUE, Number.MIN_VALUE, Infinity, -Infinity, NaN,
];
for (let i = 0; i < 40; i++) {
  numbers.push((random() - 0.5) * Math.pow(2, Math.floor(random() * 70)));
}

describe("LongBigInt matches long.js", () => {
  it("constants", () => {
    for (const name of ["ZERO", "ONE", "NEG_ONE", "MAX_VALUE", "MIN_VALUE"] as const) {
      Same(name, () => LongJs[name], () => LongBigInt[name]);
    }
  });

  it("fromInt, fromNumber", () => {
    for (const n of numbers) {
      Same(`fromInt(${n})`, () => LongJs.fromInt(n), () => LongBigInt.fromInt(n));
      Same(`fromNumber(${n})`, () => LongJs.fromNumber(n), () => LongBigInt.fromNumber(n));
    }
  });

  it("fromBits", () => {
    const bits = [0, 1, -1, 0x7fffffff, -0x80000000, 0xffffffff, 0x100000000, 1.5, -1.5, NaN, 2 ** 40 + 3];
    for (const low of bits) {
      for (const high of bits) {
        Same(`fromBits(${low}, ${high})`, () => LongJs.fromBits(low, high), () => LongBigInt.fromBits(low, high));
      }
    }
  });

  it("fromString", () => {
    const strings = [
      ...edgeStrings, "", "-", "+5", "007", "-007", "NaN", "Infinity", "+Infinity", "-Infinity", "1-2", "--5", "abc",
      "12ab34", "1.5", " 12", "9223372036854775808", "-9223372036854775809", "18446744073709551616", "99999999999999999999",
      "123456789012345678901234567890", "ffffffffffffffff", "-8000000000000000", "zz",
    ];
    for (const s of strings) {
      Same(`fromString("${s}")`, () => LongJs.fromString(s), () => LongBigInt.fromString(s));
      for (const radix of [2, 8, 16, 36, 1, 37]) {
        Same(`fromString("${s}", ${radix})`, () => LongJs.fromString(s, radix), () => LongBigInt.fromString(s, radix));
        Same(`fromString("${s}", false, ${radix})`, () => LongJs.fromString(s, false, radix), () => LongBigInt.fromString(s, false, radix));
      }
    }
  });

  it("unary members: high, low, neg, isZero, isNegative, isSafeInteger, toInt, toNumber, toString", () => {
    for (const [js, big] of values) {
      const name = js.toString();
      Same(`${name}.high`, () => js.high, () => big.high);
      Same(`${name}.low`, () => js.low, () => big.low);
      Same(`${name}.neg()`, () => js.neg(), () => big.neg());
      Same(`${name}.isZero()`, () => js.isZero(), () => big.isZero());
      Same(`${name}.isNegative()`, () => js.isNegative(), () => big.isNegative());
      Same(`${name}.isSafeInteger()`, () => js.isSafeInteger(), () => big.isSafeInteger());
      Same(`${name}.toInt()`, () => js.toInt(), () => big.toInt());
      Same(`${name}.toNumber()`, () => js.toNumber(), () => big.toNumber());
      for (const radix of [undefined, 2, 7, 10, 16, 36, 1, 37]) {
        Same(`${name}.toString(${radix})`, () => js.toString(radix), () => big.toString(radix));
      }
    }
  });

  it("shr", () => {
    for (const [js, big] of values) {
      for (const bits of [0, 1, 2, 14, 31, 32, 33, 52, 53, 62, 63, 64, 65, 100, -1, -33]) {
        Same(`${js}.shr(${bits})`, () => js.shr(bits), () => big.shr(bits));
        Same(`${js}.shr(Long ${bits})`, () => js.shr(LongJs.fromInt(bits)), () => big.shr(LongBigInt.fromInt(bits)));
      }
    }
  });

  it("binary members: add, sub, mul, div, mod, eq, compare, lt, gt, gte", () => {
    const operations = ["add", "sub", "mul", "div", "mod", "eq", "compare", "lt", "gt", "gte"] as const;
    for (const [a, bigA] of values) {
      for (const [b, bigB] of values) {
        for (const op of operations) {
          Same(`${a}.${op}(${b})`, () => op === "div" && LongJsDivBug(a, b) ? a.neg() : (a[op] as (x: LongJs) => unknown)(b),
            () => (bigA[op] as (x: LongBigInt) => unknown)(bigB));
        }
      }
      // Other operands: numbers (fromNumber), strings (fromString) and { low, high } objects, as long.js takes them.
      for (const other of [0, 1, -1, 3, 10, 52734375, 864000000000, 2.5, -2.5, 9007199254740993, 1e19, NaN, "86400", "-9223372036854775808"]) {
        for (const op of operations) {
          Same(`${a}.${op}(${other})`,
            () => op === "div" && typeof other === "number" && LongJsDivBug(a, other) ? a.neg() : (a[op] as (x: unknown) => unknown)(other),
            () => (bigA[op] as (x: unknown) => unknown)(other));
        }
      }
      const bits = { low: 5, high: -7, unsigned: false };
      Same(`${a}.add(${JSON.stringify(bits)})`, () => a.add(bits), () => bigA.add(bits));
    }
  });

  it("division by zero throws", () => {
    for (const [js, big] of values) {
      expect(() => js.div(0)).toThrow();
      expect(() => big.div(0)).toThrow();
      expect(() => big.mod(LongBigInt.ZERO)).toThrow();
    }
  });

  it("wraps: MIN_VALUE.neg(), MIN_VALUE / -1, MAX_VALUE + 1, MIN_VALUE * -1", () => {
    expect(LongBigInt.MIN_VALUE.neg().eq(LongBigInt.MIN_VALUE)).toBe(true);
    expect(LongBigInt.MIN_VALUE.div(-1).eq(LongBigInt.MIN_VALUE)).toBe(true);
    expect(LongBigInt.MIN_VALUE.mod(-1).isZero()).toBe(true);
    expect(LongBigInt.MAX_VALUE.add(1).eq(LongBigInt.MIN_VALUE)).toBe(true);
    expect(LongBigInt.MIN_VALUE.mul(-1).eq(LongBigInt.MIN_VALUE)).toBe(true);
  });
});
