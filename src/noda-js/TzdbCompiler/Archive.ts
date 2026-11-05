// noda-js: new code. Reads a tzdata archive (a gzip-compressed tar file, as IANA publishes it, or a plain tar file)
// into the FileSource the tzdb compiler reads, as NodaTime's FileSource.FromArchive (and the code that downloads and
// decompresses the archive before it) does.

import { DecodeUtf8 } from "../Utility/Encoding.ts";
import { Gunzip, IsGzip } from "./Inflate.ts";
import { FileSource, GetFileName, GetValue, Trim } from "./internal.ts";
import { ReadTar } from "./Tar.ts";
import { NewInvalidDataException, NewNotSupportedException, type InvalidDataException, type NotSupportedException } from "../internal.ts";

/** Whether the data starts with lzip's magic number ("LZIP"). */
function IsLzip(data: Uint8Array): boolean {
  return data.length >= 4 && data[0] === 0x4c && data[1] === 0x5a && data[2] === 0x49 && data[3] === 0x50;
}

/** Decompresses gzip data with the host's DecompressionStream. */
async function GunzipWithHost(data: Uint8Array): Promise<Uint8Array> {
  const stream = new DecompressionStream("gzip");
  const writer = stream.writable.getWriter();
  // If the data is invalid, these reject as well as the reads below, which report it.
  writer.write(data as Uint8Array<ArrayBuffer>).catch(() => undefined);
  writer.close().catch(() => undefined);
  const reader = stream.readable.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      chunks.push(value);
      length += value.length;
    }
  } catch (e) {
    // As the built-in decompressor reports invalid data (the host's error is a TypeError).
    throw NewInvalidDataException(`Invalid gzip data: ${e instanceof Error ? e.message : String(e)}`);
  }
  const output = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.length;
  }
  return output;
}

/** Throws if the archive is lzip-compressed, which isn't supported. */
function CheckNotLzip(archive: Uint8Array): void {
  if (IsLzip(archive)) {
    throw NewNotSupportedException(
      "lzip-compressed archives (such as tzdb-<version>.tar.lz) aren't supported. Use the tzdata archive, " +
        "tzdata<version>.tar.gz (e.g. https://data.iana.org/time-zones/tzdata-latest.tar.gz).",
    );
  }
}

/**
 * Returns tzdata files (from an archive or a directory) as a {@link FileSource}, as NodaTime's FileSource.FromArchive
 * does with the files it reads from an archive.
 *
 * The compiler takes the tzdb version from the Makefile (whose VERSION is "unknown" in the release archives) or else
 * from the source's name, so if there's a `version` file (as release archives have), the source's name is
 * "tzdata<version>.tar" whatever `origin` is.
 * @param files The files, by file name.
 * @param origin Where the files came from (e.g. an archive's or directory's name), used for the tzdb version if there
 * is no `version` file.
 * @internal
 */
export function TzdataFileSource(files: ReadonlyMap<string, Uint8Array>, origin: string): FileSource {
  const version = files.get("version");
  if (version !== undefined) {
    origin = `tzdata${Trim(DecodeUtf8(version))}.tar`;
  }
  const copy = new Map<string, Uint8Array>(files);
  return FileSource.NewNamesOpenFunctionFullOrigin([...copy.keys()], name => GetValue(copy, name), origin);
}

/**
 * Reads the files in a tar archive, and returns them as a {@link FileSource} (see {@link TzdataFileSource}).
 *
 * As in NodaTime's FileSource.FromArchive, each file is named by just its file name, without directories (the
 * tzdb-<version>.tar.lz archives put everything in a directory).
 */
function ReadTarFiles(tar: Uint8Array, origin: string): FileSource {
  const files = new Map<string, Uint8Array>();
  for (const [name, data] of ReadTar(tar)) {
    files.set(GetFileName(name), data);
  }
  return TzdataFileSource(files, origin);
}

/**
 * Decompresses the archive if it's gzip-compressed (with the host's DecompressionStream if it has one, and noda-js's
 * own decompressor otherwise), reads the files in it, and returns them as a {@link FileSource} (see
 * {@link ReadTarFiles}).
 * @param archive The archive's bytes.
 * @param origin Where the archive came from (a URL or file name), used for the tzdb version if the archive has no
 * `version` file.
 * @throws {NotSupportedException} The archive is lzip-compressed.
 * @throws {InvalidDataException} The archive is invalid (not gzip-compressed or a tar file, or corrupt).
 * @internal
 */
export async function ReadTzdbArchive(archive: Uint8Array, origin: string): Promise<FileSource> {
  CheckNotLzip(archive);
  if (IsGzip(archive)) {
    archive = typeof DecompressionStream === "function" ? await GunzipWithHost(archive) : Gunzip(archive);
  }
  return ReadTarFiles(archive, origin);
}

/**
 * As {@link ReadTzdbArchive}, synchronously: gzip data is always decompressed by noda-js's own decompressor (the
 * host's DecompressionStream is asynchronous).
 * @param archive The archive's bytes.
 * @param origin Where the archive came from (a URL or file name), used for the tzdb version if the archive has no
 * `version` file.
 * @throws {NotSupportedException} The archive is lzip-compressed.
 * @throws {InvalidDataException} The archive is invalid (not gzip-compressed or a tar file, or corrupt).
 * @internal
 */
export function ReadTzdbArchiveSync(archive: Uint8Array, origin: string): FileSource {
  CheckNotLzip(archive);
  return ReadTarFiles(IsGzip(archive) ? Gunzip(archive) : archive, origin);
}
