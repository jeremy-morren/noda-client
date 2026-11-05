// noda-js on a host without the web APIs it can use: no Intl, navigator, TextDecoder, atob, Uint8Array.fromBase64 or
// performance (as in embedded or scripting JavaScript engines). The library is loaded fresh with those globals
// removed, so nothing it caches at load time comes from a full environment. Everything that doesn't need the host's
// time zones or languages must work; what does must fail with a clear error.
// (Node only: it removes globals and re-imports the modules; see vitest.config.ts.)

import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

type Core = typeof import("../src/noda-js/index.ts");

let noda: Core;
let tzdb: typeof import("../src/noda-js/entries/tzdb-bundled.ts").tzdb;
let browser: typeof import("../src/noda-js/entries/browser.ts").browser;
let cultures: typeof import("../src/noda-js/Cultures/index.generated.ts");
let fromBase64: PropertyDescriptor | undefined;
const now = Date.now();

beforeAll(async () => {
  for (const name of ["Intl", "navigator", "TextDecoder", "atob", "performance"]) {
    vi.stubGlobal(name, undefined);
  }
  fromBase64 = Object.getOwnPropertyDescriptor(Uint8Array, "fromBase64");
  if (fromBase64 !== undefined) {
    delete (Uint8Array as unknown as { fromBase64?: unknown }).fromBase64;
  }
  vi.resetModules();
  noda = await import("../src/noda-js/index.ts");
  ({ tzdb } = await import("../src/noda-js/entries/tzdb-bundled.ts"));
  ({ browser } = await import("../src/noda-js/entries/browser.ts"));
  cultures = await import("../src/noda-js/Cultures/index.generated.ts");
  // Re-importing (and transforming) the whole library takes seconds, more when the full suite runs alongside.
}, 120_000);

afterAll(() => {
  vi.unstubAllGlobals();
  if (fromBase64 !== undefined) {
    Object.defineProperty(Uint8Array, "fromBase64", fromBase64);
  }
  vi.resetModules();
});

describe("without Intl, navigator, TextDecoder, atob, Uint8Array.fromBase64 or performance", () => {
  it("really has none of them", () => {
    expect(typeof Intl).toBe("undefined");
    expect(typeof navigator).toBe("undefined");
    expect(typeof TextDecoder).toBe("undefined");
    expect(typeof atob).toBe("undefined");
    expect(typeof performance).toBe("undefined");
    expect("fromBase64" in Uint8Array).toBe(false);
  });

  it("loads the bundled tzdb and converts between zones", () => {
    const instant = noda.Instant.FromUtc(2024, 7, 1, 12, 0);
    expect(instant.InZone(tzdb.Get("Europe/Madrid")).toString()).toBe("2024-07-01T14:00:00 Europe/Madrid (+02)");
    expect(instant.InZone(tzdb.Get("Australia/Sydney")).toString()).toBe("2024-07-01T22:00:00 Australia/Sydney (+10)");
    expect(tzdb.Ids.length).toBeGreaterThan(500);
  });

  it("formats and parses, in the invariant culture and others (names match case-insensitively)", () => {
    const date = new noda.LocalDate(2024, 7, 1);
    expect(date.toString("d MMMM uuuu", null)).toBe("1 July 2024");
    const spanish = noda.LocalDatePattern.Create("d 'de' MMMM 'de' uuuu", cultures.esES);
    expect(spanish.Format(date)).toBe("1 de julio de 2024");
    // Month names match case-insensitively (quoted literals such as 'de' match exactly, as in NodaTime).
    expect(spanish.Parse("1 de JULIO de 2024").Value.Equals(date)).toBe(true);
  });

  it("reads and writes JSON", () => {
    const zoned = noda.Instant.FromUtc(2024, 7, 1, 12, 0).InZone(tzdb.Get("Europe/Madrid"));
    const json = zoned.toJSON();
    expect(json).toBe("2024-07-01T14:00:00+02 Europe/Madrid");
    expect(noda.ZonedDateTime.fromJSON(json, tzdb).Equals(zoned)).toBe(true);
    expect(noda.Period.fromJSON("P1Y2M3DT4H").toString()).toBe("P1Y2M3DT4H");
  });

  it("reads the system clock from Date.now()", () => {
    const current = noda.SystemClock.Instance.GetCurrentInstant().ToUnixTimeMilliseconds();
    expect(current).toBeGreaterThanOrEqual(now);
    expect(current).toBeLessThan(now + 60_000);
  });

  it("CurrentCulture throws a clear error: the host reports no languages", () => {
    expect(() => noda.NodaCultureInfo.CurrentCulture).toThrow(noda.InvalidOperationError);
    expect(() => noda.NodaCultureInfo.CurrentCulture).toThrow(/The host reports no languages/);
  });

  it("the tzdb provider can't name the system's zone: GetSystemDefault throws DateTimeZoneNotFoundError", () => {
    expect(() => tzdb.GetSystemDefault()).toThrow(noda.DateTimeZoneNotFoundError);
  });

  it("noda-js/browser says it needs Intl, on first use", () => {
    expect(() => browser.Ids).toThrow(noda.InvalidOperationError);
    expect(() => browser.Ids).toThrow(/needs the host's Intl/);
  });
});
