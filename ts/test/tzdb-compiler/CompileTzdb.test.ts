// Compiling the tzdata release the bundled NZD came from must give exactly that NZD.

import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { CompileTzdb, CompileTzdbSync, CompileTzdbToNzd, CompileTzdbToNzdSync } from "../../src/noda-js/entries/tzdb-compiler.ts";
import { tzdbSource as bundledSource } from "../../src/noda-js/entries/tzdb-bundled.ts";
import { DateTimeZoneCache, Instant } from "../../src/noda-js/index.ts";
import { TzdbDateTimeZoneSource } from "../../src/noda-js/entries/tzdb.ts";
import { nzdBase64 } from "../../src/noda-js/TimeZones/TzdbBundledData.generated.ts";
import { DecodeBase64 } from "../../src/noda-js/Utility/Encoding.ts";
import { ReadTar } from "../../src/noda-js/TzdbCompiler/Tar.ts";
import tzdataUrl from "@testdata/tzdb/tzdata2026f.tar.gz?inline";
import tzdataPath from "@testdata/tzdb/tzdata2026f.tar.gz?url";

const timeout = 60_000;

let tarGz: Uint8Array;
let tar: Uint8Array;
const bundledNzd = DecodeBase64(nzdBase64);

beforeAll(async () => {
  tarGz = new Uint8Array(await (await fetch(tzdataUrl)).arrayBuffer());
  // Independently of the code under test.
  tar = new Uint8Array(await new Response(new Blob([tarGz as Uint8Array<ArrayBuffer>]).stream().pipeThrough(new DecompressionStream("gzip"))).arrayBuffer());
});

afterEach(() => {
  vi.unstubAllGlobals();
});

/** Reports the first difference rather than diffing ~100 KB. */
function expectSameBytes(actual: Uint8Array, expected: Uint8Array): void {
  let index = 0;
  while (index < actual.length && index < expected.length && actual[index] === expected[index]) {
    index++;
  }
  expect({ length: actual.length, firstDifference: index }).toEqual({ length: expected.length, firstDifference: expected.length });
}

describe("CompileTzdbToNzd", () => {
  it("compiles tzdata .tar.gz to the bundled NZD, byte for byte (host DecompressionStream)", async () => {
    expect(typeof DecompressionStream).toBe("function");
    expectSameBytes(await CompileTzdbToNzd(tarGz), bundledNzd);
  }, timeout);

  it("compiles tzdata .tar.gz to the bundled NZD with noda-js's own inflate (no DecompressionStream)", async () => {
    vi.stubGlobal("DecompressionStream", undefined);
    expectSameBytes(await CompileTzdbToNzd(tarGz.buffer.slice(tarGz.byteOffset, tarGz.byteOffset + tarGz.byteLength) as ArrayBuffer), bundledNzd);
  }, timeout);

  it("compiles an uncompressed tzdata .tar to the bundled NZD", async () => {
    expectSameBytes(await CompileTzdbToNzd(tar), bundledNzd);
  }, timeout);

  it("reads a File, and a stream (the inputs are covered in Input.test.ts)", async () => {
    expectSameBytes(await CompileTzdbToNzd(new File([tarGz as Uint8Array<ArrayBuffer>], "tzdata2026f.tar.gz")), bundledNzd);
    expectSameBytes(await CompileTzdbToNzd(new Blob([tar as Uint8Array<ArrayBuffer>]).stream()), bundledNzd);
  }, timeout);

  it("downloads a directory's files (a URL ending with /), getting the version from its name without a version file", async () => {
    const base = "https://cdn.jsdelivr.net/gh/eggert/tz@2026f/";
    const files = new Map([...ReadTar(tar)].map(([name, data]) => [name.replace(/.*\//, ""), data]));
    files.delete("version");
    vi.stubGlobal("fetch", (url: string) => {
      const file = files.get(url.substring(base.length));
      return Promise.resolve(file === undefined ? new Response("", { status: 404 }) : new Response(file as Uint8Array<ArrayBuffer>));
    });
    const log: string[] = [];
    expectSameBytes(await CompileTzdbToNzd(base, { Log: line => log.push(line) }), bundledNzd);
    expect(log).toContain("Inferred version 2026f from file/directory name tz@2026f");
  }, timeout);

  it("downloads a URL with fetch", async () => {
    const requests: string[] = [];
    vi.stubGlobal("fetch", (url: string) => {
      requests.push(url);
      return Promise.resolve(new Response(tarGz as Uint8Array<ArrayBuffer>));
    });
    const log: string[] = [];
    const nzd = await CompileTzdbToNzd(new URL("https://data.iana.org/time-zones/tzdata-latest.tar.gz"), { Log: line => log.push(line) });
    expect(requests).toEqual(["https://data.iana.org/time-zones/tzdata-latest.tar.gz"]);
    expectSameBytes(nzd, bundledNzd);
    // From the archive's version file (the Makefile and URL say "unknown").
    expect(log).toContain("Downloading https://data.iana.org/time-zones/tzdata-latest.tar.gz");
    expect(log).toContain("Inferred version 2026f from file/directory name tzdata2026f.tar");
    expect(log).toContain("Reading generated data and validating...");
  }, timeout);
});

/** A synchronous XMLHttpRequest stand-in serving `body` as the x-user-defined charset gives it. */
function FakeXhr(body: Uint8Array, status = 200, statusText = "OK"): { readonly Requests: string[]; readonly Class: unknown } {
  const requests: string[] = [];
  let text = "";
  for (const byte of body) {
    text += String.fromCharCode(byte < 0x80 ? byte : 0xf700 + byte);
  }
  class Xhr {
    status = 0;
    statusText = "";
    responseText = "";
    private _url = "";
    private _mimeType = "";
    open(method: string, url: string, async: boolean): void {
      requests.push(`${method} ${url} async=${async}`);
      this._url = url;
    }
    overrideMimeType(mimeType: string): void {
      this._mimeType = mimeType;
    }
    send(): void {
      expect(this._mimeType).toBe("text/plain; charset=x-user-defined");
      expect(this._url).not.toBe("");
      this.status = status;
      this.statusText = statusText;
      this.responseText = text;
    }
  }
  return { Requests: requests, Class: Xhr };
}

describe("CompileTzdbToNzdSync", () => {
  it("compiles tzdata .tar.gz to the bundled NZD, byte for byte (noda-js's own inflate)", () => {
    expectSameBytes(CompileTzdbToNzdSync(tarGz), bundledNzd);
  }, timeout);

  it("compiles an uncompressed tzdata .tar to the bundled NZD", () => {
    expectSameBytes(CompileTzdbToNzdSync(tar.buffer.slice(tar.byteOffset, tar.byteOffset + tar.byteLength) as ArrayBuffer), bundledNzd);
  }, timeout);

  it("downloads a URL with a synchronous XMLHttpRequest", () => {
    const xhr = FakeXhr(tarGz);
    vi.stubGlobal("XMLHttpRequest", xhr.Class);
    const log: string[] = [];
    const nzd = CompileTzdbToNzdSync(new URL("https://data.iana.org/time-zones/tzdata-latest.tar.gz"), { Log: line => log.push(line) });
    expect(xhr.Requests).toEqual(["GET https://data.iana.org/time-zones/tzdata-latest.tar.gz async=false"]);
    expectSameBytes(nzd, bundledNzd);
    expect(log).toContain("Downloading https://data.iana.org/time-zones/tzdata-latest.tar.gz");
    expect(log).toContain("Inferred version 2026f from file/directory name tzdata2026f.tar");
  }, timeout);

  it.runIf(typeof XMLHttpRequest === "function")("downloads from a server with the host's XMLHttpRequest", () => {
    expectSameBytes(CompileTzdbToNzdSync(new URL(tzdataPath, location.href).href), bundledNzd);
  }, timeout);
});

describe("CompileTzdbSync", () => {
  it("gives a validated source with the bundled tzdb's version", () => {
    const source = CompileTzdbSync(tarGz);
    expect(source).toBeInstanceOf(TzdbDateTimeZoneSource);
    expect(source.VersionId).toBe(bundledSource.VersionId);
    const zones = new DateTimeZoneCache(source);
    expect(Instant.FromUtc(2024, 7, 1, 12, 0).InZone(zones.Get("Australia/Sydney")).toString()).toBe("2024-07-01T22:00:00 Australia/Sydney (+10)");
  }, timeout);
});

describe("CompileTzdb", () => {
  it("gives a validated source with the bundled tzdb's version and zones", async () => {
    const source = await CompileTzdb(tarGz);
    expect(source).toBeInstanceOf(TzdbDateTimeZoneSource);
    expect(source.VersionId).toBe(bundledSource.VersionId);
    expect(source.TzdbVersion).toBe("2026f");
    expect([...source.GetIds()]).toEqual([...bundledSource.GetIds()]);
    expect([...source.CanonicalIdMap]).toEqual([...bundledSource.CanonicalIdMap]);
    expect(source.ZoneLocations!.length).toBe(bundledSource.ZoneLocations!.length);
    expect(source.WindowsMapping.MapZones.length).toBe(bundledSource.WindowsMapping.MapZones.length);

    const zones = new DateTimeZoneCache(source);
    expect(Instant.FromUtc(2024, 7, 1, 12, 0).InZone(zones.Get("Europe/Madrid")).toString()).toBe("2024-07-01T14:00:00 Europe/Madrid (+02)");
  }, timeout);
});

describe("errors", () => {
  it("a URL without fetch", async () => {
    vi.stubGlobal("fetch", undefined);
    await expect(CompileTzdb("https://data.iana.org/time-zones/tzdata-latest.tar.gz")).rejects.toThrowNodaError("InvalidOperationException");
    await expect(CompileTzdb("https://data.iana.org/time-zones/tzdata-latest.tar.gz")).rejects.toThrow(/with the host's fetch\(\), which is not available/);
  });

  it("a URL without XMLHttpRequest (sync)", () => {
    vi.stubGlobal("XMLHttpRequest", undefined);
    expect(() => CompileTzdbSync("https://data.iana.org/time-zones/tzdata-latest.tar.gz")).toThrowNodaError("InvalidOperationException");
    expect(() => CompileTzdbToNzdSync("https://data.iana.org/time-zones/tzdata-latest.tar.gz")).toThrow(/with the host's XMLHttpRequest, which is not available/);
  });

  it("an HTTP error (sync)", () => {
    vi.stubGlobal("XMLHttpRequest", FakeXhr(new Uint8Array(0), 404, "Not Found").Class);
    expect(() => CompileTzdbSync("https://example.com/tzdata.tar.gz")).toThrow("Downloading https://example.com/tzdata.tar.gz failed: HTTP 404 Not Found");
  });

  it("an HTTP error", async () => {
    vi.stubGlobal("fetch", () => Promise.resolve(new Response("Not here", { status: 404, statusText: "Not Found" })));
    await expect(CompileTzdb("https://example.com/tzdata.tar.gz")).rejects.toThrow("Downloading https://example.com/tzdata.tar.gz failed: HTTP 404 Not Found");
  });

  it("an lzip archive", async () => {
    const lzip = new Uint8Array([0x4c, 0x5a, 0x49, 0x50, 0x01, 0x0c, 0x00, 0x00]);
    await expect(CompileTzdbToNzd(lzip)).rejects.toThrowNodaError("NotSupportedException");
    await expect(CompileTzdbToNzd(lzip)).rejects.toThrow(/tzdata-latest\.tar\.gz/);
    expect(() => CompileTzdbToNzdSync(lzip)).toThrowNodaError("NotSupportedException");
  });

  it("data that is neither gzip nor tar", async () => {
    await expect(CompileTzdbToNzd(new Uint8Array(1024).fill(0x41))).rejects.toThrowNodaError("InvalidDataException");
    expect(() => CompileTzdbToNzdSync(new Uint8Array(1024).fill(0x41))).toThrowNodaError("InvalidDataException");
  });

  it("corrupt gzip data, from the host's DecompressionStream or noda-js's inflate", async () => {
    const corrupt = tarGz.slice(0, 2000);
    corrupt.fill(0xff, 100);
    await expect(CompileTzdbToNzd(corrupt)).rejects.toThrowNodaError("InvalidDataException");
    vi.stubGlobal("DecompressionStream", undefined);
    await expect(CompileTzdbToNzd(corrupt)).rejects.toThrowNodaError("InvalidDataException");
  });

  it("an archive without a version (no version file, and nothing in the source's name)", async () => {
    const withoutVersion = await CompileTzdbToNzd(RemoveTarEntry(tar, "version")).then(() => null, (e: unknown) => e);
    expect(withoutVersion).toBeNodaError("InvalidDataException");
    expect((withoutVersion as Error).message).toBe("Unable to determine TZDB version from source");
  }, timeout);

  it("a source that isn't a URL or bytes", async () => {
    await expect(CompileTzdb(42 as unknown as string)).rejects.toThrow(/must be a URL/);
    expect(() => CompileTzdbSync(42 as unknown as string)).toThrow(/must be a URL/);
  });
});

/** The archive with the named entry renamed away. */
function RemoveTarEntry(archive: Uint8Array, name: string): Uint8Array {
  const copy = archive.slice();
  for (let position = 0; position + 512 <= copy.length;) {
    const header = copy.subarray(position, position + 512);
    const entryName = new TextDecoder().decode(header.subarray(0, 100)).replace(/\0.*$/s, "");
    if (entryName === "") {
      break;
    }
    const size = parseInt(new TextDecoder().decode(header.subarray(124, 136)).replace(/\0.*$/s, "").trim(), 8);
    if (entryName === name) {
      header[0] = 0x5f; // '_'
      let sum = 0;
      for (let i = 0; i < 512; i++) {
        sum += i >= 148 && i < 156 ? 0x20 : header[i]!;
      }
      header.set(new TextEncoder().encode(sum.toString(8).padStart(6, "0") + "\0 "), 148);
    }
    position += 512 + Math.ceil(size / 512) * 512;
  }
  return copy;
}
