// Every calendar registered, as NodaTime's tests assume.
import "../src/noda-js/entries/calendars/all.ts";

// NodaError matchers: the code must match exactly, as NUnit's Assert.Throws<T> requires the exact type.
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
