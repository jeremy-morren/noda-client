// Assertions for ported NodaTime tests (NUnit's Assert.AreEqual on NodaTime values uses Equals()).

import { expect } from "vitest";

interface Equatable {
  Equals(other: unknown): boolean;
}

function isEquatable(value: unknown): value is Equatable {
  return typeof value === "object" && value !== null && typeof (value as Equatable).Equals === "function";
}

/**
 * Like NUnit's Assert.AreEqual(expected, actual): uses equals() for noda-js values. A bigint expected value (a C# long)
 * is compared with a number actual value as the nearest number, as noda-js returns C# long results as numbers.
 */
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

/** Like NUnit's Assert.Throws<T>(action): returns the error. */
export function assertThrows<T extends Error>(errorType: abstract new (...args: any[]) => T, action: () => unknown): T {
  try {
    action();
  } catch (e) {
    if (e instanceof errorType) {
      return e;
    }
    throw new Error(`Expected ${errorType.name} but got ${(e as Error)?.name}: ${(e as Error)?.message}`, { cause: e });
  }
  throw new Error(`Expected ${errorType.name} but nothing was thrown`);
}
