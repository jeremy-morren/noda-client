// Utility/Encoding.ts: UTF-8 and base64 decoding for NZD (tzdb) data. DecodeUtf8 and DecodeBase64 use the host's
// TextDecoder / Uint8Array.fromBase64 / atob when available, and the plain-JavaScript fallbacks otherwise (web APIs not
// available): every path must give the same results.

import { afterEach, describe, expect, it, vi } from "vitest";
import { DecodeBase64, DecodeBase64Fallback, DecodeUtf8, DecodeUtf8Fallback } from "../src/noda-js/Utility/Encoding.ts";
import { nzdBase64 } from "../src/noda-js/TimeZones/TzdbBundledData.generated.ts";
import { TzdbDateTimeZoneSource } from "../src/noda-js/internal.ts";

const encoder = new TextEncoder();

describe("DecodeUtf8Fallback", () => {
  it.each([
    "", "ASCII text", "Zürich, Réunion", "Ελληνικά", "日本語", "😀 emoji (4 bytes) 🇪🇸", "\u0000\u007f\u0080߿ࠀ￿",
  ])("decodes %j as TextDecoder does", (text) => {
    const bytes = encoder.encode(text);
    expect(DecodeUtf8Fallback(bytes)).toBe(new TextDecoder("utf-8").decode(bytes));
  });

  it("decodes long text (more code points than one String.fromCodePoint call takes)", () => {
    const text = "aé日😀".repeat(5000);
    expect(DecodeUtf8Fallback(encoder.encode(text))).toBe(text);
  });
});

describe("DecodeBase64Fallback", () => {
  it.each([0, 1, 2, 3, 4, 5, 100, 1001])("decodes %i random bytes as atob does", (length) => {
    const bytes = new Uint8Array(length);
    for (let i = 0; i < length; i++) {
      bytes[i] = Math.floor(Math.random() * 256);
    }
    const text = btoa(String.fromCharCode(...bytes));
    expect(Array.from(DecodeBase64Fallback(text))).toEqual(Array.from(bytes));
    // Unpadded input too.
    expect(Array.from(DecodeBase64Fallback(text.replace(/=+$/, "")))).toEqual(Array.from(bytes));
  });

  it("rejects characters outside the base64 alphabet", () => {
    expect(() => DecodeBase64Fallback("ab$d")).toThrowNodaError("FormatException");
  });

  it("decodes the bundled tzdb, which then loads", () => {
    const bytes = DecodeBase64Fallback(nzdBase64);
    const binary = atob(nzdBase64);
    expect(bytes.length).toBe(binary.length);
    const source = TzdbDateTimeZoneSource.FromBytes(bytes);
    expect(source.ForId("Europe/Madrid").Id).toBe("Europe/Madrid");
  });
});

describe("DecodeUtf8Fallback with invalid input", () => {
  it("decodes an invalid lead byte as U+FFFD", () => {
    expect(DecodeUtf8Fallback(new Uint8Array([0x41, 0xff, 0x42]))).toBe("A\ufffdB");
    expect(DecodeUtf8Fallback(new Uint8Array([0x80]))).toBe("\ufffd"); // a continuation byte can't lead
  });
});

// The dispatching functions, on each path: with the host's APIs, and with them removed (as on a host without them).
describe("DecodeUtf8 and DecodeBase64", () => {
  const text = "Zürich 日本 😀";
  const bytes = encoder.encode(text);
  const base64 = btoa(String.fromCharCode(...bytes));

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("use the host's TextDecoder and base64 decoding when available", () => {
    expect(DecodeUtf8(bytes)).toBe(text);
    expect(Array.from(DecodeBase64(base64))).toEqual(Array.from(bytes));
  });

  it("DecodeUtf8 falls back without TextDecoder", () => {
    vi.stubGlobal("TextDecoder", undefined);
    expect(DecodeUtf8(bytes)).toBe(text);
  });

  it("DecodeBase64 uses atob without Uint8Array.fromBase64, and the fallback without either", () => {
    const fromBase64 = Object.getOwnPropertyDescriptor(Uint8Array, "fromBase64");
    try {
      if (fromBase64 !== undefined) {
        delete (Uint8Array as unknown as { fromBase64?: unknown }).fromBase64;
      }
      expect(Array.from(DecodeBase64(base64))).toEqual(Array.from(bytes)); // atob
      vi.stubGlobal("atob", undefined);
      expect(Array.from(DecodeBase64(base64))).toEqual(Array.from(bytes)); // plain JavaScript
    } finally {
      if (fromBase64 !== undefined) {
        Object.defineProperty(Uint8Array, "fromBase64", fromBase64);
      }
    }
  });

  it("load the bundled tzdb with no web APIs at all", () => {
    const fromBase64 = Object.getOwnPropertyDescriptor(Uint8Array, "fromBase64");
    try {
      if (fromBase64 !== undefined) {
        delete (Uint8Array as unknown as { fromBase64?: unknown }).fromBase64;
      }
      vi.stubGlobal("atob", undefined);
      vi.stubGlobal("TextDecoder", undefined);
      const source = TzdbDateTimeZoneSource.FromBase64(nzdBase64);
      expect(source.TzdbVersion).toMatch(/^\d{4}[a-z]$/);
      expect(source.ForId("Australia/Sydney").Id).toBe("Australia/Sydney");
    } finally {
      if (fromBase64 !== undefined) {
        Object.defineProperty(Uint8Array, "fromBase64", fromBase64);
      }
    }
  });
});
