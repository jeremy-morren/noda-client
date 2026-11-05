// NodaCultureInfo.CurrentCulture and Register (noda-js additions): the culture of the host's preferred language,
// among the registered cultures (the noda-js/cultures cultures register themselves when used), and how the library
// behaves when navigator or Intl is not available.

import { afterEach, describe, expect, it, vi } from "vitest";
import { CompareInfo, CompareOptions, NodaCultureInfo } from "../src/noda-js/internal.ts";
import { enAU, enGB, es419, esES, esMX } from "../src/noda-js/Cultures/index.generated.ts";

/** Pretends the host's languages are these (navigator.languages, as in a browser). */
function hostLanguages(...languages: string[]): void {
  vi.stubGlobal("navigator", { languages, language: languages[0] });
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("CurrentCulture", () => {
  // Using the cultures registers them (their modules create them with FromDataRegistered).
  const used = [enAU, enGB, esES, esMX, es419];

  it("registers the cultures an app uses", () => {
    hostLanguages("es-MX");
    expect(used).toHaveLength(5);
    expect(NodaCultureInfo.CurrentCulture).toBe(esMX);
  });

  it("matches the exact culture name, case-insensitively", () => {
    hostLanguages("EN-gb");
    expect(NodaCultureInfo.CurrentCulture).toBe(enGB);
    hostLanguages("es-419");
    expect(NodaCultureInfo.CurrentCulture).toBe(es419);
  });

  it("falls back to the first registered culture of the language", () => {
    hostLanguages("es-AR"); // not registered: Spanish → es-ES, the first Spanish culture registered
    expect(NodaCultureInfo.CurrentCulture.Name.startsWith("es-")).toBe(true);
    hostLanguages("en");
    expect(NodaCultureInfo.CurrentCulture.Name.startsWith("en-")).toBe(true);
  });

  it("prefers a culture named by the language alone", () => {
    const neutral = NodaCultureInfo.FromData({ ...esES, Name: "es", DateTimeFormat: esES.DateTimeFormat } as never);
    NodaCultureInfo.Register(neutral);
    hostLanguages("es-AR");
    expect(NodaCultureInfo.CurrentCulture).toBe(neutral);
  });

  it("takes the host's languages in order of preference", () => {
    hostLanguages("xx-YY", "en-AU", "es-ES");
    expect(NodaCultureInfo.CurrentCulture).toBe(enAU);
  });

  it("throws, naming the host's languages, when none matches a registered culture", () => {
    hostLanguages("xx-YY", "zz");
    expect(() => NodaCultureInfo.CurrentCulture).toThrowNodaError("InvalidOperationException");
    expect(() => NodaCultureInfo.CurrentCulture).toThrow(/xx-YY, zz/);
  });

  it("uses navigator.language when there's no navigator.languages", () => {
    vi.stubGlobal("navigator", { language: "en-GB" });
    expect(NodaCultureInfo.CurrentCulture).toBe(enGB);
  });

  it("uses navigator.language when navigator.languages is empty or isn't an array", () => {
    vi.stubGlobal("navigator", { languages: [], language: "en-GB" });
    expect(NodaCultureInfo.CurrentCulture).toBe(enGB);
    vi.stubGlobal("navigator", { languages: "es-MX", language: "en-GB" });
    expect(NodaCultureInfo.CurrentCulture).toBe(enGB);
  });

  it("uses Intl's default locale when navigator has neither languages nor a language", () => {
    vi.stubGlobal("navigator", { language: 42 });
    const locale = new Intl.DateTimeFormat().resolvedOptions().locale;
    expect(() => NodaCultureInfo.CurrentCulture).not.toThrow(/The host reports no languages/);
    expect(locale).not.toBe("");
  });

  it("uses Intl's default locale without a navigator", () => {
    vi.stubGlobal("navigator", undefined);
    const locale = new Intl.DateTimeFormat().resolvedOptions().locale;
    NodaCultureInfo.Register(NodaCultureInfo.FromData({ ...enGB, Name: locale, DateTimeFormat: enGB.DateTimeFormat } as never));
    expect(NodaCultureInfo.CurrentCulture.Name).toBe(locale);
  });

  it("throws a clear error on a host with neither navigator nor Intl", () => {
    vi.stubGlobal("navigator", undefined);
    vi.stubGlobal("Intl", undefined);
    expect(() => NodaCultureInfo.CurrentCulture).toThrow(/The host reports no languages/);
  });

  it("doesn't register the invariant culture, and only registers cultures", () => {
    NodaCultureInfo.Register(NodaCultureInfo.InvariantCulture);
    hostLanguages("");
    expect(() => NodaCultureInfo.CurrentCulture).toThrowNodaError("InvalidOperationException");
    expect(() => NodaCultureInfo.Register({} as NodaCultureInfo)).toThrowNodaError("ArgumentException");
  });
});

describe("CompareInfo without Intl", () => {
  it("compares case-insensitively and ordinally without Intl.Collator", () => {
    vi.stubGlobal("Intl", undefined);
    const compareInfo = new CompareInfo("es-ES");
    expect(compareInfo.Compare("ENERO", "enero", CompareOptions.IgnoreCase)).toBe(0);
    expect(compareInfo.Compare("enero", "febrero", CompareOptions.IgnoreCase)).toBeLessThan(0);
    expect(compareInfo.Compare("a", "b", CompareOptions.None)).toBeLessThan(0);
    expect(compareInfo.Compare("a", "A", CompareOptions.None)).not.toBe(0);
  });
});
