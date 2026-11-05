// noda-js: the `noda-js/tzdb/compiler` entry point: compiles an IANA tzdata release into NZD data at runtime, as
// NodaTime's TzdbCompiler command-line tool does, so an app can use time zone data newer than the data bundled with
// noda-js without waiting for a new release. CompileTzdb and CompileTzdbToNzd are asynchronous (a URL is downloaded
// with fetch()); CompileTzdbSync and CompileTzdbToNzdSync are synchronous (a URL is downloaded with a synchronous
// XMLHttpRequest).

import type { TzdbDateTimeZoneSource } from "../internal.ts";
import type { WindowsZones } from "../internal.ts";
import { GetCldrWindowsZones } from "../Bcl/CldrWindowsZones.ts";
import { ReadTzdbArchive, ReadTzdbArchiveSync, TzdataFileSource } from "../TzdbCompiler/Archive.ts";
import { ReadTzdataSource, ReadTzdataSourceSync } from "../TzdbCompiler/Input.ts";
import type { TzdataSource, TzdataSyncSource } from "../TzdbCompiler/Input.ts";
import type { FileSource } from "../TzdbCompiler/internal.ts";
import { Program } from "../TzdbCompiler/internal.ts";
import type { ArgumentException, FormatException, InvalidDataException, InvalidOperationException, NotSupportedException } from "../internal.ts";

export type { TzdataBytes, TzdataChunk, TzdataSource, TzdataSyncSource } from "../TzdbCompiler/Input.ts";
// The errors for an invalid archive and a failed download (NodaError codes, as the .NET exceptions NodaTime's
// compiler throws).
export type { HttpRequestException, InvalidDataException } from "../internal.ts";

/** Options for {@link CompileTzdb}, {@link CompileTzdbToNzd} and their synchronous variants. */
export interface CompileTzdbOptions {
  /**
   * The Windows time zone mapping to write into the data (TzdbDateTimeZoneSource.WindowsMapping, as used by
   * noda-js/windows): NodaTime's compiler's `-w` option. By default, the CLDR mapping bundled with noda-js
   * (GetCldrWindowsZones() in noda-js/windows), which is also the bundled tzdb's. To use a newer mapping, take one
   * from a newer NZD file (TzdbDateTimeZoneSource.WindowsMapping).
   */
  readonly WindowsZones?: WindowsZones | undefined;
  /**
   * Called with each line of the compiler's log (what NodaTime's compiler writes to the console: the files it
   * parses, the version it found, counts of zones and rules). By default nothing is logged.
   */
  readonly Log?: ((line: string) => void) | undefined;
}

/** Compiles the files, writes the data, reads it back and validates it (NodaTime's TzdbCompiler program). */
function CompileFiles(
  files: FileSource,
  options: CompileTzdbOptions | undefined,
): { readonly Nzd: Uint8Array; readonly Source: TzdbDateTimeZoneSource } {
  return Program.Main(files, options?.WindowsZones ?? GetCldrWindowsZones(), options?.Log ?? null);
}

/** Reads the archive (downloading a URL with fetch()), then compiles it. */
async function Compile(
  source: TzdataSource,
  options: CompileTzdbOptions | undefined,
): Promise<{ readonly Nzd: Uint8Array; readonly Source: TzdbDateTimeZoneSource }> {
  const input = await ReadTzdataSource(source, options?.Log ?? null);
  return CompileFiles("Files" in input ? TzdataFileSource(input.Files, input.Origin) : await ReadTzdbArchive(input.Bytes, input.Origin), options);
}

/** Reads the archive synchronously (downloading a URL with a synchronous XMLHttpRequest), then compiles it. */
function CompileSync(
  source: TzdataSyncSource,
  options: CompileTzdbOptions | undefined,
): { readonly Nzd: Uint8Array; readonly Source: TzdbDateTimeZoneSource } {
  const input = ReadTzdataSourceSync(source, options?.Log ?? null);
  return CompileFiles("Files" in input ? TzdataFileSource(input.Files, input.Origin) : ReadTzdbArchiveSync(input.Bytes, input.Origin), options);
}

/**
 * Compiles a release of the IANA time zone database (tzdata) into a time zone source, so an app can use newer
 * time zone data than noda-js bundles (`noda-js/tzdb/bundled`). The result is the same as loading the NZD file
 * that NodaTime's TzdbCompiler writes for that release (with the Windows mapping noda-js bundles; see
 * {@link CompileTzdbOptions.WindowsZones}), and is validated (TzdbDateTimeZoneSource.Validate) as NodaTime's
 * compiler does. Use it with a `DateTimeZoneCache`:
 *
 * ```ts
 * const source = await CompileTzdb("https://data.iana.org/time-zones/tzdata-latest.tar.gz");
 * const zones = new DateTimeZoneCache(source);
 * zones.Get("Europe/London");
 * ```
 *
 * data.iana.org doesn't send CORS headers, so a browser page can't download from it directly. In a browser, use a
 * directory URL on a CDN instead (a URL ending with `/`; the compiler downloads the files it reads one by one), such as
 * a tag of IANA's tz repository on jsDelivr: `https://cdn.jsdelivr.net/gh/eggert/tz@2026f/`. The newest tag is the
 * first in `https://api.github.com/repos/eggert/tz/tags`. Node.js, Deno and Bun have no CORS restriction.
 *
 * After the download, compiling keeps the thread busy for a few hundred milliseconds on Node or a desktop browser
 * (much longer on an interpreter such as QuickJS); in a page, consider a worker, or compile once with
 * {@link CompileTzdbToNzd} and cache the result.
 * @param source The tzdata archive (see {@link TzdataSource}): its URL (a string or URL object, downloaded with the
 * host's `fetch`) or of a directory of tzdata files (a URL ending with `/`), its bytes (a `Uint8Array`, Node `Buffer`, any other typed array or `DataView`, an `ArrayBuffer`
 * or `SharedArrayBuffer`, an array of byte values, or a list of any of these), a `Blob` or `File`, a fetch `Request`
 * (fetched) or `Response`, a `ReadableStream`, or an async iterable of byte chunks (e.g. a Node.js stream). (On
 * Node.js, read a file with `readFileSync(path)` or `createReadStream(path)`: `fetch` doesn't read `file:` URLs.)
 * The archive is a tzdata release as IANA publishes it, `tzdata<version>.tar.gz`
 * (https://data.iana.org/time-zones/tzdata-latest.tar.gz is the latest release;
 * https://data.iana.org/time-zones/releases/ has every release), or the same uncompressed (`.tar`). (The
 * `tzdb-<version>.tar.lz` archives aren't supported.) gzip data is decompressed with the host's `DecompressionStream`
 * if it has one, and in plain JavaScript otherwise.
 * @param options Options: the Windows mapping to include, and a log function.
 * @returns The time zone source.
 * @throws {InvalidOperationException} `source` is a URL and the host has no `fetch` (use {@link CompileTzdbSync}, or pass
 * the bytes).
 * @throws {ArgumentException} `source` isn't one of the kinds of {@link TzdataSource}, or gives something other than
 * bytes (e.g. an array with a number that isn't a byte, or a stream with an encoding set).
 * @throws {HttpRequestException} The download failed with an HTTP error status (`fetch`'s own errors, such as a
 * network error, and errors reading a Blob or stream, are passed through).
 * @throws {NotSupportedException} The archive is lzip-compressed (a tzdb-<version>.tar.lz archive).
 * @throws {InvalidDataException} The archive isn't a valid gzip-compressed or plain tar file, or its tzdb version can't
 * be determined (from its `version` file or `Makefile`, or else from the URL's file name).
 * @throws {InvalidNodaDataException} The compiled data fails validation (e.g. the Windows mapping uses a zone ID that
 * the release doesn't have). Errors in the tzdata files themselves are reported as NodaTime's compiler reports
 * them (e.g. `FormatException`).
 */
export async function CompileTzdb(source: TzdataSource, options?: CompileTzdbOptions): Promise<TzdbDateTimeZoneSource> {
  return (await Compile(source, options)).Source;
}

/**
 * Compiles a release of the IANA time zone database (tzdata) into NodaTime's NZD format, as NodaTime's TzdbCompiler
 * does (byte for byte, with the Windows mapping noda-js bundles; see {@link CompileTzdbOptions.WindowsZones}).
 * The data is validated (loaded and checked with TzdbDateTimeZoneSource.Validate) before it's returned, as
 * NodaTime's compiler does. Cache the bytes (e.g. in IndexedDB or a file) and load them later with
 * `TzdbDateTimeZoneSource.FromBytes` (`noda-js/tzdb`), which is much faster than compiling:
 *
 * ```ts
 * const nzd = await CompileTzdbToNzd("https://data.iana.org/time-zones/tzdata-latest.tar.gz");
 * // ... later:
 * const zones = new DateTimeZoneCache(TzdbDateTimeZoneSource.FromBytes(nzd));
 * ```
 * @param source The tzdata archive, as for {@link CompileTzdb}: its URL (downloaded with the host's `fetch`), its
 * bytes, a `Blob`, `Request`, `Response` or stream (see {@link TzdataSource}). As for {@link CompileTzdb}: `tzdata<version>.tar.gz` as IANA publishes it
 * (https://data.iana.org/time-zones/tzdata-latest.tar.gz), or the same uncompressed.
 * @param options Options: the Windows mapping to include, and a log function.
 * @returns The NZD data.
 * @throws {InvalidOperationException} `source` is a URL and the host has no `fetch` (use {@link CompileTzdbToNzdSync}, or
 * pass the bytes).
 * @throws {ArgumentException} `source` isn't one of the kinds of {@link TzdataSource}, or gives something other than
 * bytes (e.g. an array with a number that isn't a byte, or a stream with an encoding set).
 * @throws {HttpRequestException} The download failed with an HTTP error status (`fetch`'s own errors, such as a
 * network error, and errors reading a Blob or stream, are passed through).
 * @throws {NotSupportedException} The archive is lzip-compressed (a tzdb-<version>.tar.lz archive).
 * @throws {InvalidDataException} The archive isn't a valid gzip-compressed or plain tar file, or its tzdb version can't
 * be determined.
 * @throws {InvalidNodaDataException} The compiled data fails validation.
 */
export async function CompileTzdbToNzd(source: TzdataSource, options?: CompileTzdbOptions): Promise<Uint8Array> {
  return (await Compile(source, options)).Nzd;
}

/**
 * As {@link CompileTzdb}, synchronously: a URL is downloaded with a synchronous `XMLHttpRequest`, and gzip data is
 * decompressed in plain JavaScript (the host's `DecompressionStream` is asynchronous). For hosts and code that can't
 * wait for a promise; with bytes, it needs neither `fetch` nor `XMLHttpRequest`.
 *
 * ```ts
 * const zones = new DateTimeZoneCache(CompileTzdbSync("/tzdata-latest.tar.gz"));
 * ```
 *
 * A synchronous request blocks the thread until the download finishes, and browsers deprecate them on a page's main
 * thread (they log a warning); prefer a worker, or {@link CompileTzdb}. As with `fetch`, a cross-origin URL needs the
 * server's CORS headers.
 * @param source The tzdata archive (see {@link TzdataSyncSource}): its URL (a string or URL object, downloaded with
 * the host's `XMLHttpRequest`), its bytes (as for {@link CompileTzdb}), or a `Blob` or `File` (read with the host's
 * `FileReaderSync`, which only workers have). As for {@link CompileTzdb}: `tzdata<version>.tar.gz` as IANA publishes it, or the same uncompressed.
 * @param options Options: the Windows mapping to include, and a log function.
 * @returns The time zone source.
 * @throws {InvalidOperationException} `source` is a URL and the host has no `XMLHttpRequest` (as on Node; use
 * {@link CompileTzdb}, or pass the bytes), or a Blob and the host has no `FileReaderSync` (outside a worker).
 * @throws {ArgumentException} `source` isn't one of the kinds of {@link TzdataSyncSource} (a Request, Response or stream
 * can only be read asynchronously), or is an array with a number that isn't a byte.
 * @throws {HttpRequestException} The download failed with an HTTP error status (`XMLHttpRequest`'s own errors, such
 * as a network error, are passed through).
 * @throws {NotSupportedException} The archive is lzip-compressed (a tzdb-<version>.tar.lz archive).
 * @throws {InvalidDataException} The archive isn't a valid gzip-compressed or plain tar file, or its tzdb version can't
 * be determined.
 * @throws {InvalidNodaDataException} The compiled data fails validation.
 */
export function CompileTzdbSync(source: TzdataSyncSource, options?: CompileTzdbOptions): TzdbDateTimeZoneSource {
  return CompileSync(source, options).Source;
}

/**
 * As {@link CompileTzdbToNzd}, synchronously: a URL is downloaded with a synchronous `XMLHttpRequest`, and gzip data
 * is decompressed in plain JavaScript. See {@link CompileTzdbSync}.
 * @param source The tzdata archive (see {@link TzdataSyncSource}): its URL (a string or URL object, downloaded with
 * the host's `XMLHttpRequest`), its bytes (as for {@link CompileTzdb}), or a `Blob` or `File` (read with the host's
 * `FileReaderSync`, which only workers have). As for {@link CompileTzdb}: `tzdata<version>.tar.gz` as IANA publishes it, or the same uncompressed.
 * @param options Options: the Windows mapping to include, and a log function.
 * @returns The NZD data.
 * @throws {InvalidOperationException} `source` is a URL and the host has no `XMLHttpRequest` (as on Node; use
 * {@link CompileTzdbToNzd}, or pass the bytes), or a Blob and the host has no `FileReaderSync` (outside a worker).
 * @throws {ArgumentException} `source` isn't one of the kinds of {@link TzdataSyncSource} (a Request, Response or stream
 * can only be read asynchronously), or is an array with a number that isn't a byte.
 * @throws {HttpRequestException} The download failed with an HTTP error status (`XMLHttpRequest`'s own errors, such
 * as a network error, are passed through).
 * @throws {NotSupportedException} The archive is lzip-compressed (a tzdb-<version>.tar.lz archive).
 * @throws {InvalidDataException} The archive isn't a valid gzip-compressed or plain tar file, or its tzdb version can't
 * be determined.
 * @throws {InvalidNodaDataException} The compiled data fails validation.
 */
export function CompileTzdbToNzdSync(source: TzdataSyncSource, options?: CompileTzdbOptions): Uint8Array {
  return CompileSync(source, options).Nzd;
}
