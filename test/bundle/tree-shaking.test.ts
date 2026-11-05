// Tree-shaking checks: bundle small apps with esbuild (production settings) and check
// that optional data (tzdb, browser zones, cultures) is only included when it's imported.

import { build } from "esbuild";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { nzdBase64 } from "../../src/noda-js/TimeZones/TzdbBundledData.generated.ts";

const root = fileURLToPath(new URL("../../", import.meta.url));
const nzdMarker = nzdBase64.substring(0, 40);

async function bundle(source: string): Promise<string> {
  const result = await build({
    stdin: { contents: source, resolveDir: root, loader: "ts", sourcefile: "app.ts" },
    bundle: true,
    write: false,
    minify: true,
    treeShaking: true,
    format: "esm",
    platform: "neutral",
    target: "es2015",
    logLevel: "silent",
  });
  return result.outputFiles[0]!.text;
}

describe("tree shaking", () => {
  it("core only: no tzdb data, browser source or cultures", async () => {
    const code = await bundle(`
      import { Instant, LocalDate, DateTimeZone, Offset, LocalDatePattern } from "./src/noda-js/index.ts";
      const zone = DateTimeZone.ForOffset(Offset.FromHours(10));
      console.log(JSON.stringify(Instant.FromUtc(2024, 1, 1, 0, 0).InZone(zone)), LocalDatePattern.Iso.Format(new LocalDate(2024, 3, 1)));
    `);
    expect(code).not.toContain(nzdMarker);
    expect(code).not.toContain("Africa/Abidjan");
    expect(code).not.toContain("supportedValuesOf");
    expect(code).not.toContain("janvier");
    expect(code).not.toContain("AUS Eastern Standard Time");
  }, 60000);

  it("browser only: no tzdb data", async () => {
    const code = await bundle(`
      import { browser } from "./src/noda-js/entries/browser.ts";
      console.log(browser.GetZoneOrNull("Europe/London"));
    `);
    expect(code).not.toContain(nzdMarker);
    expect(code).toContain("supportedValuesOf");
  }, 60000);

  it("tzdb runtime (no bundled data): reader present, no NZD", async () => {
    const code = await bundle(`
      import { TzdbDateTimeZoneSource } from "./src/noda-js/entries/tzdb.ts";
      export const load = (bytes: Uint8Array) => TzdbDateTimeZoneSource.FromBytes(bytes);
    `);
    expect(code).not.toContain(nzdMarker);
  }, 60000);

  it("tzdb bundled: NZD present (the checks can tell the difference)", async () => {
    const code = await bundle(`
      import { tzdb } from "./src/noda-js/entries/tzdb-bundled.ts";
      console.log(tzdb.get("Europe/London"));
    `);
    expect(code).toContain(nzdMarker);
  }, 60000);

  it("one culture: only that culture's data", async () => {
    const code = await bundle(`
      import { LocalDatePattern, LocalDate } from "./src/noda-js/index.ts";
      import { frFR } from "./src/noda-js/Cultures/fr-FR.generated.ts";
      console.log(LocalDatePattern.Create("d MMMM uuuu", frFR).Format(new LocalDate(2024, 1, 1)));
    `);
    expect(code).toContain("janvier");
    expect(code).not.toContain("März"); // de-DE
    expect(code).not.toContain(nzdMarker);
  }, 60000);

  it("cultures barrel (noda-js/cultures): only the imported culture's data", async () => {
    const code = await bundle(`
      import { LocalDatePattern, LocalDate } from "./src/noda-js/index.ts";
      import { frFR } from "./src/noda-js/Cultures/index.generated.ts";
      console.log(LocalDatePattern.Create("d MMMM uuuu", frFR).Format(new LocalDate(2024, 1, 1)));
    `);
    expect(code).toContain("janvier");
    expect(code).not.toContain("März"); // de-DE
    expect(code).not.toContain("enero"); // es-ES
    expect(code).not.toContain(nzdMarker);
  }, 60000);
});
