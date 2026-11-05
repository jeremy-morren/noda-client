// noda-js's minimal tar reader (src/noda-js/TzdbCompiler/Tar.ts), on archives built here: regular files only, named
// from the header (with the ustar prefix), a pax extended header's path, or a GNU long name.

import { describe, expect, it } from "vitest";
import { ReadTar } from "../../src/noda-js/TzdbCompiler/Tar.ts";

const encoder = new TextEncoder();

interface Entry {
  name: string;
  data?: string;
  /** The type flag (default '0', a regular file). */
  type?: string;
  prefix?: string;
  /** The magic and version: POSIX ustar by default. */
  magic?: "ustar\u000000" | "ustar  \u0000" | "";
}

/** A tar header block for the entry. */
function Header(entry: Entry, size: number): Uint8Array {
  const header = new Uint8Array(512);
  const put = (offset: number, text: string): void => header.set(encoder.encode(text), offset);
  put(0, entry.name);
  put(100, "0000644\0");
  put(108, "0000000\0");
  put(116, "0000000\0");
  put(124, size.toString(8).padStart(11, "0") + "\0");
  put(136, "00000000000\0");
  put(156, entry.type ?? "0");
  put(257, entry.magic ?? "ustar\u000000");
  if (entry.prefix !== undefined) {
    put(345, entry.prefix);
  }
  let sum = 0;
  for (let i = 0; i < 512; i++) {
    sum += i >= 148 && i < 156 ? 0x20 : header[i]!;
  }
  put(148, sum.toString(8).padStart(6, "0") + "\0 ");
  return header;
}

/** A pax extended header record: "<length> <key>=<value>\n", where the length counts itself. */
function PaxRecord(key: string, value: string): string {
  const rest = ` ${key}=${value}\n`;
  let length = encoder.encode(rest).length + 1;
  while (String(length).length + encoder.encode(rest).length !== length) {
    length++;
  }
  return `${length}${rest}`;
}

/** A tar archive of the entries, with the two zero blocks at the end. */
function Tar(...entries: Entry[]): Uint8Array {
  const blocks: Uint8Array[] = [];
  for (const entry of entries) {
    const data = encoder.encode(entry.data ?? "");
    blocks.push(Header(entry, data.length));
    const padded = new Uint8Array(Math.ceil(data.length / 512) * 512);
    padded.set(data);
    blocks.push(padded);
  }
  blocks.push(new Uint8Array(1024));
  const archive = new Uint8Array(blocks.reduce((total, block) => total + block.length, 0));
  let offset = 0;
  for (const block of blocks) {
    archive.set(block, offset);
    offset += block.length;
  }
  return archive;
}

function Texts(files: Map<string, Uint8Array>): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [name, data] of files) {
    result[name] = new TextDecoder().decode(data);
  }
  return result;
}

describe("ReadTar", () => {
  it("reads regular files, by their names in the archive", () => {
    const archive = Tar({ name: "africa", data: "Zone\tAfrica/Abidjan" }, { name: "tzdb-2026f/version", data: "2026f\n" }, { name: "empty" });
    expect(Texts(ReadTar(archive))).toEqual({ africa: "Zone\tAfrica/Abidjan", "tzdb-2026f/version": "2026f\n", empty: "" });
  });

  it("reads files of several blocks", () => {
    const big = "x".repeat(1500);
    expect(Texts(ReadTar(Tar({ name: "big", data: big }, { name: "after", data: "a" })))).toEqual({ big, after: "a" });
  });

  it("uses the ustar prefix field, only in POSIX ustar headers", () => {
    expect([...ReadTar(Tar({ name: "zone.tab", data: "z", prefix: "tzdb-2026f/data" })).keys()]).toEqual(["tzdb-2026f/data/zone.tab"]);
    // GNU tar ("ustar  \0") uses the same bytes for other things; old (v7) archives have no magic.
    expect([...ReadTar(Tar({ name: "a", prefix: "x", magic: "ustar  \u0000" })).keys()]).toEqual(["a"]);
    expect([...ReadTar(Tar({ name: "b", prefix: "x", magic: "" })).keys()]).toEqual(["b"]);
  });

  it("uses the path in a pax extended header for the next entry only", () => {
    const longName = `tzdb-2026f/${"d".repeat(120)}/zone1970.tab`;
    const archive = Tar(
      { name: "PaxHeaders/zone1970.tab", type: "x", data: PaxRecord("mtime", "1700000000.5") + PaxRecord("path", longName) },
      { name: "truncated-name", data: "z" },
      { name: "PaxHeaders/other", type: "x", data: PaxRecord("mtime", "1") },
      { name: "plain", data: "p" },
    );
    expect(Texts(ReadTar(archive))).toEqual({ [longName]: "z", plain: "p" });
  });

  it("uses a GNU long name for the next entry", () => {
    const longName = `${"n".repeat(150)}/backward`;
    const archive = Tar({ name: "././@LongLink", type: "L", data: longName + "\0", magic: "ustar  \u0000" }, { name: "short", data: "b" });
    expect(Texts(ReadTar(archive))).toEqual({ [longName]: "b" });
  });

  it("skips entries that aren't regular files", () => {
    const archive = Tar(
      { name: "dir/", type: "5" },
      { name: "link", type: "1", data: "" },
      { name: "symlink", type: "2" },
      { name: "PaxHeaders/global", type: "g", data: PaxRecord("comment", "hi") },
      { name: "old-dir/", type: "\0" },
      { name: "old-file", type: "\0", data: "o" },
      { name: "contiguous", type: "7", data: "c" },
    );
    expect(Texts(ReadTar(archive))).toEqual({ "old-file": "o", contiguous: "c" });
  });

  it("keeps the last of entries with the same name", () => {
    expect(Texts(ReadTar(Tar({ name: "a", data: "1" }, { name: "a", data: "2" })))).toEqual({ a: "2" });
  });

  it("stops at the first zero block, and accepts an archive without one", () => {
    const archive = Tar({ name: "a", data: "1" });
    expect(Texts(ReadTar(archive.subarray(0, 1024)))).toEqual({ a: "1" });
    expect(ReadTar(new Uint8Array(0)).size).toBe(0);
  });

  it("rejects data that isn't a tar archive, or is truncated", () => {
    expect(() => ReadTar(new Uint8Array(512).fill(0x41))).toThrowNodaError("InvalidDataException");
    expect(() => ReadTar(new Uint8Array(512).fill(0x41))).toThrow("Not a tar archive (invalid header checksum at offset 0).");
    const archive = Tar({ name: "a", data: "x".repeat(600) });
    expect(() => ReadTar(archive.subarray(0, 1000))).toThrow("unexpected end of data");
    const corrupt = archive.slice();
    corrupt[0] = 0x62;
    expect(() => ReadTar(corrupt)).toThrow("invalid header checksum");
    expect(() => ReadTar(Tar({ name: "p", type: "x", data: "99 path=x\n" }, { name: "a" }))).toThrow("invalid pax extended header");
  });
});
