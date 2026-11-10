// Assertions for ported NodaTime tests (NUnit's Assert.AreEqual on NodaTime values uses Equals()).

import { expect } from "vitest";
import { IsNodaError } from "../../src/noda-js/internal.ts";
import type { NodaErrorCode, NodaErrorType } from "../../src/noda-js/internal.ts";

interface Equatable {
  Equals(other: unknown): boolean;
}

function isEquatable(value: unknown): value is Equatable {
  return typeof value === "object" && value !== null && typeof (value as Equatable).Equals === "function";
}

/** NUnit's Assert.AreEqual; a bigint expected value is compared as the nearest number. */
export function assertNodaEqual(actual: unknown, expected: unknown, message?: string): void {
  if (typeof expected === "bigint" && typeof actual === "number") {
    expected = Number(expected);
  }
  if (isEquatable(expected) && isEquatable(actual)) {
    if (!expected.Equals(actual)) {
      expect.fail(`${message ? message + ": " : ""}expected ${describe(expected)} but was ${describe(actual)}`);
    }
    return;
  }
  if (Array.isArray(expected) && Array.isArray(actual)) {
    expect(actual.length, message).toBe(expected.length);
    expected.forEach((e, i) => assertNodaEqual(actual[i], e, `${message ?? ""}[${i}]`));
    return;
  }
  expect(actual, message).toEqual(expected);
}

function describe(value: unknown): string {
  try {
    return String(value);
  } catch {
    return Object.prototype.toString.call(value);
  }
}

function Describe(e: unknown): string {
  return IsNodaError(e) ? `${e.Codes[0]}: ${e.message}` : `${(e as Error)?.name}: ${(e as Error)?.message}`;
}

/** NUnit's Assert.Throws<T>: a NodaError code must match exactly, as NUnit requires the exact type. */
export function assertThrows<TCode extends NodaErrorCode>(code: TCode, action: () => unknown): NodaErrorType<TCode>;
export function assertThrows<T extends Error>(errorType: abstract new (...args: any[]) => T, action: () => unknown): T;
export function assertThrows(expected: NodaErrorCode | (abstract new (...args: any[]) => Error), action: () => unknown): Error {
  const name = typeof expected === "string" ? expected : expected.name;
  try {
    action();
  } catch (e) {
    if (typeof expected === "string" ? IsNodaError(e) && e.Codes[0] === expected : e instanceof expected) {
      return e as Error;
    }
    throw new Error(`Expected ${name} but got ${Describe(e)}`, { cause: e });
  }
  throw new Error(`Expected ${name} but nothing was thrown`);
}
