// noda-js: new code. The noda-js/tzdb/compiler entry point: compiles IANA tzdata at run time.

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
export type { HttpRequestException, InvalidDataException } from "../internal.ts";

/** Options for {@link CompileTzdb}, {@link CompileTzdbToNzd} and their synchronous variants. */
export interface CompileTzdbOptions {
  /** The Windows mapping to include (the compiler's `-w`); defaults to the CLDR mapping bundled with noda-js. */
  readonly WindowsZones?: WindowsZones | undefined;
  /** Called with each line of the compiler's log; by default nothing is logged. */
  readonly Log?: ((line: string) => void) | undefined;
}

/** Compiles, writes, reads back and validates the data (NodaTime's TzdbCompiler program). */
function CompileFiles(
  files: FileSource,
  options: CompileTzdbOptions | undefined,
): { readonly Nzd: Uint8Array; readonly Source: TzdbDateTimeZoneSource } {
  return Program.Main(files, options?.WindowsZones ?? GetCldrWindowsZones(), options?.Log ?? null);
}

async function Compile(
  source: TzdataSource,
  options: CompileTzdbOptions | undefined,
): Promise<{ readonly Nzd: Uint8Array; readonly Source: TzdbDateTimeZoneSource }> {
  const input = await ReadTzdataSource(source, options?.Log ?? null);
  return CompileFiles("Files" in input ? TzdataFileSource(input.Files, input.Origin) : await ReadTzdbArchive(input.Bytes, input.Origin), options);
}

function CompileSync(
  source: TzdataSyncSource,
  options: CompileTzdbOptions | undefined,
): { readonly Nzd: Uint8Array; readonly Source: TzdbDateTimeZoneSource } {
  const input = ReadTzdataSourceSync(source, options?.Log ?? null);
  return CompileFiles("Files" in input ? TzdataFileSource(input.Files, input.Origin) : ReadTzdbArchiveSync(input.Bytes, input.Origin), options);
}

/**
 * Compiles an IANA tzdata release into a validated time zone source, as NodaTime's TzdbCompiler does.
 *
 * ```ts
 * const zones = new DateTimeZoneCache(await CompileTzdb("https://data.iana.org/time-zones/tzdata-latest.tar.gz"));
 * ```
 *
 * data.iana.org has no CORS headers: in a browser, use a directory URL ending with `/`, such as
 * `https://cdn.jsdelivr.net/gh/eggert/tz@2026f/`.
 * @param source A `tzdata<version>.tar.gz` (or `.tar`) URL, directory URL, bytes, Blob, Request, Response or stream.
 * @param options The Windows mapping and a log function.
 * @returns The time zone source.
 * @throws {InvalidOperationException} `source` is a URL and the host has no `fetch`.
 * @throws {ArgumentException} `source` isn't a {@link TzdataSource}, or doesn't give bytes.
 * @throws {HttpRequestException} The download failed with an HTTP error status.
 * @throws {NotSupportedException} The archive is lzip-compressed.
 * @throws {InvalidDataException} The archive isn't gzip or tar, or its tzdb version can't be determined.
 * @throws {InvalidNodaDataException} The compiled data fails validation (tzdata errors throw as NodaTime's do, e.g.
 * {@link FormatException}).
 */
export async function CompileTzdb(source: TzdataSource, options?: CompileTzdbOptions): Promise<TzdbDateTimeZoneSource> {
  return (await Compile(source, options)).Source;
}

/**
 * Compiles an IANA tzdata release into NZD bytes, to cache and load with `TzdbDateTimeZoneSource.FromBytes`.
 * @param source The tzdata, as for {@link CompileTzdb}.
 * @param options The Windows mapping and a log function.
 * @returns The NZD data.
 * @throws {InvalidOperationException} `source` is a URL and the host has no `fetch`.
 * @throws {ArgumentException} `source` isn't a {@link TzdataSource}, or doesn't give bytes.
 * @throws {HttpRequestException} The download failed with an HTTP error status.
 * @throws {NotSupportedException} The archive is lzip-compressed.
 * @throws {InvalidDataException} The archive isn't gzip or tar, or its tzdb version can't be determined.
 * @throws {InvalidNodaDataException} The compiled data fails validation.
 */
export async function CompileTzdbToNzd(source: TzdataSource, options?: CompileTzdbOptions): Promise<Uint8Array> {
  return (await Compile(source, options)).Nzd;
}

/**
 * {@link CompileTzdb}, synchronously: a URL is downloaded with a synchronous `XMLHttpRequest` (prefer a worker).
 * @param source A URL, bytes, or a Blob (in a worker, read with `FileReaderSync`).
 * @param options The Windows mapping and a log function.
 * @returns The time zone source.
 * @throws {InvalidOperationException} The host has no `XMLHttpRequest` (for a URL) or `FileReaderSync` (for a Blob).
 * @throws {ArgumentException} `source` isn't a {@link TzdataSyncSource}, or has a non-byte value.
 * @throws {HttpRequestException} The download failed with an HTTP error status.
 * @throws {NotSupportedException} The archive is lzip-compressed.
 * @throws {InvalidDataException} The archive isn't gzip or tar, or its tzdb version can't be determined.
 * @throws {InvalidNodaDataException} The compiled data fails validation.
 */
export function CompileTzdbSync(source: TzdataSyncSource, options?: CompileTzdbOptions): TzdbDateTimeZoneSource {
  return CompileSync(source, options).Source;
}

/**
 * {@link CompileTzdbToNzd}, synchronously; see {@link CompileTzdbSync}.
 * @param source A URL, bytes, or a Blob (in a worker).
 * @param options The Windows mapping and a log function.
 * @returns The NZD data.
 * @throws {InvalidOperationException} The host has no `XMLHttpRequest` (for a URL) or `FileReaderSync` (for a Blob).
 * @throws {ArgumentException} `source` isn't a {@link TzdataSyncSource}, or has a non-byte value.
 * @throws {HttpRequestException} The download failed with an HTTP error status.
 * @throws {NotSupportedException} The archive is lzip-compressed.
 * @throws {InvalidDataException} The archive isn't gzip or tar, or its tzdb version can't be determined.
 * @throws {InvalidNodaDataException} The compiled data fails validation.
 */
export function CompileTzdbToNzdSync(source: TzdataSyncSource, options?: CompileTzdbOptions): Uint8Array {
  return CompileSync(source, options).Nzd;
}
