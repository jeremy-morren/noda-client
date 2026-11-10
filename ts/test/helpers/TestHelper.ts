// Ported from NodaTime 6e024dde: src/NodaTime.Test/TestHelper.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { assertThrows } from "./assertions.ts";
import { IsNodaError, type ArgumentException, type ArgumentOutOfRangeException, type InvalidOperationException, type OverflowException } from "../../src/noda-js/internal.ts";

interface Comparable<T> {
  CompareTo(other: T | null): number;
}

interface Equatable {
  Equals(other: unknown): boolean;
}

/** Provides methods to help run tests for some of the system interfaces and object support. */
export const TestHelper = {
  /** Does nothing other than let a variable appear to be used (C# Consume). */
  consume(_ignored: unknown): void {},

  /** Asserts that func(...args) throws ArgumentException (exactly, as NUnit's Assert.Throws does). */
  assertInvalid(func: (...args: any[]) => unknown, ...args: unknown[]): void {
    const e = assertThrows("ArgumentException", () => func(...args));
    expect(e).not.toBeNodaError("ArgumentNullException");
  },

  assertArgumentNull(func: (...args: any[]) => unknown, ...args: unknown[]): void {
    assertThrows("ArgumentNullException", () => func(...args));
  },

  assertOutOfRange(func: (...args: any[]) => unknown, ...args: unknown[]): void {
    assertThrows("ArgumentOutOfRangeException", () => func(...args));
  },

  assertValid(func: (...args: any[]) => unknown, ...args: unknown[]): void {
    func(...args);
  },

  /**
   * Asserts that the action throws OverflowException, ArgumentException (exactly, or
   * ArgumentOutOfRangeException) or InvalidOperationException.
   */
  assertOverflow(action: () => unknown): void {
    try {
      action();
    } catch (e) {
      if (IsNodaError(e, "OverflowException") || IsNodaError(e, "InvalidOperationException")) {
        return;
      }
      if (IsNodaError(e, "ArgumentException") || IsNodaError(e, "ArgumentOutOfRangeException")) {
        expect(IsNodaError(e, "ArgumentNullException"), "Exception should not be a subtype of ArgumentException, other than ArgumentOutOfRangeException").toBe(false);
        return;
      }
      throw e;
    }
    expect.fail("Expected OverflowException, ArgumentException, ArgumentOutOfRangeException or InvalidOperationException");
  },

  assertNoFailures<T>(failures: Iterable<T>, failureFormatter: (failure: T) => string): void {
    const failureList = [...failures];
    if (failureList.length === 0) {
      return;
    }
    expect.fail(`Failures: ${failureList.length}\n${failureList.map(failureFormatter).join("\n")}`);
  },

  /** Tests a comparer (C# IComparer<T>, here anything with compare(a, b)). */
  testComparerStruct<T>(comparer: { Compare(x: T, y: T): number }, value: T, equalValue: T, greaterValue: T): void {
    expect(comparer.Compare(value, equalValue)).toBe(0);
    expect(Math.sign(comparer.Compare(greaterValue, value))).toBe(1);
    expect(Math.sign(comparer.Compare(value, greaterValue))).toBe(-1);
  },

  testCompareToClass<T extends Comparable<T>>(value: T, equalValue: T, ...greaterValues: T[]): void {
    validateInput(value, equalValue, greaterValues, "greaterValue");
    expect(value.CompareTo(null), "value.CompareTo<T>(null)").toBeGreaterThan(0);
    TestHelper.testCompareToStruct(value, equalValue, ...greaterValues);
  },

  testCompareToStruct<T extends Comparable<T>>(value: T, equalValue: T, ...greaterValues: T[]): void {
    expect(value.CompareTo(value), "value.CompareTo(value)").toBe(0);
    expect(value.CompareTo(equalValue), "value.CompareTo(equalValue)").toBe(0);
    expect(equalValue.CompareTo(value), "equalValue.CompareTo(value)").toBe(0);
    for (const greaterValue of greaterValues) {
      expect(value.CompareTo(greaterValue), "value.CompareTo(greaterValue)").toBeLessThan(0);
      expect(greaterValue.CompareTo(value), "greaterValue.CompareTo(value)").toBeGreaterThan(0);
      // Now move up to the next pair...
      value = greaterValue;
    }
  },

  /** C#'s non-generic IComparable.CompareTo(object), folded into CompareTo. */
  testNonGenericCompareTo<T extends Comparable<T>>(value: T, equalValue: T, ...greaterValues: T[]): void {
    validateInput(value, equalValue, greaterValues, "greaterValues");
    expect(value.CompareTo(null), "value.CompareTo(null)").toBeGreaterThan(0);
    TestHelper.testCompareToStruct(value, equalValue, ...greaterValues);
    const last = greaterValues.length > 0 ? greaterValues[greaterValues.length - 1]! : value;
    assertThrows("ArgumentException", () => last.CompareTo({} as T));
  },

  testEqualsClass<T extends Equatable>(value: T, equalValue: T, ...unequalValues: T[]): void {
    TestHelper.testObjectEquals(value, equalValue, ...unequalValues);
  },

  testEqualsStruct<T extends Equatable>(value: T, equalValue: T, ...unequalValues: T[]): void {
    TestHelper.testObjectEquals(value, equalValue, ...unequalValues);
  },

  testObjectEquals(value: Equatable, equalValue: Equatable, ...unequalValues: unknown[]): void {
    validateInput(value, equalValue, unequalValues, "unequalValue");
    expect(value.Equals(null), "value.Equals(null)").toBe(false);
    expect(value.Equals(value), "value.Equals(value)").toBe(true);
    expect(value.Equals(equalValue), "value.Equals(equalValue)").toBe(true);
    expect(equalValue.Equals(value), "equalValue.Equals(value)").toBe(true);
    for (const unequalValue of unequalValues) {
      expect(value.Equals(unequalValue), "value.Equals(unequalValue)").toBe(false);
    }
    // Not ported: GetHashCode checks.
    expect(value.Equals({}), "Equals with the wrong type").toBe(false);
  },

  /** C# < and > operators → CompareTo. */
  testOperatorComparison<T extends Comparable<T>>(value: T, equalValue: T, ...greaterValues: T[]): void {
    validateInput(value, equalValue, greaterValues, "greaterValue");
    expect(value.CompareTo(value) > 0, "value > value").toBe(false);
    expect(value.CompareTo(equalValue) > 0, "value > equalValue").toBe(false);
    expect(equalValue.CompareTo(value) > 0, "equalValue > value").toBe(false);
    expect(value.CompareTo(value) < 0, "value < value").toBe(false);
    expect(value.CompareTo(equalValue) < 0, "value < equalValue").toBe(false);
    expect(equalValue.CompareTo(value) < 0, "equalValue < value").toBe(false);
    for (const greaterValue of greaterValues) {
      expect(value.CompareTo(greaterValue) > 0, "value > greaterValue").toBe(false);
      expect(greaterValue.CompareTo(value) > 0, "greaterValue > value").toBe(true);
      expect(value.CompareTo(greaterValue) < 0, "value < greaterValue").toBe(true);
      expect(greaterValue.CompareTo(value) < 0, "greaterValue < value").toBe(false);
      // Now move up to the next pair...
      value = greaterValue;
    }
  },

  /** C# ==, !=, <, <=, >, >= → Equals/CompareTo. */
  testOperatorComparisonEquality<T extends Comparable<T> & Equatable>(value: T, equalValue: T, ...greaterValues: T[]): void {
    for (const greaterValue of greaterValues) {
      TestHelper.testOperatorEquality(value, equalValue, greaterValue);
    }
    TestHelper.testOperatorComparison(value, equalValue, ...greaterValues);
    expect(value.CompareTo(value) >= 0, "value >= value").toBe(true);
    expect(value.CompareTo(equalValue) >= 0, "value >= equalValue").toBe(true);
    expect(value.CompareTo(value) <= 0, "value <= value").toBe(true);
    expect(value.CompareTo(equalValue) <= 0, "value <= equalValue").toBe(true);
    for (const greaterValue of greaterValues) {
      expect(value.CompareTo(greaterValue) >= 0, "value >= greaterValue").toBe(false);
      expect(greaterValue.CompareTo(value) >= 0, "greaterValue >= value").toBe(true);
      expect(value.CompareTo(greaterValue) <= 0, "value <= greaterValue").toBe(true);
      expect(greaterValue.CompareTo(value) <= 0, "greaterValue <= value").toBe(false);
      // Now move up to the next pair...
      value = greaterValue;
    }
  },

  /** C# == and != → equals. */
  testOperatorEquality<T extends Equatable>(value: T, equalValue: T, unequalValue: T): void {
    validateInput(value, equalValue, [unequalValue], "unequalValue");
    expect(value.Equals(value), "value == value").toBe(true);
    expect(value.Equals(equalValue), "value == equalValue").toBe(true);
    expect(equalValue.Equals(value), "equalValue == value").toBe(true);
    expect(value.Equals(unequalValue), "value == unequalValue").toBe(false);
    expect(!value.Equals(unequalValue), "value != unequalValue").toBe(true);
  },

  /** C# IMinMaxValue<T>: checks the type's static MinValue/MaxValue. */
  assertMinMaxValue<T extends Equatable>(type: { MinValue: T; MaxValue: T }, min: T, max: T): void {
    expect(type.MinValue.Equals(min), "MinValue").toBe(true);
    expect(type.MaxValue.Equals(max), "MaxValue").toBe(true);
  },

  // Not ported: AssertXmlRoundtrip, AssertParsableXml, AssertXmlInvalid (XML serialization isn't ported).
} as const;

function validateInput(value: unknown, equalValue: unknown, unequalValues: readonly unknown[], unequalName: string): void {
  expect(value, "value cannot be null in the test").not.toBeNull();
  expect(equalValue, "equalValue cannot be null in the test").not.toBeNull();
  expect(value !== equalValue || typeof value !== "object", "value and equalValue MUST be different objects").toBe(true);
  for (const unequalValue of unequalValues) {
    expect(unequalValue, `${unequalName} cannot be null in the test`).not.toBeNull();
    expect(unequalValue === value && typeof value === "object", `${unequalName} and value MUST be different objects`).toBe(false);
  }
}
