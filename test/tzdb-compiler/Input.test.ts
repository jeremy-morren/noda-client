// The tzdata sources noda-js/tzdb/compiler takes (src/noda-js/TzdbCompiler/Input.ts): bytes in every form a host
// gives them, URLs, Blobs and Files, fetch Requests and Responses, and streams; asynchronously and (where the host
// can) synchronously.

import { afterEach, describe, expect, it, vi } from "vitest";
import { ReadTzdataSource, ReadTzdataSourceSync } from "../../src/noda-js/TzdbCompiler/Input.ts";
import type { TzdataArchive, TzdataDirectory, TzdataSource, TzdataSyncSource } from "../../src/noda-js/TzdbCompiler/Input.ts";

const bytes = [1, 2, 3, 0x80, 0xff];

afterEach(() => {
  vi.unstubAllGlobals();
});

async function read(source: unknown): Promise<{ bytes: number[]; origin: string }> {
  const archive = await ReadTzdataSource(source as TzdataSource, null) as TzdataArchive;
  return { bytes: [...archive.Bytes], origin: archive.Origin };
}

function readSync(source: unknown): { bytes: number[]; origin: string } {
  const archive = ReadTzdataSourceSync(source as TzdataSyncSource, null) as TzdataArchive;
  return { bytes: [...archive.Bytes], origin: archive.Origin };
}

/** Checks both functions read the source as `expected`. */
async function expectBoth(source: unknown, expected: number[] = bytes): Promise<void> {
  expect(readSync(source)).toEqual({ bytes: expected, origin: "" });
  expect(await read(source)).toEqual({ bytes: expected, origin: "" });
}

describe("bytes (sync and async)", () => {
  it("a Uint8Array, and a view of part of one", async () => {
    await expectBoth(new Uint8Array(bytes));
    await expectBoth(new Uint8Array([9, ...bytes, 9]).subarray(1, 6));
  });

  it("other typed arrays and DataViews: the bytes they view", async () => {
    await expectBoth(new Int8Array([1, 2, 3, -128, -1]));
    await expectBoth(new Uint8ClampedArray(bytes));
    const words = new Uint16Array([0x0201, 0x0403]);
    await expectBoth(words, [...new Uint8Array(words.buffer)]);
    await expectBoth(new DataView(new Uint8Array([9, ...bytes]).buffer, 1));
  });

  it.runIf(typeof Buffer === "function")("a Node.js Buffer", async () => {
    await expectBoth(Buffer.from(bytes));
  });

  it("an ArrayBuffer", async () => {
    await expectBoth(new Uint8Array(bytes).buffer);
  });

  // (Browsers have SharedArrayBuffer only when cross-origin isolated.)
  it.runIf(typeof SharedArrayBuffer === "function")("a SharedArrayBuffer, and a view of one (copied)", async () => {
    const shared = new SharedArrayBuffer(bytes.length);
    new Uint8Array(shared).set(bytes);
    await expectBoth(shared);
    await expectBoth(new Uint8Array(shared));
    expect((ReadTzdataSourceSync(new Uint8Array(shared), null) as TzdataArchive).Bytes.buffer).not.toBe(shared);
  });

  it("an array of byte values, unsigned or signed, and an array-like", async () => {
    await expectBoth(bytes);
    await expectBoth([1, 2, 3, -128, -1]);
    await expectBoth({ length: 5, 0: 1, 1: 2, 2: 3, 3: 0x80, 4: 0xff });
    await expectBoth([], []);
  });

  it("a list of chunks of any kind, concatenated", async () => {
    await expectBoth([new Uint8Array([1, 2]), [3], new Int8Array([-128]).buffer, new DataView(new Uint8Array([0xff]).buffer)]);
    await expectBoth([[1, 2, 3], [0x80, 0xff]]);
  });

  it("rejects numbers that aren't bytes, and values that aren't sources", async () => {
    for (const source of [[256], [-129], [1.5], [1, Number.NaN], [1, "2"], [new Uint8Array(1), "text"], {}, 42, null, undefined, true]) {
      expect(() => readSync(source), String(source)).toThrowNodaError("ArgumentException");
      await expect(read(source), String(source)).rejects.toThrowNodaError("ArgumentException");
    }
    expect(() => readSync([256])).toThrow("element 0 is 256");
  });
});

describe("URLs", () => {
  it("async: fetch()", async () => {
    const requests: unknown[] = [];
    vi.stubGlobal("fetch", (request: unknown) => {
      requests.push(request);
      return Promise.resolve(new Response(new Uint8Array(bytes)));
    });
    expect(await read("https://example.com/tzdata2026f.tar.gz?x=1#y")).toEqual({ bytes, origin: "tzdata2026f.tar.gz" });
    expect(await read(new URL("https://example.com/b/tzdata.tar.gz"))).toEqual({ bytes, origin: "tzdata.tar.gz" });
    expect(requests).toEqual(["https://example.com/tzdata2026f.tar.gz?x=1#y", "https://example.com/b/tzdata.tar.gz"]);
  });

  it("async: data: and blob: URLs (which have no file name), with the host's fetch()", async () => {
    expect(await read("data:application/octet-stream;base64,AQIDgP8=")).toEqual({ bytes, origin: "" });
    if (typeof URL.createObjectURL === "function") {
      const url = URL.createObjectURL(new Blob([new Uint8Array(bytes)]));
      try {
        expect(await read(url)).toEqual({ bytes, origin: "" });
      } finally {
        URL.revokeObjectURL(url);
      }
    }
  });
});

/** A server for the stand-ins below: files by URL; anything else is a 404 (or the status given). */
type Server = Record<string, Uint8Array | number>;

/** A stand-in for fetch() serving `server`, recording the requested URLs. */
function StubFetch(server: Server): string[] {
  const requests: string[] = [];
  vi.stubGlobal("fetch", (url: string) => {
    requests.push(url);
    const file = server[url] ?? 404;
    return Promise.resolve(typeof file === "number"
      ? new Response("Error", { status: file, statusText: file === 404 ? "Not Found" : "Error" })
      : new Response(file as Uint8Array<ArrayBuffer>));
  });
  return requests;
}

/** A stand-in for a synchronous XMLHttpRequest serving `server` (bytes as the x-user-defined charset gives them). */
function StubXhr(server: Server): string[] {
  const requests: string[] = [];
  vi.stubGlobal("XMLHttpRequest", class {
    status = 0;
    statusText = "";
    responseText = "";
    private _url = "";
    open(_method: string, url: string, async: boolean): void {
      expect(async).toBe(false);
      this._url = url;
    }
    overrideMimeType(): void {}
    send(): void {
      requests.push(this._url);
      const file = server[this._url] ?? 404;
      this.status = typeof file === "number" ? file : 200;
      this.responseText = typeof file === "number" ? "" : String.fromCharCode(...[...file].map(b => b < 0x80 ? b : 0xf700 + b));
    }
  });
  return requests;
}

/** The files of a directory, by name (null: missing). */
function directoryFiles(input: unknown): Record<string, number[]> {
  const directory = input as TzdataDirectory;
  return Object.fromEntries([...directory.Files].map(([name, data]) => [name, [...data]]));
}

describe("directory URLs (a path ending with /): the compiler's files, one by one", () => {
  const base = "https://cdn.example.com/gh/eggert/tz@2026f/";
  const files = ["africa", "antarctica", "asia", "australasia", "europe", "northamerica", "southamerica", "pacificnew",
    "etcetera", "backward", "systemv", "iso3166.tab", "zone.tab", "zone1970.tab", "version"];
  // Every file but pacificnew and systemv (removed from tzdb in 2020b) and version (not in the tz repository).
  const server: Server = Object.fromEntries(files
    .filter(name => !["pacificnew", "systemv", "version"].includes(name))
    .map((name, i) => [base + name, new Uint8Array([i, 0x80 + i])]));
  const expected = Object.fromEntries(Object.entries(server).map(([url, data]) => [url.substring(base.length), [...data as Uint8Array]]));

  it("async: with fetch(), skipping the files that are missing (404)", async () => {
    const requests = StubFetch(server);
    const directory = await ReadTzdataSource(base, null) as TzdataDirectory;
    expect(requests).toEqual(files.map(name => base + name));
    expect(directoryFiles(directory)).toEqual(expected);
    // The version comes from the directory's name (here "tz@2026f": the compiler finds 2026f in it).
    expect(directory.Origin).toBe("tz@2026f");
  });

  it("sync: with XMLHttpRequest", () => {
    const requests = StubXhr(server);
    const directory = ReadTzdataSourceSync(new URL(base), null) as TzdataDirectory;
    expect(requests).toEqual(files.map(name => base + name));
    expect(directoryFiles(directory)).toEqual(expected);
    expect(directory.Origin).toBe("tz@2026f");
  });

  it("keeps the URL's query", async () => {
    const requests = StubFetch(Object.fromEntries(Object.entries(server).map(([url, data]) => [`${url}?token=1`, data])));
    expect(directoryFiles(await ReadTzdataSource(`${base}?token=1`, null))).toEqual(expected);
    expect(requests[0]).toBe(`${base}africa?token=1`);
  });

  it("errors: other HTTP errors, and a directory without tzdata files", async () => {
    StubFetch({ ...server, [`${base}europe`]: 500 });
    await expect(ReadTzdataSource(base, null)).rejects.toThrow(`Downloading ${base}europe failed: HTTP 500 Error`);
    StubXhr({ ...server, [`${base}europe`]: 403 });
    expect(() => ReadTzdataSourceSync(base, null)).toThrow(`Downloading ${base}europe failed: HTTP 403`);
    StubFetch({});
    await expect(ReadTzdataSource(base, null)).rejects.toThrowNodaError("InvalidDataException");
    StubXhr({});
    expect(() => ReadTzdataSourceSync(base, null)).toThrow(/has none of the tzdata files/);
  });
});

describe("Blobs and Files", () => {
  it("async: a Blob, and a File (whose name is the origin)", async () => {
    expect(await read(new Blob([new Uint8Array(bytes)]))).toEqual({ bytes, origin: "" });
    expect(await read(new File([new Uint8Array(bytes)], "tzdata2026f.tar.gz"))).toEqual({ bytes, origin: "tzdata2026f.tar.gz" });
  });

  // React Native's Blob, for one, has no arrayBuffer method.
  it.runIf(typeof FileReader === "function")("async: a Blob without arrayBuffer(), with the host's FileReader", async () => {
    const blob = new Blob([new Uint8Array(bytes)]);
    Object.defineProperty(blob, "arrayBuffer", { value: undefined });
    expect(await read(blob)).toEqual({ bytes, origin: "" });
  });

  it("sync: with FileReaderSync (workers), and an error without it", () => {
    const blob = new File([new Uint8Array(bytes)], "tzdata.tar.gz");
    vi.stubGlobal("FileReaderSync", undefined);
    expect(() => readSync(blob)).toThrowNodaError("InvalidOperationException");
    expect(() => readSync(blob)).toThrow(/FileReaderSync, which only workers have/);
    // A stand-in, reading the Blob's bytes ahead of time.
    vi.stubGlobal("FileReaderSync", class {
      readAsArrayBuffer(value: Blob): ArrayBuffer {
        expect(value).toBe(blob);
        return new Uint8Array(bytes).buffer;
      }
    });
    expect(readSync(blob)).toEqual({ bytes, origin: "tzdata.tar.gz" });
  });
});

describe("Requests, Responses and streams (async only)", () => {
  it("a Request: fetched", async () => {
    const requests: unknown[] = [];
    vi.stubGlobal("fetch", (request: unknown) => {
      requests.push(request);
      return Promise.resolve(new Response(new Uint8Array(bytes)));
    });
    const request = new Request("https://example.com/tzdata2026f.tar.gz");
    expect(await read(request)).toEqual({ bytes, origin: "tzdata2026f.tar.gz" });
    expect(requests).toEqual([request]);
  });

  it("a Response, and its body (a ReadableStream)", async () => {
    expect(await read(new Response(new Uint8Array(bytes)))).toEqual({ bytes, origin: "" });
    expect(await read(new Response(new Uint8Array(bytes)).body)).toEqual({ bytes, origin: "" });
  });

  it("an unsuccessful Response", async () => {
    await expect(read(new Response("Not here", { status: 404, statusText: "Not Found" }))).rejects.toThrow("failed: HTTP 404 Not Found");
  });

  it("a ReadableStream of chunks of any kind", async () => {
    const chunks: unknown[] = [new Uint8Array([1, 2]), [3], new Uint8Array([0x80, 0xff]).buffer];
    const stream = new ReadableStream({
      pull(controller) {
        const chunk = chunks.shift();
        if (chunk === undefined) {
          controller.close();
        } else {
          controller.enqueue(chunk);
        }
      },
    });
    expect(await read(stream)).toEqual({ bytes, origin: "" });
  });

  it("an async iterable of chunks (as a Node.js stream is)", async () => {
    async function* chunks(): AsyncGenerator<unknown> {
      yield new Uint8Array([1, 2]);
      yield [3];
      yield new Uint8Array([0x80, 0xff]);
    }
    expect(await read(chunks())).toEqual({ bytes, origin: "" });
  });

  it("a stream of text (a Node.js stream with an encoding set) is an error, and the stream is closed", async () => {
    let closed = false;
    async function* chunks(): AsyncGenerator<unknown> {
      try {
        yield "text";
        yield new Uint8Array(1);
      } finally {
        closed = true;
      }
    }
    await expect(read(chunks())).rejects.toThrow(/not text \(don't set an encoding on the stream\)/);
    expect(closed).toBe(true);
  });

  it("can't be read synchronously", () => {
    for (const source of [new Request("https://example.com/"), new Response(new Uint8Array(bytes)), new Response(new Uint8Array(bytes)).body]) {
      expect(() => readSync(source)).toThrowNodaError("ArgumentException");
      expect(() => readSync(source)).toThrow(/CompileTzdbToNzd also take a Request, Response or stream/);
    }
  });
});
