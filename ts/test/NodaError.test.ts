// NodaError's Codes and IsNodaError.

import { describe, expect, it } from "vitest";
import {
  AmbiguousTimeException,
  DateTimeZoneNotFoundException,
  GetAllNodaErrorCodes,
  GetNodaErrorCodes,
  Instant,
  IsNodaError,
  LocalDateTime,
  NewArgumentException,
  NewArgumentOutOfRangeException,
  NewFormatException,
  NodaError,
  SkippedTimeException,
  UnparsableValueException,
} from "../src/noda-js/internal.ts";
import { tzdb } from "../src/noda-js/entries/tzdb-bundled.ts";

describe("Codes", () => {
  it("are each type, then its base types, nearest first: the type, then its base's Codes", () => {
    for (const code of GetAllNodaErrorCodes()) {
      const codes = GetNodaErrorCodes(code) as readonly string[];
      expect(codes[0], code).toBe(code);
      expect(codes, code).not.toContain("Exception");
      expect(new Set(codes).size, code).toBe(codes.length);
      if (codes.length > 1) {
        expect(GetAllNodaErrorCodes(), code).toContain(codes[1]);
        expect(GetNodaErrorCodes(codes[1] as typeof code), code).toEqual(codes.slice(1));
      }
    }
  });

  it("are on every error, never empty, and shared and frozen", () => {
    const skipped = new SkippedTimeException(new LocalDateTime(2024, 3, 31, 2, 30), tzdb.Get("Europe/Madrid"));
    expect(skipped.Codes).toEqual(["SkippedTimeException", "ArgumentOutOfRangeException", "ArgumentException", "SystemException"]);
    expect(skipped.name).toBe("SkippedTimeException");
    expect(NewFormatException().Codes).toEqual(["FormatException", "SystemException"]);
    expect(new DateTimeZoneNotFoundException("x").Codes).toEqual(["DateTimeZoneNotFoundException", "TimeZoneNotFoundException"]);
    expect(new NodaError("InvalidNodaDataException", "x").Codes).toEqual(["InvalidNodaDataException"]);
    expect(NewFormatException().Codes).toBe(NewFormatException().Codes);
    expect(Object.isFrozen(skipped.Codes)).toBe(true);
  });
});

describe("IsNodaError", () => {
  const madrid = tzdb.Get("Europe/Madrid");
  const skipped = new SkippedTimeException(new LocalDateTime(2024, 3, 31, 2, 30), madrid);
  const local = new LocalDateTime(2024, 10, 27, 2, 30);
  const ambiguous = new AmbiguousTimeException(
    local.InZoneLeniently(madrid), Instant.FromUtc(2024, 10, 27, 1, 30).InZone(madrid));

  it("matches the code and the base codes, as a C# catch clause matches a type and the types derived from it", () => {
    for (const code of ["SkippedTimeException", "ArgumentOutOfRangeException", "ArgumentException", "SystemException"] as const) {
      expect(IsNodaError(skipped, code), code).toBe(true);
    }
    expect(IsNodaError(skipped, "AmbiguousTimeException")).toBe(false);
    expect(IsNodaError(skipped, "ArgumentNullException")).toBe(false);
    expect(IsNodaError(skipped, "FormatException")).toBe(false);
    expect(IsNodaError(ambiguous, "ArgumentOutOfRangeException")).toBe(true);
    expect(IsNodaError(NewArgumentOutOfRangeException("x"), "ArgumentException")).toBe(true);
    expect(IsNodaError(NewArgumentException("x"), "ArgumentOutOfRangeException")).toBe(false);
    expect(IsNodaError(new UnparsableValueException("x"), "FormatException")).toBe(true);
    expect(IsNodaError(new DateTimeZoneNotFoundException("x"), "TimeZoneNotFoundException")).toBe(true);
  });

  it("without a code: any NodaError, including one from another copy of noda-js (by shape)", () => {
    expect(IsNodaError(skipped)).toBe(true);
    expect(IsNodaError(new Error("x"))).toBe(false);
    expect(IsNodaError(null)).toBe(false);
    expect(IsNodaError({ Codes: ["FormatException"] })).toBe(false); // Not an Error.
    const foreign = Object.assign(new Error("x"), { Codes: ["SkippedTimeException"] });
    expect(IsNodaError(foreign, "ArgumentException")).toBe(true);
    expect(IsNodaError(Object.assign(new Error("x"), { Codes: ["NoSuchException"] }))).toBe(false);
    expect(IsNodaError(Object.assign(new Error("x"), { Codes: [] }))).toBe(false);
  });

  it("narrows to the type, with its members", () => {
    const error: unknown = skipped;
    if (IsNodaError(error, "ArgumentOutOfRangeException")) {
      expect(error.ParamName).toBeNull();
      const own: "ArgumentOutOfRangeException" | "SkippedTimeException" | "AmbiguousTimeException" = error.Codes[0];
      expect(own).toBe("SkippedTimeException");
    }
    if (IsNodaError(error, "SkippedTimeException")) {
      expect(error.Zone).toBe(madrid);
      const first: "ArgumentOutOfRangeException" = error.Codes[1];
      expect(first).toBe("ArgumentOutOfRangeException");
    }
  });
});
