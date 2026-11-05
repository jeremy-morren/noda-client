// noda-js: new code. The inputs the tzdb compiler (noda-js/tzdb/compiler) takes tzdata from: an archive's bytes in
// any of the forms a JavaScript host gives them (typed arrays, buffers, arrays of numbers, chunks), a URL (downloaded
// with fetch(), or a synchronous XMLHttpRequest) of an archive or of a directory of tzdata files, a Blob or File, a
// fetch Request or Response, or a stream.

import { GetFileName, TzdbZoneInfoCompiler } from "./internal.ts";
import { NewArgumentException, NewHttpRequestException, NewInvalidDataException, NewInvalidOperationException, type ArgumentException } from "../internal.ts";

/**
 * Some of a tzdata archive's bytes: a typed array (`Uint8Array`, Node's `Buffer`, `Int8Array`, ...) or `DataView`
 * (the bytes it views, whatever its element type), an `ArrayBuffer` or `SharedArrayBuffer`, or an array (or
 * array-like) of byte values (0 to 255, or -128 to 127 as signed bytes).
 */
export type TzdataChunk = ArrayBufferLike | ArrayBufferView | ArrayLike<number>;

/** A tzdata archive's bytes: one {@link TzdataChunk}, or a list of them (concatenated). */
export type TzdataBytes = TzdataChunk | readonly TzdataChunk[];

/**
 * A tzdata archive, for the synchronous compiler functions (CompileTzdbSync and CompileTzdbToNzdSync): its bytes,
 * its URL (a string or URL object, downloaded with a synchronous XMLHttpRequest), or a Blob or File (read with
 * FileReaderSync, which only workers have). A URL whose path ends with `/` is a directory of tzdata files instead
 * (such as a tag of IANA's tz repository on a CDN, e.g. `https://cdn.jsdelivr.net/gh/eggert/tz@2026f/`): the files the
 * compiler reads are downloaded one by one, and those the directory doesn't have (HTTP 404) are skipped.
 */
export type TzdataSyncSource = string | URL | TzdataBytes | Blob;

/**
 * A tzdata archive, for the asynchronous compiler functions (CompileTzdb and CompileTzdbToNzd): anything a
 * {@link TzdataSyncSource} can be (a URL, of an archive or a directory, is downloaded with fetch(), and a Blob or
 * File read asynchronously), a
 * fetch Request (fetched) or Response (read), a ReadableStream of bytes, or an async iterable of byte chunks (such as
 * a Node.js stream, without an encoding set).
 */
export type TzdataSource = TzdataSyncSource | Request | Response | ReadableStream<TzdataChunk> | AsyncIterable<TzdataChunk>;

/** The archive's bytes, and its name if known (for the compiler's version detection: e.g. a URL's file name). */
export interface TzdataArchive {
  readonly Bytes: Uint8Array;
  readonly Origin: string;
}

/** The files from a directory URL, by name, and the directory's name (for the compiler's version detection). */
export interface TzdataDirectory {
  readonly Files: ReadonlyMap<string, Uint8Array>;
  readonly Origin: string;
}

/**
 * The files the compiler reads, besides the Makefile: its VERSION is "unknown" except in a release's build, and
 * directories of release files have a `version` file instead.
 */
let compilerFiles: readonly string[] | undefined;
function CompilerFiles(): readonly string[] {
  return (compilerFiles ??= [
    ...TzdbZoneInfoCompiler.ZoneFiles,
    TzdbZoneInfoCompiler.Iso3166TabFile,
    TzdbZoneInfoCompiler.ZoneTabFile,
    TzdbZoneInfoCompiler.Zone1970TabFile,
  ]);
}

/** The files to download from a directory URL: the files the compiler reads, and the `version` file (Archive.ts). */
function DirectoryFiles(): readonly string[] {
  return [...CompilerFiles(), "version"];
}

// Workers only (it isn't in TypeScript's DOM library).
declare const FileReaderSync: (new () => { readAsArrayBuffer(blob: Blob): ArrayBuffer }) | undefined;

const toString = Object.prototype.toString;

/** Whether the value is an ArrayBuffer or SharedArrayBuffer (from any realm, unlike `instanceof`). */
function IsArrayBuffer(value: unknown): value is ArrayBufferLike {
  const tag = toString.call(value);
  return tag === "[object ArrayBuffer]" || tag === "[object SharedArrayBuffer]";
}

/** Whether the value is an array-like of numbers (judged by its first element; an empty one counts). */
function IsNumberArrayLike(value: unknown): value is ArrayLike<number> {
  if (value === null || typeof value !== "object") {
    return false;
  }
  const length = (value as { length?: unknown }).length;
  return typeof length === "number" && length >= 0 && length % 1 === 0 &&
    (length === 0 || typeof (value as ArrayLike<unknown>)[0] === "number");
}

/** A chunk's bytes, or null if it isn't a {@link TzdataChunk}. */
function ChunkBytes(chunk: unknown): Uint8Array | null {
  if (ArrayBuffer.isView(chunk)) {
    const bytes = new Uint8Array(chunk.buffer, chunk.byteOffset, chunk.byteLength);
    // A copy of shared memory: it could change while we read it, and DecompressionStream rejects it.
    return IsArrayBuffer(chunk.buffer) && toString.call(chunk.buffer) !== "[object ArrayBuffer]" ? bytes.slice() : bytes;
  }
  if (IsArrayBuffer(chunk)) {
    const bytes = new Uint8Array(chunk);
    return toString.call(chunk) === "[object ArrayBuffer]" ? bytes : bytes.slice();
  }
  if (IsNumberArrayLike(chunk)) {
    const bytes = new Uint8Array(chunk.length);
    for (let i = 0; i < chunk.length; i++) {
      const value = chunk[i];
      if (typeof value !== "number" || value % 1 !== 0 || value < -128 || value > 255) {
        throw NewArgumentException(`The tzdata bytes must be integers from 0 to 255 (or -128 to 127); element ${i} is ${String(value)}.`);
      }
      bytes[i] = value & 0xff;
    }
    return bytes;
  }
  return null;
}

/** Concatenates chunks of bytes. */
function Concat(chunks: readonly Uint8Array[]): Uint8Array {
  if (chunks.length === 1) {
    return chunks[0]!;
  }
  let length = 0;
  for (const chunk of chunks) {
    length += chunk.length;
  }
  const output = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.length;
  }
  return output;
}

/** The chunk's bytes, or an ArgumentException naming what it came from. */
function RequireChunk(chunk: unknown, from: string): Uint8Array {
  const bytes = ChunkBytes(chunk);
  if (bytes === null) {
    throw NewArgumentException(
      `${from} must give the archive's bytes (typed arrays, ArrayBuffers or arrays of numbers), not ` +
        `${typeof chunk === "string" ? "text (don't set an encoding on the stream)" : toString.call(chunk)}.`,
    );
  }
  return bytes;
}

/** The bytes, if the source is a {@link TzdataBytes}, or else null. */
function SourceBytes(source: unknown): Uint8Array | null {
  const bytes = ChunkBytes(source);
  if (bytes !== null) {
    return bytes;
  }
  // A list of chunks (an empty list is an empty array of numbers, above).
  if (Array.isArray(source)) {
    return Concat(source.map(chunk => RequireChunk(chunk, "Each element of the tzdata source")));
  }
  return null;
}

/** Whether the source is a URL: a string or URL object. */
function IsUrl(source: unknown): source is string | URL {
  return typeof source === "string" || (typeof URL === "function" && source instanceof URL);
}

/** Whether the value is a Blob (or File), by its class if the host has one, and by shape otherwise. */
function IsBlob(value: unknown): value is Blob {
  if (typeof Blob === "function" && value instanceof Blob) {
    return true;
  }
  const tag = toString.call(value);
  return tag === "[object Blob]" || tag === "[object File]";
}

/** A Blob's name (a File's), for the compiler's version detection, or "". */
function BlobName(blob: Blob): string {
  const name = (blob as { name?: unknown }).name;
  return typeof name === "string" ? GetFileName(name) : "";
}

/**
 * The archive's name, for the compiler's version detection: the URL's file name, without any query or fragment; none
 * for a data: or blob: URL, which has no file name.
 */
function OriginOf(url: string): string {
  return /^(data|blob):/i.test(url) ? "" : GetFileName(url.split(/[?#]/)[0]!);
}

/** Whether a URL is a directory's: its path ends with "/". */
function IsDirectoryUrl(url: string): boolean {
  return !/^(data|blob):/i.test(url) && /\/$/.test(url.split(/[?#]/)[0]!);
}

/** The URL of a file in a directory (keeping the directory URL's query and fragment, if any). */
function DirectoryFileUrl(directory: string, name: string): string {
  const index = directory.search(/[?#]/);
  return index === -1 ? directory + name : directory.substring(0, index) + name + directory.substring(index);
}

/** A directory's name, for the compiler's version detection: the last segment of its URL's path. */
function DirectoryOrigin(url: string): string {
  const segments = url.split(/[?#]/)[0]!.split("/").filter(segment => segment !== "");
  return segments.length > 1 ? segments[segments.length - 1]! : "";
}

/** The files downloaded from a directory, checking it has some of the zone files. */
function Directory(url: string, files: ReadonlyMap<string, Uint8Array>): TzdataDirectory {
  if (!CompilerFiles().some(name => files.has(name))) {
    throw NewInvalidDataException(`${url} has none of the tzdata files (${CompilerFiles().join(", ")}).`);
  }
  return { Files: files, Origin: DirectoryOrigin(url) };
}

/** The error for an unsuccessful HTTP status. */
function DownloadFailed(url: string, status: number, statusText: string): Error {
  return NewHttpRequestException(`Downloading ${url} failed: HTTP ${status} ${statusText}`.trim(), status);
}

/** The error for a source that isn't one of the supported kinds. */
function UnsupportedSource(source: unknown, sync: boolean): ArgumentException {
  return NewArgumentException(
    sync
      ? "The tzdata source must be a URL (a string or URL object), the archive's bytes (a typed array, ArrayBuffer, " +
        `array of numbers or list of them) or a Blob, not ${toString.call(source)}. (CompileTzdb and ` +
        "CompileTzdbToNzd also take a Request, Response or stream.)"
      : "The tzdata source must be a URL (a string or URL object), the archive's bytes (a typed array, ArrayBuffer, " +
        "array of numbers or list of them), a Blob, a Request or Response, a ReadableStream or an async iterable of " +
        `bytes, not ${toString.call(source)}.`,
  );
}

/** Reads a Response's body, if it was successful. */
async function ReadResponse(response: Response, fallbackUrl: string): Promise<TzdataArchive> {
  const url = response.url || fallbackUrl;
  if (!response.ok) {
    throw DownloadFailed(url, response.status, response.statusText);
  }
  return { Bytes: new Uint8Array(await response.arrayBuffer()), Origin: url ? OriginOf(url) : "" };
}

/** Throws if the host has no fetch(). */
function RequireFetch(): void {
  if (typeof fetch !== "function") {
    throw NewInvalidOperationException(
      "CompileTzdb and CompileTzdbToNzd download a URL with the host's fetch(), which is not available. " +
        "Use CompileTzdbSync or CompileTzdbToNzdSync (which use XMLHttpRequest), or download the archive another " +
        "way and pass its bytes (a Uint8Array or ArrayBuffer) instead.",
    );
  }
}

/** Downloads a URL or Request with the host's fetch(). */
async function Fetch(request: string | Request, log: ((line: string) => void) | null): Promise<TzdataArchive> {
  RequireFetch();
  const url = typeof request === "string" ? request : request.url;
  log?.(`Downloading ${url}`);
  return await ReadResponse(await fetch(request), url);
}

/** Downloads the files the compiler reads from a directory URL with the host's fetch(), in parallel. */
async function FetchDirectory(url: string, log: ((line: string) => void) | null): Promise<TzdataDirectory> {
  RequireFetch();
  const downloads = DirectoryFiles().map(async name => {
    const fileUrl = DirectoryFileUrl(url, name);
    log?.(`Downloading ${fileUrl}`);
    const response = await fetch(fileUrl);
    if (response.status === 404) {
      return null; // A file this release doesn't have (e.g. systemv, removed in 2020b).
    }
    if (!response.ok) {
      throw DownloadFailed(fileUrl, response.status, response.statusText);
    }
    return { Name: name, Bytes: new Uint8Array(await response.arrayBuffer()) };
  });
  // (Not `for (... of await ...)`: QuickJS miscompiles the `yield` that an ES2015 build turns the await into.)
  const downloaded = await Promise.all(downloads);
  const files = new Map<string, Uint8Array>();
  for (const file of downloaded) {
    if (file !== null) {
      files.set(file.Name, file.Bytes);
    }
  }
  return Directory(url, files);
}

/** Reads a Blob asynchronously (with its arrayBuffer method, or a FileReader on hosts whose Blob has none). */
async function ReadBlob(blob: Blob): Promise<Uint8Array> {
  if (typeof blob.arrayBuffer === "function") {
    return new Uint8Array(await blob.arrayBuffer());
  }
  if (typeof FileReader !== "function") {
    throw NewInvalidOperationException("Reading a Blob needs its arrayBuffer method or the host's FileReader, and neither is available.");
  }
  return await new Promise<Uint8Array>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(new Uint8Array(reader.result as ArrayBuffer));
    reader.onerror = () => reject(reader.error ?? new Error("Reading the Blob failed."));
    reader.readAsArrayBuffer(blob);
  });
}

/** Reads a ReadableStream to its end. */
async function ReadStream(stream: ReadableStream<unknown>): Promise<Uint8Array> {
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      chunks.push(RequireChunk(value, "The tzdata stream"));
    }
  } finally {
    reader.releaseLock();
  }
  return Concat(chunks);
}

/** The value's async iterator method, if it has one (Symbol.asyncIterator is ES2018). */
function AsyncIteratorOf(value: unknown): (() => AsyncIterator<unknown>) | null {
  if (value === null || (typeof value !== "object" && typeof value !== "function") ||
    typeof Symbol !== "function" || typeof Symbol.asyncIterator !== "symbol") {
    return null;
  }
  const method = (value as { [Symbol.asyncIterator]?: unknown })[Symbol.asyncIterator];
  return typeof method === "function" ? () => (method as () => AsyncIterator<unknown>).call(value) : null;
}

/** Reads an async iterable of chunks to its end. */
async function ReadAsyncIterable(iterate: () => AsyncIterator<unknown>): Promise<Uint8Array> {
  const iterator = iterate();
  const chunks: Uint8Array[] = [];
  let done = false;
  try {
    for (;;) {
      const result = await iterator.next();
      if (result.done) {
        done = true;
        break;
      }
      chunks.push(RequireChunk(result.value, "The tzdata stream"));
    }
  } finally {
    // As `for await` does when it stops early (e.g. a Node stream is then destroyed).
    if (!done && typeof iterator.return === "function") {
      await iterator.return();
    }
  }
  return Concat(chunks);
}

/**
 * Reads a {@link TzdataSource}: downloads a URL (of an archive or a directory) or Request with fetch(), reads a
 * Response, Blob or stream.
 * @internal
 */
export async function ReadTzdataSource(source: TzdataSource, log: ((line: string) => void) | null): Promise<TzdataArchive | TzdataDirectory> {
  const bytes = SourceBytes(source);
  if (bytes !== null) {
    return { Bytes: bytes, Origin: "" };
  }
  if (IsUrl(source)) {
    const url = String(source);
    return IsDirectoryUrl(url) ? await FetchDirectory(url, log) : await Fetch(url, log);
  }
  if (IsBlob(source)) {
    return { Bytes: await ReadBlob(source), Origin: BlobName(source) };
  }
  if (typeof Request === "function" && source instanceof Request) {
    return await Fetch(source, log);
  }
  if ((typeof Response === "function" && source instanceof Response) || toString.call(source) === "[object Response]") {
    return await ReadResponse(source as Response, "");
  }
  if (source === null || typeof source !== "object") {
    throw UnsupportedSource(source, false);
  }
  if (typeof (source as { getReader?: unknown }).getReader === "function") {
    return { Bytes: await ReadStream(source as ReadableStream<unknown>), Origin: "" };
  }
  const iterate = AsyncIteratorOf(source);
  if (iterate !== null) {
    return { Bytes: await ReadAsyncIterable(iterate), Origin: "" };
  }
  throw UnsupportedSource(source, false);
}

/** Downloads a URL with a synchronous XMLHttpRequest: its bytes, or null if `missingOk` and it was a 404. */
function DownloadWithXhr(url: string, log: ((line: string) => void) | null, missingOk = false): Uint8Array | null {
  if (typeof XMLHttpRequest !== "function") {
    throw NewInvalidOperationException(
      "CompileTzdbSync and CompileTzdbToNzdSync download a URL with the host's XMLHttpRequest, which is not " +
        "available. Use CompileTzdb or CompileTzdbToNzd (which use fetch()), or download the archive another way " +
        "and pass its bytes (a Uint8Array or ArrayBuffer) instead.",
    );
  }
  log?.(`Downloading ${url}`);
  const request = new XMLHttpRequest();
  request.open("GET", url, false);
  // A synchronous request can't ask for an ArrayBuffer (in a window), so take the body as text in a charset that
  // maps each byte to one character (bytes 0x80-0xFF become U+F780-U+F7FF; the low byte is the byte).
  request.overrideMimeType("text/plain; charset=x-user-defined");
  request.send();
  if (missingOk && request.status === 404) {
    return null;
  }
  if (request.status < 200 || request.status > 299) {
    throw DownloadFailed(url, request.status, request.statusText);
  }
  const text = request.responseText;
  const bytes = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) {
    bytes[i] = text.charCodeAt(i) & 0xff;
  }
  return bytes;
}

/**
 * Reads a {@link TzdataSyncSource} synchronously: downloads a URL (of an archive, or each file from a directory) with
 * a synchronous XMLHttpRequest, reads a Blob with FileReaderSync.
 * @internal
 */
export function ReadTzdataSourceSync(source: TzdataSyncSource, log: ((line: string) => void) | null): TzdataArchive | TzdataDirectory {
  const bytes = SourceBytes(source);
  if (bytes !== null) {
    return { Bytes: bytes, Origin: "" };
  }
  if (IsUrl(source)) {
    const url = String(source);
    if (IsDirectoryUrl(url)) {
      const files = new Map<string, Uint8Array>();
      for (const name of DirectoryFiles()) {
        const bytes = DownloadWithXhr(DirectoryFileUrl(url, name), log, true);
        if (bytes !== null) {
          files.set(name, bytes);
        }
      }
      return Directory(url, files);
    }
    return { Bytes: DownloadWithXhr(url, log)!, Origin: OriginOf(url) };
  }
  if (IsBlob(source)) {
    if (typeof FileReaderSync !== "function") {
      throw NewInvalidOperationException(
        "CompileTzdbSync and CompileTzdbToNzdSync read a Blob with the host's FileReaderSync, which only workers " +
          "have. Use CompileTzdb or CompileTzdbToNzd, or pass the Blob's bytes instead.",
      );
    }
    return { Bytes: new Uint8Array(new FileReaderSync().readAsArrayBuffer(source)), Origin: BlobName(source) };
  }
  throw UnsupportedSource(source, true);
}
