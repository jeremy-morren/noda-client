// noda-js: new code. A minimal tar archive reader (POSIX ustar and pax, and GNU tar's long names), for reading tzdata
// archives (see Archive.ts): just the regular files, by name, as NodaTime's FileSource.FromArchive reads them with
// .NET's TarReader.

import { DecodeUtf8 } from "../Utility/Encoding.ts";
import { NewInvalidDataException, type InvalidDataException } from "../internal.ts";

const BlockSize = 512;

/** The text of a NUL-terminated header field (or the whole field, if it has no NUL), decoded as UTF-8. */
function ReadString(bytes: Uint8Array, offset: number, length: number): string {
  let end = offset;
  while (end < offset + length && bytes[end] !== 0) {
    end++;
  }
  return DecodeUtf8(bytes.subarray(offset, end));
}

/**
 * A numeric header field: octal digits (padded with spaces or NULs), or, if the first byte's high bit is set, a
 * big-endian base-256 number (GNU tar's extension for values too large for octal).
 */
function ReadNumber(header: Uint8Array, offset: number, length: number): number {
  if ((header[offset]! & 0x80) !== 0) {
    let value = header[offset]! & 0x7f;
    for (let i = 1; i < length; i++) {
      value = value * 256 + header[offset + i]!;
    }
    return value;
  }
  const text = ReadString(header, offset, length).replace(/^ +| +$/g, "");
  if (!/^[0-7]*$/.test(text)) {
    throw NewInvalidDataException(`Invalid tar archive: invalid number '${text}' in a header.`);
  }
  return text === "" ? 0 : parseInt(text, 8);
}

/** Whether the header's checksum (the sum of its bytes, with the checksum field counted as spaces) is right. */
function IsChecksumValid(header: Uint8Array): boolean {
  let sum = 0;
  for (let i = 0; i < BlockSize; i++) {
    sum += i >= 148 && i < 156 ? 0x20 : header[i]!;
  }
  // Six octal digits, then a NUL and a space (by convention; readers accept other padding).
  const stored = ReadString(header, 148, 8).replace(/^ +| +$/g, "");
  return /^[0-7]+$/.test(stored) && parseInt(stored, 8) === sum;
}

function IsZeroBlock(block: Uint8Array): boolean {
  for (let i = 0; i < block.length; i++) {
    if (block[i] !== 0) {
      return false;
    }
  }
  return true;
}

/** The `path` record of a pax extended header (records of the form "<length> <key>=<value>\n"), if it has one. */
function ReadPaxPath(data: Uint8Array): string | null {
  let path: string | null = null;
  for (let position = 0; position < data.length;) {
    let space = position;
    while (space < data.length && data[space] !== 0x20) {
      space++;
    }
    const length = parseInt(ReadString(data, position, space - position), 10);
    if (!(length > space - position) || position + length > data.length || data[position + length - 1] !== 0x0a) {
      throw NewInvalidDataException("Invalid tar archive: invalid pax extended header.");
    }
    const record = DecodeUtf8(data.subarray(space + 1, position + length - 1));
    const equals = record.indexOf("=");
    if (equals === -1) {
      throw NewInvalidDataException("Invalid tar archive: invalid pax extended header.");
    }
    if (record.substring(0, equals) === "path") {
      path = record.substring(equals + 1);
    }
    position += length;
  }
  return path;
}

/**
 * Reads the regular files in a tar archive: their names (as in the archive, with any directories) and contents
 * (views of the archive's bytes). Names come from the header (with the ustar prefix field, if present), a pax
 * extended header's `path` record, or a GNU long name entry. Other entries (directories, links, devices, ...) are
 * skipped. If a name occurs more than once, the last entry wins.
 * @throws {InvalidDataException} The data isn't a tar archive, or is invalid or truncated.
 * @internal
 */
export function ReadTar(archive: Uint8Array): Map<string, Uint8Array> {
  const files = new Map<string, Uint8Array>();
  // The name of the next entry, from a pax extended header or GNU long name entry before it.
  let nextName: string | null = null;
  let position = 0;
  while (position + BlockSize <= archive.length) {
    const header = archive.subarray(position, position + BlockSize);
    // The archive ends with two zero blocks (and is padded with more); the first is enough.
    if (IsZeroBlock(header)) {
      return files;
    }
    if (!IsChecksumValid(header)) {
      throw NewInvalidDataException(`Not a tar archive (invalid header checksum at offset ${position}).`);
    }
    const size = ReadNumber(header, 124, 12);
    const dataStart = position + BlockSize;
    if (dataStart + size > archive.length) {
      throw NewInvalidDataException("Invalid tar archive: unexpected end of data.");
    }
    const data = archive.subarray(dataStart, dataStart + size);
    position = dataStart + Math.ceil(size / BlockSize) * BlockSize;

    const type = header[156]!;
    if (type === 0x78 /* 'x': pax extended header, for the next entry */) {
      nextName = ReadPaxPath(data) ?? nextName;
      continue;
    }
    if (type === 0x4c /* 'L': GNU long name, for the next entry */) {
      nextName = ReadString(data, 0, data.length);
      continue;
    }
    // '0' (or NUL, in old archives) is a regular file; '7' is a contiguous file, which readers treat as regular.
    if (type === 0x30 || type === 0 || type === 0x37) {
      let name = nextName;
      if (name === null) {
        name = ReadString(header, 0, 100);
        // POSIX ustar (magic "ustar\0"; GNU tar's "ustar  \0" uses those bytes for other things) splits long names
        // into a prefix and a name.
        const prefix = ReadString(header, 257, 6) === "ustar" && header[262] === 0 ? ReadString(header, 345, 155) : "";
        if (prefix !== "") {
          name = `${prefix}/${name}`;
        }
      }
      // Old archives mark directories as regular files whose names end with '/'.
      if (!name.endsWith("/")) {
        files.set(name, data);
      }
    }
    nextName = null;
  }
  // No end-of-archive blocks: accepted if the last entry was complete (as other readers do).
  if (position < archive.length && !IsZeroBlock(archive.subarray(position))) {
    throw NewInvalidDataException("Invalid tar archive: unexpected end of data.");
  }
  return files;
}
