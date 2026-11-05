// Every test runs with every calendar system registered (noda-js/calendars/all), as NodaTime's tests assume.
// test/bundle/ checks that bundles leave out the calendars an app doesn't import.
import "../src/noda-js/entries/calendars/all.ts";

// Matchers for NodaErrors (the .NET library exceptions NodaTime throws): the error's own code (the first of its Codes)
// must be exactly the one given,
// as NUnit's Assert.Throws<T> requires the exact type. `expect(action).toThrowNodaError("ArgumentException")`, also
// with `.rejects`; `expect(error).toBeNodaError("FormatException")`.
import { expect } from "vitest";
import { IsNodaError } from "../src/noda-js/internal.ts";
import type { NodaErrorCode } from "../src/noda-js/internal.ts";

function Describe(value: unknown): string {
  return IsNodaError(value) ? `${value.Codes[0]}: ${value.message}` : value instanceof Error ? `${value.name}: ${value.message}` : String(value);
}

expect.extend({
  toThrowNodaError(received: unknown, code: NodaErrorCode) {
    let error: unknown;
    let threw = false;
    if (typeof received === "function") {
      try {
        (received as () => unknown)();
      } catch (e) {
        error = e;
        threw = true;
      }
    } else {
      // With .rejects: the rejection reason.
      error = received;
      threw = true;
    }
    const pass = threw && IsNodaError(error) && error.Codes[0] === code;
    return {
      pass,
      message: () => pass
        ? `expected not to throw ${code}`
        : threw ? `expected ${code}, but got ${Describe(error)}` : `expected ${code}, but nothing was thrown`,
    };
  },
  toBeNodaError(received: unknown, code: NodaErrorCode) {
    const pass = IsNodaError(received) && received.Codes[0] === code;
    return { pass, message: () => pass ? `expected not to be ${code}` : `expected ${code}, but got ${Describe(received)}` };
  },
});

interface NodaErrorMatchers<R = unknown> {
  /** The action throws (or the promise rejects with) a NodaError whose Code is exactly `code`. */
  toThrowNodaError(code: NodaErrorCode): R;
  /** The value is a NodaError whose Code is exactly `code`. */
  toBeNodaError(code: NodaErrorCode): R;
}

declare module "vitest" {
  // eslint-disable-next-line @typescript-eslint/no-empty-object-type
  interface Matchers<R extends void | Promise<void> = void | Promise<void>, T = unknown> extends NodaErrorMatchers<R> {}
}
